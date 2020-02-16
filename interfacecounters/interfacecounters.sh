#!/bin/bash
# Onur

fPrintHelp() {
echo Usage:
echo "interfacecounters -c <CiscoHost> <int_1> <int_2> ... <int_n>"
echo "interfacecounters -a <AristaHost> <int_1> <int_2> ... <int_n>"
echo "interfacecounters -j <JuniperHost> <int_1> <int_2> ... <int_n>"
echo ""
echo -e "Make sure zsshpass is installed\n"
echo "Input arguments: $@"
}

[[ $# -lt 3 ]] && { fPrintHelp; exit 1; }

UsersName=`whoami`

while true; do case "$1" in
  -c)       shift;host=$1;shift;devicetype=cisco;;
  -a)       shift;host=$1;shift;devicetype=arista;;
  -j)       shift;host=$1;shift;devicetype=juniper;;
  -u)       shift;UsersName=$1;shift;;
  -p)       shift;UsersPass=$1;shift;;
  *)        break;;
esac
done
[[ -z "$devicetype" ]] && { fPrintHelp; exit 1; }

[[ ! -f ~/.data/input && ( -z $UsersName || -z $UsersPass ) ]] && { read -s -p "Softlayer Password: " UsersPass; echo ""; }

args=("$@")

[[ $devicetype == "cisco" ]] && { prompt="#"; commands=`echo "$@" | sed 's/ /\n/g' | sed 's/^/\"show int /g' | sed 's/$/" /g' | awk '{ printf "%s", $0 }'`; }
[[ $devicetype == "arista" ]] && { prompt="#"; commands=`echo "$@" | sed 's/ /\n/g' | sed 's/^/\"show int /g' | sed 's/$/\ | begin packets" /g' | awk '{ printf "%s", $0 }'`; }
[[ $devicetype == "juniper" ]] && { prompt=">"; commands=`echo "$@" | sed 's/ /\n/g' | sed 's/^/\"show int /g' | sed 's/$/\ extensive" /g' | awk '{ printf "%s", $0 }'`; }

if [[ ! -z $UsersName && ! -z $UsersPass ]]; then
  CommandsOutput=`sh -c "zsshpass -u $UsersName/$UsersPass $host $commands 2> /dev/null" | sed 's/\r//g'| sed 's/\t/ /g'`
else
  CommandsOutput=`sh -c "zsshpass $host $commands 2> /dev/null" | sed 's/\r//g'| sed 's/\t/ /g'`
fi
#echo "$CommandsOutput"

