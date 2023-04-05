#!/usr/local/share/virtualenv_onur/bin/python

# To Do List:
# - Arguman yonetimi
#    - Unlimited line count icin -0 calismiyor, daha kolay bir yol da dusun.
#    - Line count ile ilgili -N e alternatif olarak +N de dusun
#    - Device type lar daha generic olsun, sadece son word dc olunca degil. (utility server lar su an disarida kaliyor)
# - Help i dokumantasyon formatinda duzenle
# - Programini functional hale getir
# - protocol keywordleri destegi
# - Assist fonksiyonu ekle
# - Digerleri icin sifre
# - Istatistik icin loglama

from __future__ import absolute_import
from __future__ import print_function
import splunklib.client as client
import splunklib.results as results
import os, sys, re
from datetime import datetime, timezone, timedelta
from getpass import getpass

class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    mustard = '\033[93m'
    FAIL = '\033[91m'
    endc = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def fDateTimeReference(string):
    if string[0] == '-':
        string = string.lstrip('-')
    else:
        return False
    weeks = days = hours = minutes = seconds = 0
    if re.fullmatch('[0-9][0-9]*w.*', string):
        weeks = re.findall('[0-9][0-9]*', string)[0]
        string = re.sub('[0-9][0-9]*w', '', string)
    if re.fullmatch('[0-9][0-9]*d.*', string):
        days = re.findall('[0-9][0-9]*', string)[0]
        string = re.sub('[0-9][0-9]*d', '', string)
    if re.fullmatch('[0-9][0-9]*h.*', string):
        hours = re.findall('[0-9][0-9]*', string)[0]
        string = re.sub('[0-9][0-9]*h', '', string)
    if re.fullmatch('[0-9][0-9]*m.*', string):
        minutes = re.findall('[0-9][0-9]*', string)[0]
        string = re.sub('[0-9][0-9]*m', '', string)
    if re.fullmatch('[0-9][0-9]*s.*', string):
        seconds = re.findall('[0-9][0-9]*', string)[0]
        string = re.sub('[0-9][0-9]*s', '', string)
    if string == '':
        return [weeks, days, hours, minutes, seconds]
    else:
        return False

def fPrintHelp():
    if len(protocol_inputs) == 0:
        print("splunker ppr01.dal10 2022-08-08T18:10:30 2022-08-08T18:15:30")
        print("splunker ppr01.dal10 -10m")
        print("splunker ppr01.dal10 -10d RPD_LDP_NBRUP")
        print("splunker ppr01.dal10 -10w RPD_LDP_NBRUP -5")
        print("splunker ppr01.dal10 -10w RPD_LDP_NBRUP +5")
        print("")
        print("--and")
        print("--or")
        print("--txn")
        print("-v")
        print("-h")
        print("-r, --reverse")
    else:
        bProtoHelpRequested = False
        for key in protocol_inputs.keys():
            if len(protocol_inputs[key]) == 0:
                bProtoHelpRequested = True
                print(bcolors.mustard + key.upper() + " KEYWORDS" + bcolors.endc)
                for i in range(len(protocol_params_dict[key])):
                    print(i, "-", protocol_params_dict[key][i])
                print("")

# DC and Role Variables
stream = os.popen('nodedb')
output = stream.read().rstrip()
dc_list = list(output.split("\n"))

city_list = []
for dc in dc_list:
    if not dc.rstrip('0123456789') in city_list:
        city_list.append(dc.rstrip('0123456789'))

stream = os.popen('nodedb --roles')
output = stream.read().rstrip()
node_role_list = list(output.split("\n"))

