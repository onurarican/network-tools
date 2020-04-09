#!/usr/bin/python

import sys
import json
import softlayer_api_common as ims
client = ims.connect_to_api(neteng_user=True)

if len(sys.argv) !=5 and len(sys.argv) !=6:
   print 'imsquery Hardware getAllObjects \'{"id": {"operation": 1742603}}\' 100 "mask[id, hostname, domain, accountId, datacenter, networkVlans, networkManagementIpAddress, primaryBackendIpAddress, primaryIpAddress, softwareComponents[modifyDate, passwords[username, password], softwareLicense[softwareDescriptionId, softwareDescription[longDescription]]], uplinkNetworkComponents[id, name, port, primaryIpAddress, networkVlanId, macAddress, speed, status, uplink[id, uplinkComponent[id, hardwareId, name, port, duplexModeId, maxSpeed, speed, status, networkPortChannelId, networkVlanId]]], upstreamHardware[id, hostname]]" | jqflatten'
   print ('imsquery Virtual_Guest getAllObjects \'{"id": {"operation": 62765165}}\' 100 "mask[id, hostname, domain, accountId, datacenter, networkVlans, primaryBackendIpAddress, primaryIpAddress, softwareComponents[modifyDate, passwords[username, password], softwareLicense[softwareDescriptionId, softwareDescription[longDescription]]]]" | jqflatten')
   sys.exit()

DBType = sys.argv[1]
ObjMethod = sys.argv[2]
filterinput = json.loads(sys.argv[3])
limitinput = sys.argv[4]

if len(sys.argv) ==5:
   result = client.call(DBType, ObjMethod, filter=filterinput, limit=limitinput)
   # result = client.call(DBType, ObjMethod, filter=filterinput)
if len(sys.argv) ==6:
   maskinput = sys.argv[5]
   result = client.call(DBType, ObjMethod, filter=filterinput, limit=limitinput, mask=maskinput)
   # result = client.call(DBType, ObjMethod, filter=filterinput, mask=maskinput)

print result

sys.exit()