if [ $devicetype == "cisco" ]; then
  for cmdindex in $(eval echo {1..$#}); do
    ThisCmdOutput=`echo "$CommandsOutput" | egrep -A 100000 "command $cmdindex start" | egrep -B 100000 "command $cmdindex finish" | grep -v "command $cmdindex" | awk '/packets input/ { print "  RX"; print; next }1' | awk '/packets output/ { print "  TX"; print; next }1'`
        # RX
        echo "$ThisCmdOutput" | sed -e '1,/^  RX$/d' -e '/^  TX$/,$d' | sed -e 's/\([0-9]\+\)/\n\1/g' | sed '/^[[:space:]]*$/d' | awk '{$1=$1};1' | sed '/^[^0-9]/d' | tr -d '(),_' | awk '{$1=$1};1' | sed -e 's/ /_/g' -e 's/_/ /1' | awk '{print "rx_" $2 " " $1}' | grep -v RX | sed -e 's/rx_Rx_/rx_/g' | awk -v interface="${args[$cmdindex-1]}" '{print interface " " $0}'
        # TX
        echo "$ThisCmdOutput" | sed -e '1,/^  TX$/d' | sed -e 's/\([0-9]\+\)/\n\1/g' | sed '/^[[:space:]]*$/d' | awk '{$1=$1};1' | sed '/^[^0-9]/d' | tr -d '(),_' | awk '{$1=$1};1' | sed -e 's/ /_/g' -e 's/_/ /1' | awk '{print "tx_" $2 " " $1}' | sed -e 's/tx_Tx_/tx_/g' | awk -v interface="${args[$cmdindex-1]}" '{print interface " " $0}'
  done
fi
if [ $devicetype == "arista" ]; then
  for cmdindex in $(eval echo {1..$#}); do
    ThisCmdOutput=`echo "$CommandsOutput" | egrep -A 100000 "command $cmdindex start" | egrep -B 100000 "command $cmdindex finish" | grep -v "command $cmdindex"`
        # RX
        echo "$ThisCmdOutput" | awk '/packets input/{flag=1}/packets output/{flag=0}flag' | awk '{$1=$1};1' | sed 's/^\([A-Z]\)\([a-z]\)* //g' | sed 's/,//g' | sed -e 's/\([0-9]\+\)/\n\1/g' | sed '/^[[:space:]]*$/d' | awk '{$1=$1};1' | sed -e 's/ /_/g' -e 's/_/ /1' | awk '{print "rx_" $2 " " $1}' | awk -v interface="${args[$cmdindex-1]}" '{print interface " " $0}'
        # TX
        echo "$ThisCmdOutput" | awk '/packets output/,0' | awk '{$1=$1};1' | sed 's/^\([A-Z]\)\([a-z]\)* //g' | sed 's/,//g' | sed -e 's/\([0-9]\+\)/\n\1/g' | sed '/^[[:space:]]*$/d' | awk '{$1=$1};1' | sed -e 's/ /_/g' -e 's/_/ /1' | awk '{print "tx_" $2 " " $1}' | awk -v interface="${args[$cmdindex-1]}" '{print interface " " $0}'
  done
fi
if [ $devicetype == "juniper" ]; then
  for cmdindex in $(eval echo {1..$#}); do
    ThisCmdOutput=`echo "$CommandsOutput" | egrep -A 100000 "command $cmdindex start" | egrep -B 100000 "command $cmdindex finish" | grep -v "command $cmdindex" | sed 's/---(more)---//g'`
    echo "$ThisCmdOutput" | sed '/IPv6 transit/q' | grep "Input  bytes" | awk -v interface="${args[$cmdindex-1]}" '{print interface " rx_bytes " $4}'  
    echo "$ThisCmdOutput" | sed '/IPv6 transit/q' | grep "Output bytes" | awk -v interface="${args[$cmdindex-1]}" '{print interface " tx_bytes " $4}'
    # RX
    echo "$ThisCmdOutput" | grep "    Errors:" | sed 's/://g' | sed 's/,/\n/g' | awk '{$1=$1};1' | sed '/^[[:space:]]*$/d' | sed -e 's/ /_/g' | sed -r 's/(.*)_/\1 /' | awk '{print "rx_" $1 " " $2}' | awk -v interface="${args[$cmdindex-1]}" '{print interface " " $0}'
    # TX
    echo "$ThisCmdOutput" | grep "    Carrier transitions:" | sed 's/://g' | sed 's/,/\n/g' | awk '{$1=$1};1' | sed '/^[[:space:]]*$/d' | sed -e 's/ /_/g' | sed -r 's/(.*)_/\1 /' | awk '{print "tx_" $1 " " $2}' | awk -v interface="${args[$cmdindex-1]}" '{print interface " " $0}'
    echo "$ThisCmdOutput" | sed '/Logical interface/q' | grep "    Bit errors" | awk '{$1=$1};1' | sed -e 's/ /_/g' | sed -r 's/(.*)_/\1 /' | awk -v interface="${args[$cmdindex-1]}" '{print interface " PCS_" $0}'
    echo "$ThisCmdOutput" | sed '/Logical interface/q' | grep "    Errored blocks" | awk '{$1=$1};1' | sed -e 's/ /_/g' | sed -r 's/(.*)_/\1 /' | awk -v interface="${args[$cmdindex-1]}" '{print interface " PCS_" $0}'
    echo "$ThisCmdOutput" | sed '/Logical interface/q' | grep "    FEC C\|    FEC U" | awk '{$1=$1};1' | sed -e 's/ /_/g' | sed -r 's/(.*)_/\1 /' | awk -v interface="${args[$cmdindex-1]}" '{print interface " " $0}'
    echo "$ThisCmdOutput" | sed '/Logical interface/q' | grep "CRC/Align" | awk '{$1=$1};1' | awk -v interface="${args[$cmdindex-1]}" '{print interface " rx_CRC/Align " $3}'
    echo "$ThisCmdOutput" | sed '/Logical interface/q' | grep "CRC/Align" | awk '{$1=$1};1' | awk -v interface="${args[$cmdindex-1]}" '{print interface " tx_CRC/Align " $4}'
    echo "$ThisCmdOutput" | sed '/Logical interface/q' | grep "    Output packet error count" | awk '{$1=$1};1' | sed -e 's/ /_/g' | sed -r 's/(.*)_/\1 /' | awk -v interface="${args[$cmdindex-1]}" '{print interface " " $0}'
  done
fi

exit 0