# Protocol and Params
protocol_params_dict = {'bgp' : ['RPD_BGP_NEIGHBOR_STATE_CHANGED',
                                 'RPD_BGP_CFG_LOCAL_ASNUM_WARN',
                                 'RPD_BGP_THR_RESTART',
                                 'NOTIFICATION sent to',
                                 'NOTIFICATION received from',
                                 'BGP_CONNECT_FAILED',
                                 'BGP_UNEXPECTED_MESSAGE_TYPE',
                                 'BGP_NO_INCOMING_INTERFACE_FOUND',
                                 'BGP_NLRI_MISMATCH',
                                 'Connection attempt from unconfigured neighbor'],
                        'ospf': ['RPD_OSPF_NBRUP',
                                 'RPD_OSPF_NBRDOWN'],
                        'mpls': ['RPD_MPLS_LSP_UP',
                                 'RPD_MPLS_LSP_DOWN',
                                 'RPD_MPLS_PATH_UP',
                                 'RPD_MPLS_PATH_DOWN',
                                 'RPD_MPLS_LSP_CHANGE',
                                 'RPD_MPLS_LSP_SELFPING_TIMEOUT'],
                        'rsvp': ['RPD_RSVP_BYPASS_UP',
                                 'RPD_RSVP_BYPASS_DOWN',
                                 'RPD_RSVP_BACKUP_UP',
                                 'RPD_RSVP_BACKUP_DOWN',
                                 'RPD_RSVP_NBRUP',
                                 'RPD_RSVP_NBRDOWN',
                                 'RPD_RSVP_LSP_SWITCH'],
                        'ldp' : ['RPD_LDP_SESSIONUP',
                                 'RPD_LDP_SESSIONDOWN',
                                 'RPD_LDP_NBRUP',
                                 'RPD_LDP_NBRDOWN']
                       }

# Splunk Server and Creds
HOST = "splunk.softlayer.local"
PORT = 8089
USERNAME = os.getlogin()
PASSWORD = os.environ.get("MYPASS", "default")
if PASSWORD == "default":
    prompt = 'Password (' + USERNAME + '): '
    PASSWORD = getpass(prompt=prompt, stream=None)

# Argument management
searchmode = "host"
double_quotes = False
device_inputs =[]
dc_inputs = []
city_inputs = []
region_inputs = []
role_inputs = []
last_protocol_index = -1
protocol_inputs = {}
bProtocolMode = False
protocol_keys = []
search_key_inputs = []
bSearchWithOr = True
bSearchWithAnd = False
bVerbose = False
bPrintHelp = False
bRaw = False
bReversed = False
OutputLineCount = "0"
# OutputLineCount = "50"
CountSign = '-'

for i in range(1, len(sys.argv)):
    argument = sys.argv[i].lower()
    argument_orig = sys.argv[i]
    if double_quotes:
        if argument[-1] == '"':
            search_key_inputs[-1] = search_key_inputs[-1] + ' ' + argument_orig[:-1]
            double_quotes = False
        else:
            search_key_inputs[-1] = search_key_inputs[-1] + ' ' + argument_orig
    elif argument[0] == '"':
        if argument[-1] == '"':
            search_key_inputs.append(argument_orig[1:-1])
        else:
            search_key_inputs.append(argument_orig[1:])
            double_quotes = True
    elif argument.count('.') > 0 and argument.split('.')[-1] in dc_list:
        device_inputs.append(argument)
    elif argument in dc_list:
        dc_inputs.append(argument)
    # elif argument.count('.') == 0 and argument.rstrip('0123456789') in city_list:
    elif argument.rstrip('0123456789') in city_list:
        city_inputs.append(argument)
    elif argument in ['emea', 'americas', 'apac']:
        region_inputs.append(argument)
    elif argument in node_role_list:
        role_inputs.append(argument)
    elif argument in protocol_params_dict.keys():
        if argument in protocol_inputs.keys():
            if not argument_orig in search_key_inputs:
                search_key_inputs.append(argument_orig)
        else:
            protocol_inputs[argument] = []
            bProtocolMode = True
        last_protocol_index = i
    elif bProtocolMode and (argument.rstrip('0123456789') == '' or argument == '--all'):
        protocol_inputs[list(protocol_inputs.keys())[-1]].append(argument)
        if argument == '--all':
            bProtocolMode = False
    elif argument in ['and', '--and']:
        bSearchWithAnd = True
        bSearchWithOr = False
    elif argument in ['or', '--or']:
        bSearchWithOr = True
        bSearchWithAnd = False
    elif argument in ['txn', '-txn', '--txn']:
        searchmode = "txn"
    elif argument in ['-v', '--verbose']:
        bVerbose = True
    elif argument in ['-h', '--help']:
        bPrintHelp = True
    elif argument in ['--raw']:
        bRaw = True
    elif argument in ['-r', '--reverse', '--reversed']:
        bReversed = True
    elif argument.rstrip('0123456789') in ['-', '+']:
        OutputLineCount = argument[1:]
        CountSign = argument[:1]
        if OutputLineCount == '0':
            CountSign = '-'
    elif argument in ['now', '-now', '--now']:
        to_ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000")
    elif re.fullmatch('[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}', argument_orig) or \
         re.fullmatch('[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}', argument_orig):
        if not 'from_ts' in locals():
            from_ts = argument_orig
        else:
            to_ts = argument_orig
    else:
        wdhms = fDateTimeReference(argument)
        if wdhms:
            timestamp = datetime.now(timezone.utc) - timedelta(weeks = int(wdhms[0]), days = int(wdhms[1]), hours = int(wdhms[2]), minutes = int(wdhms[3]), seconds = int(wdhms[4]))
            if not 'from_ts' in locals():
                from_ts = timestamp.strftime("%Y-%m-%dT%H:%M:%S.000")
            else:
                to_ts = timestamp.strftime("%Y-%m-%dT%H:%M:%S.000")
        else:
            search_key_inputs.append(argument_orig)
    # To exit from protocol mode when a non-number input is entered
    if not argument.rstrip('0123456789') == '' and not argument == '--all' and i > last_protocol_index:
        bProtocolMode = False

# If user requested help
if bPrintHelp:
    fPrintHelp()
    sys.exit()

# If an entered protocol's list length is zero, then append that protocol name into search_key_inputs
for key in protocol_inputs.keys():
    if len(protocol_inputs[key]) == 0:
        if not key in search_key_inputs:
            search_key_inputs.append(key)
    elif '--all' in protocol_inputs[key]:
        for element in protocol_params_dict[key]:
            protocol_keys.append(element)
    else:
        for element in protocol_inputs[key]:
            protocol_keys.append(protocol_params_dict[key][int(element)])

# Set Time Frame Parameters
current_ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
if not 'from_ts' in locals():
    timestamp = datetime.now(timezone.utc) - timedelta(hours = 1)
    from_ts = timestamp.strftime("%Y-%m-%dT%H:%M:%S.000")
if not 'to_ts' in locals():
    to_ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000")

# Set Search Parameters
# Set devices_string
# Populate devices list
devices = device_inputs
if len(role_inputs) > 0:
    if len(region_inputs) > 0:
        for region in region_inputs:
            for role in role_inputs:
                query_string = 'nodedb ' + region + ' ' + role
                stream = os.popen(query_string)
                output = stream.read().rstrip()
                output_list = list(output.split("\n"))
                for item in output_list:
                    device = item.split('|')[0]
                    devices.append(device)
    elif len(city_inputs) > 0:
        for city in city_inputs:
            for role in role_inputs:
                query_string = 'nodedb ' + city + ' ' + role
                stream = os.popen(query_string)
                output = stream.read().rstrip()
                output_list = list(output.split("\n"))
                for item in output_list:
                    device = item.split('|')[0]
                    devices.append(device)
    elif len(dc_inputs) > 0:
        for dc in dc_inputs:
            for role in role_inputs:
                query_string = 'nodedb ' + dc + ' ' + role
                stream = os.popen(query_string)
                output = stream.read().rstrip()
                output_list = list(output.split("\n"))
                for item in output_list:
                    device = item.split('|')[0]
                    devices.append(device)


if searchmode == "host":
    if len(devices) == 0:
        print("Enter at least one device. Exiting.")
        sys.exit()

    devices_string = 'host=' + devices[0]
    for i in range(1,len(devices)):
        devices_string = devices_string + ' OR host=' + devices[i]
    devices_string = '(' + devices_string + ')'

    # Set protocols_string
    if len(protocol_keys) > 0:
        protocols_string = '(' + protocol_keys[0] + ')'
        for i in range(1,len(protocol_keys)):
            protocols_string = protocols_string + ' OR (' + protocol_keys[i] + ')'
        protocols_string = '(' + protocols_string + ')'

# Operator word for keys_string
# Keys are searched via AND or OR based on user input (default is OR)
if bSearchWithOr:
    Operator = ' OR '
else:
    Operator = ' AND '

# Set keys_string
if searchmode == "host":
    if len(search_key_inputs) > 0:
        keys_string = '(' + search_key_inputs[0] + ')'
        for i in range(1,len(search_key_inputs)):
            keys_string = keys_string + Operator + '(' + search_key_inputs[i] + ')'
        keys_string = '(' + keys_string + ')'
elif searchmode == "txn":
    for i in range(len(search_key_inputs)):
        if search_key_inputs[i].rstrip('0123456789') == '':
            if not 'keys_string' in locals():
                keys_string = '(txn_id=' + search_key_inputs[0] + ')'
            else:
                keys_string = keys_string + Operator + '(txn_id=' + search_key_inputs[i] + ')'

if searchmode == "host":
    # Set search_string based on existence of keys_string and protocols_string
    if 'keys_string' in locals() and 'protocols_string' in locals():
        search_string = 'search ' + devices_string + ' AND (' + keys_string + ' OR ' + protocols_string + ')'
    elif 'keys_string' in locals() and not 'protocols_string' in locals():
        search_string = 'search ' + devices_string + ' AND ' + keys_string
    elif not 'keys_string' in locals() and 'protocols_string' in locals():
        search_string = 'search ' + devices_string + ' AND ' + protocols_string
    else:
        search_string = 'search ' + devices_string
elif searchmode == "txn":
    if not 'keys_string' in locals():
        print("Enter at least one TXN ID. Exiting.")
        sys.exit()
    search_string = 'search (index=ims*) AND ' + keys_string

# Append the search_string for line count variable
if not OutputLineCount == '0':
    if CountSign == '-':
        search_string = search_string + ' | head ' + OutputLineCount
    else:
        search_string = search_string + ' | tail ' + OutputLineCount

# Display Verbose Info if requested
if bVerbose:
    print(search_string)
    print(from_ts, "   -   ", to_ts)

# Log search content to stats file
with open('/var/tmp/reports/splunker/search_history', 'a') as f1:
    original_stdout = sys.stdout
    sys.stdout = f1
    print(current_ts, "-", USERNAME, "-", from_ts, "to", to_ts, "-", search_string)
    sys.stdout = original_stdout

# Create a Service instance and log in
service = client.connect(
    host=HOST,
    port=PORT,
    username=USERNAME,
    password=PASSWORD,
    basic=True)

# Set time frame for the search
# kwargs_oneshot = {"earliest_time":"@d"}
# kwargs_oneshot = {"earliest_time":"2022-06-13T15:44:00.000",
#                   "latest_time":"2022-06-14T15:44:00.000"}
# kwargs_oneshot = {'earliest_time':'-24h', 'latest_time':'now'}
kwargs_oneshot = {"earliest_time":from_ts,
                  "latest_time":to_ts}

# Set search terms, run query and get the results using the ResultsReader
searchquery_oneshot = search_string
oneshotsearch_results = service.jobs.oneshot(searchquery_oneshot, **kwargs_oneshot, count=0)
reader = results.ResultsReader(oneshotsearch_results)

# Edit the results
output = []
for item in reader:
    if bRaw == True:
        output.append(item['_raw'])
    else:
        time = re.sub('.[0-9]{3}[+-][0-9]{2}:[0-9]{2}$', '', item['_time']).replace('T', ' ')
        host = item['host']
        asr_rp = re.findall('RP/[0-9]*/[a-zA-Z0-9]*/CPU[0-9]*', item['_raw'])
        raw_no_date = re.sub('^.*[a-zA-Z]{3} .[0-9]{1} [0-9]{2}:[0-9]{2}:[0-9]{2}.[0-9]{4}[:]* ', '', item['_raw'])
        raw_no_date = re.sub('^.*[a-zA-Z]{3} .[0-9]{1} [0-9]{2}:[0-9]{2}:[0-9]{2}.[0-9]{3}[:]* ', '', raw_no_date)
        raw_no_date = re.sub('^.*[a-zA-Z]{3} .[0-9]{1} [0-9]{2}:[0-9]{2}:[0-9]{2}[:]* ', '', raw_no_date)
        brief = re.sub('^.*UTC: ', '', raw_no_date)
        if len(asr_rp) > 0:
            brief = asr_rp[0] + ' ' + brief
        if not host in brief:
            brief = host + ' ' + brief
        output.append(time + ' ' + brief)

# Reverse the results if needed/requested
if bReversed ^ (CountSign == '-'):
    output = reversed(output)

# Display the results
for item in output:
    print(item)
