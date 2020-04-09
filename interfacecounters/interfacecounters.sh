#!/bin/bash
# Onur

fInitParams() {
  ToolDir=/home/oarican/tools/interfacecounters
  UsersName=`whoami`
  MinDiff=0
  MinValue=0
}
fPrintHelp() {
echo Usage:
echo "interfacecounters -c <CiscoHost> <int_1> <int_2> ... <int_n>"
echo "interfacecounters -a <AristaHost> <int_1> <int_2> ... <int_n>"
echo "interfacecounters -j <JuniperHost> <int_1> <int_2> ... <int_n>"
echo ""
echo -e "Options:\n"
echo -e "-u <user>"
echo -e "-p <pass>"
echo -e "-t <interval>            Takes two samples, waiting <interval> seconds in between"
echo -e "--all-phy                Lists all physical interface counters"
echo -e "--min-diff <value>"
echo -e "--min-value <value>"
echo -e "--print-host"
echo -e "--err-only\n"
echo "Input arguments: $@"
}
fCiscoRX() {
  echo "$ThisCmdOutput" | sed -e '1,/^  RX$/d' -e '/^  TX$/,$d' | sed -e 's/\([0-9]\+\)/\n\1/g' | sed '/^[[:space:]]*$/d' | awk '{$1=$1};1' | sed '/^[^0-9]/d' | tr -d '(),_' | awk '{$1=$1};1' | sed -e 's/ /_/g' -e 's/_/ /1' | awk '{print "rx_" $2 " " $1}' | grep -v RX | sed -e 's/rx_Rx_/rx_/g' | sed -e 's/\//_/' | awk -v interface="${args[$cmdindex-1]}" '{print interface " " $0}'
}
fCiscoTX() {
  echo "$ThisCmdOutput" | sed -e '1,/^  TX$/d' | sed -e 's/\([0-9]\+\)/\n\1/g' | sed '/^[[:space:]]*$/d' | awk '{$1=$1};1' | sed '/^[^0-9]/d' | tr -d '(),_' | awk '{$1=$1};1' | sed -e 's/ /_/g' -e 's/_/ /1' | awk '{print "tx_" $2 " " $1}' | sed -e 's/tx_Tx_/tx_/g' | sed -e 's/\//_/' | awk -v interface="${args[$cmdindex-1]}" '{print interface " " $0}'
}
fAristaRX() {
  echo "$ThisCmdOutput" | awk '/packets input/{flag=1}/packets output/{flag=0}flag' | awk '{$1=$1};1' | sed 's/^\([A-Z]\)\([a-z]\)* //g' | sed 's/,//g' | sed -e 's/\([0-9]\+\)/\n\1/g' | sed '/^[[:space:]]*$/d' | awk '{$1=$1};1' | sed -e 's/ /_/g' -e 's/_/ /1' | awk '{print "rx_" $2 " " $1}' | sed -e 's/\//_/' | awk -v interface="${args[$cmdindex-1]}" '{print interface " " $0}'
}
fAristaTX() {
  echo "$ThisCmdOutput" | awk '/packets output/,0' | awk '{$1=$1};1' | sed 's/^\([A-Z]\)\([a-z]\)* //g' | sed 's/,//g' | sed -e 's/\([0-9]\+\)/\n\1/g' | sed '/^[[:space:]]*$/d' | awk '{$1=$1};1' | sed -e 's/ /_/g' -e 's/_/ /1' | awk '{print "tx_" $2 " " $1}' | sed -e 's/\//_/' | awk -v interface="${args[$cmdindex-1]}" '{print interface " " $0}'
}
fJuniperInitial() {
  echo "$ThisCmdOutput" | sed '/IPv6 transit/q' | grep "Input  bytes" | sed -e 's/\//_/' | awk -v interface="${args[$cmdindex-1]}" '{print interface " rx_bytes " $4}'  
  echo "$ThisCmdOutput" | sed '/IPv6 transit/q' | grep "Output bytes" | sed -e 's/\//_/' | awk -v interface="${args[$cmdindex-1]}" '{print interface " tx_bytes " $4}'
}
fJuniperRX() {
  echo "$ThisCmdOutput" | grep "    Errors:" | sed 's/://g' | sed 's/,/\n/g' | awk '{$1=$1};1' | sed '/^[[:space:]]*$/d' | sed -e 's/ /_/g' | sed -r 's/(.*)_/\1 /' | awk '{print "rx_" $1 " " $2}' | sed -e 's/\//_/' | awk -v interface="${args[$cmdindex-1]}" '{print interface " " $0}'
}
fJuniperTX() {
  echo "$ThisCmdOutput" | grep "    Carrier transitions:" | sed 's/://g' | sed 's/,/\n/g' | awk '{$1=$1};1' | sed '/^[[:space:]]*$/d' | sed -e 's/ /_/g' | sed -r 's/(.*)_/\1 /' | awk '{print "tx_" $1 " " $2}' | sed -e 's/\//_/' | awk -v interface="${args[$cmdindex-1]}" '{print interface " " $0}'
  echo "$ThisCmdOutput" | sed '/Logical interface/q' | grep "    Bit errors" | awk '{$1=$1};1' | sed -e 's/ /_/g' | sed -r 's/(.*)_/\1 /' | sed -e 's/\//_/' | awk -v interface="${args[$cmdindex-1]}" '{print interface " PCS_" $0}'
  echo "$ThisCmdOutput" | sed '/Logical interface/q' | grep "    Errored blocks" | awk '{$1=$1};1' | sed -e 's/ /_/g' | sed -r 's/(.*)_/\1 /' | sed -e 's/\//_/' | awk -v interface="${args[$cmdindex-1]}" '{print interface " PCS_" $0}'
  echo "$ThisCmdOutput" | sed '/Logical interface/q' | grep "    FEC C\|    FEC U" | awk '{$1=$1};1' | sed -e 's/ /_/g' | sed -r 's/(.*)_/\1 /' | sed -e 's/\//_/' | awk -v interface="${args[$cmdindex-1]}" '{print interface " " $0}'
  echo "$ThisCmdOutput" | sed '/Logical interface/q' | grep "CRC/Align" | awk '{$1=$1};1' | awk -v interface="${args[$cmdindex-1]}" '{print interface " rx_CRC_Align " $3}'
  echo "$ThisCmdOutput" | sed '/Logical interface/q' | grep "CRC/Align" | awk '{$1=$1};1' | awk -v interface="${args[$cmdindex-1]}" '{print interface " tx_CRC_Align " $4}'
  echo "$ThisCmdOutput" | sed '/Logical interface/q' | grep "    Output packet error count" | awk '{$1=$1};1' | sed -e 's/ /_/g' | sed -r 's/(.*)_/\1 /' | sed -e 's/\//_/' | awk -v interface="${args[$cmdindex-1]}" '{print interface " " $0}'
}

[[ $# -lt 2 ]] && { fPrintHelp; exit 1; }

fInitParams

while [[ -z "$host" ]]; do case "$1" in
  -c)       shift;host=$1;shift;devicetype=cisco;;
  -a)       shift;host=$1;shift;devicetype=arista;;
  -j)       shift;host=$1;shift;devicetype=juniper;;
  -u)       shift;UsersName=$1;shift;;
  -p)       shift;UsersPass=$1;shift;;
  -t)       shift;TimeInterval=$1;shift;;
  --all-phy)    AllPhy=1;shift;;
  --min-diff)   shift;MinDiff=$1;shift;;
  --min-value)  shift;MinValue=$1;shift;;
  --print-host) PrintHost=1;shift;;
  --err-only)   ErrOnly=1;shift;;
  *)        host=$1;shift;;
esac
done

[[ ! -z "$host" && -z "$devicetype" ]] && devicetype=`nodedb $host | awk -F'|' '{print $2}' | head -1`
[[ -z "$devicetype" ]] && { fPrintHelp; exit 1; }

[[ ! -f ~/.data/input && ( -z $UsersName || -z $UsersPass ) ]] && { read -s -p "Softlayer Password: " UsersPass; echo ""; }

if [[ ! -z "$AllPhy" ]]; then
  case "$devicetype" in
    cisco)      InterfaceList=`nodedb $host -i | awk -F'|' '{print $2}' | grep "^eth\|^gig\|^ten\|^hun" | grep -v "\." | sort -n | uniq | sed ':a;N;$!ba;s/\n/ /g'`;;
    arista)     InterfaceList=`nodedb $host -i | awk -F'|' '{print $2}' | grep "^eth\|^gig\|^ten\|^hun" | grep -v "\." | sort -n | uniq | sed ':a;N;$!ba;s/\n/ /g'`;;
    juniper)    InterfaceList=`nodedb $host -i | awk -F'|' '{print $2}' | grep "^et-\|^xe-\|^ge-" | grep -v "\." | sort -n | uniq | sed ':a;N;$!ba;s/\n/ /g'`;;
  esac
fi

args=("$@")

if [[ ! -z "$InterfaceList" ]]; then
  interfacecounters `[[ ! -z $UsersName ]] && echo -u $UsersName`  `[[ ! -z $UsersPass ]] && echo -p $UsersPass` `[[ $TimeInterval -eq 1 ]] && echo -t $TimeInterval` `[[ $MinDiff -eq 1 ]] && echo --min-diff $MinDiff` `[[ $MinValue -eq 1 ]] && echo --min-value $MinValue` `[[ $PrintHost -eq 1 ]] && echo --print-host` `[[ $ErrOnly -eq 1 ]] && echo --err-only` $host $InterfaceList
  exit 0
  # case "$devicetype" in
  #   cisco)      prompt="#";commands=`echo "$InterfaceList" | sed 's/ /\n/g' | sed 's/^/\"show int /g' | sed 's/$/" /g' | awk '{ printf "%s", $0 }'`;;
  #   arista)     prompt="#";commands=`echo "$InterfaceList" | sed 's/ /\n/g' | sed 's/^/\"show int /g' | sed 's/$/\ | begin packets" /g' | awk '{ printf "%s", $0 }'`;;
  #   juniper)    prompt=">";commands=`echo "$InterfaceList" | sed 's/ /\n/g' | sed 's/^/\"show int /g' | sed 's/$/\ extensive" /g' | awk '{ printf "%s", $0 }'`;;
  # esac
else
  case "$devicetype" in
    cisco)      prompt="#";commands=`echo "$@" | sed 's/ /\n/g' | sed 's/^/\"show int /g' | sed 's/$/" /g' | awk '{ printf "%s", $0 }'`;;
    arista)     prompt="#";commands=`echo "$@" | sed 's/ /\n/g' | sed 's/^/\"show int /g' | sed 's/$/\ | begin packets" /g' | awk '{ printf "%s", $0 }'`;;
    juniper)    prompt=">";commands=`echo "$@" | sed 's/ /\n/g' | sed 's/^/\"show int /g' | sed 's/$/\ extensive" /g' | awk '{ printf "%s", $0 }'`;;
  esac
fi  

if [[ ! -z $UsersName && ! -z $UsersPass ]]; then
  CommandsOutput=`sh -c "zsshpass -u $UsersName -p $UsersPass $host $commands 2> /dev/null" | sed 's/\r//g'| sed 's/\t/ /g'`
else
  CommandsOutput=`sh -c "zsshpass $host $commands 2> /dev/null" | sed 's/\r//g'| sed 's/\t/ /g'`
fi

if [ -z $TimeInterval ]; then
  if [ $devicetype == "cisco" ]; then
  for cmdindex in $(eval echo {1..$#}); do
    ThisCmdOutput=`echo "$CommandsOutput" | egrep -A 100000 "command $cmdindex start" | egrep -B 100000 "command $cmdindex finish" | grep -v "command $cmdindex" | awk '/packets input/ { print "  RX"; print; next }1' | awk '/packets output/ { print "  TX"; print; next }1'`
      # RX
      if [[ $ErrOnly -eq 1 ]]; then
        [[ $PrintHost -eq 1 ]] && fCiscoRX | awk -v MinValue="$MinValue" '$3>=MinValue {print}' | grep -v "t_packets\|o_packet\|packets_i\|packets_o\|broadcast\|multicast\|_byte" | awk -v MinValue="$MinValue" '$3>=MinValue {print}' | sed "s/^/${host} /g" || fCiscoRX | grep -v "t_packets\|o_packet\|packets_i\|packets_o\|broadcast\|multicast\|_byte" | awk -v MinValue="$MinValue" '$3>=MinValue {print}'
      else
        [[ $PrintHost -eq 1 ]] && fCiscoRX | awk -v MinValue="$MinValue" '$3>=MinValue {print}' | sed "s/^/${host} /g" || fCiscoRX | awk -v MinValue="$MinValue" '$3>=MinValue {print}'
      fi
      # TX
      if [[ $ErrOnly -eq 1 ]]; then
        [[ $PrintHost -eq 1 ]] && fCiscoTX | grep -v "t_packets\|o_packet\|packets_i\|packets_o\|broadcast\|multicast\|_byte" | awk -v MinValue="$MinValue" '$3>=MinValue {print}' | sed "s/^/${host} /g" || fCiscoTX | grep -v "t_packets\|o_packet\|packets_i\|packets_o\|broadcast\|multicast\|_byte" | awk -v MinValue="$MinValue" '$3>=MinValue {print}'
      else
        [[ $PrintHost -eq 1 ]] && fCiscoTX | awk -v MinValue="$MinValue" '$3>=MinValue {print}' | sed "s/^/${host} /g" || fCiscoTX | awk -v MinValue="$MinValue" '$3>=MinValue {print}'
      fi
  done
  fi
  if [ $devicetype == "arista" ]; then
  for cmdindex in $(eval echo {1..$#}); do
    ThisCmdOutput=`echo "$CommandsOutput" | egrep -A 100000 "command $cmdindex start" | egrep -B 100000 "command $cmdindex finish" | grep -v "command $cmdindex"`
      # RX
      if [[ $ErrOnly -eq 1 ]]; then
        [[ $PrintHost -eq 1 ]] && fAristaRX | awk -v MinValue="$MinValue" '$3>=MinValue {print}' | grep -v "packets\|cast\|_byte" | awk -v MinValue="$MinValue" '$3>=MinValue {print}' | sed "s/^/${host} /g" || fAristaRX | grep -v "packets\|cast\|_byte" | awk -v MinValue="$MinValue" '$3>=MinValue {print}'
      else
        [[ $PrintHost -eq 1 ]] && fAristaRX | awk -v MinValue="$MinValue" '$3>=MinValue {print}' | sed "s/^/${host} /g" || fAristaRX | awk -v MinValue="$MinValue" '$3>=MinValue {print}'
      fi
      # TX
      if [[ $ErrOnly -eq 1 ]]; then
        [[ $PrintHost -eq 1 ]] && fAristaTX | grep -v "packets\|cast\|_byte" | awk -v MinValue="$MinValue" '$3>=MinValue {print}' | sed "s/^/${host} /g" || fAristaTX | grep -v "packets\|cast\|_byte" | awk -v MinValue="$MinValue" '$3>=MinValue {print}'
      else
        [[ $PrintHost -eq 1 ]] && fAristaTX | awk -v MinValue="$MinValue" '$3>=MinValue {print}' | sed "s/^/${host} /g" || fAristaTX | awk -v MinValue="$MinValue" '$3>=MinValue {print}'
      fi
  done
  fi
  if [ $devicetype == "juniper" ]; then
  for cmdindex in $(eval echo {1..$#}); do
    ThisCmdOutput=`echo "$CommandsOutput" | egrep -A 100000 "command $cmdindex start" | egrep -B 100000 "command $cmdindex finish" | grep -v "command $cmdindex" | sed 's/---(more)---//g'`
      if [[ $ErrOnly -eq 1 ]]; then
        [[ $PrintHost -eq 1 ]] && fJuniperInitial | awk -v MinValue="$MinValue" '$3>=MinValue {print}' | grep -v "_byte" | awk -v MinValue="$MinValue" '$3>=MinValue {print}' | sed "s/^/${host} /g" || fJuniperInitial | grep -v "_byte" | awk -v MinValue="$MinValue" '$3>=MinValue {print}'
      else
        [[ $PrintHost -eq 1 ]] && fJuniperInitial | awk -v MinValue="$MinValue" '$3>=MinValue {print}' | sed "s/^/${host} /g" || fJuniperInitial | awk -v MinValue="$MinValue" '$3>=MinValue {print}'
      fi
      # RX
      if [[ $ErrOnly -eq 1 ]]; then
        [[ $PrintHost -eq 1 ]] && fJuniperRX | awk -v MinValue="$MinValue" '$3>=MinValue {print}' | grep -v "_byte" | awk -v MinValue="$MinValue" '$3>=MinValue {print}' | sed "s/^/${host} /g" || fJuniperRX | grep -v "_byte" | awk -v MinValue="$MinValue" '$3>=MinValue {print}'
      else
        [[ $PrintHost -eq 1 ]] && fJuniperRX | awk -v MinValue="$MinValue" '$3>=MinValue {print}' | sed "s/^/${host} /g" || fJuniperRX | awk -v MinValue="$MinValue" '$3>=MinValue {print}'
      fi
      # TX
      if [[ $ErrOnly -eq 1 ]]; then
        [[ $PrintHost -eq 1 ]] && fJuniperTX | grep -v "_byte" | awk -v MinValue="$MinValue" '$3>=MinValue {print}' | sed "s/^/${host} /g" || fJuniperTX | grep -v "_byte" | awk -v MinValue="$MinValue" '$3>=MinValue {print}'
      else
        [[ $PrintHost -eq 1 ]] && fJuniperTX | awk -v MinValue="$MinValue" '$3>=MinValue {print}' | sed "s/^/${host} /g" || fJuniperTX | awk -v MinValue="$MinValue" '$3>=MinValue {print}'
      fi
  done
  fi
elif [ $TimeInterval -gt 0 ]; then
  FirstOutput=`interfacecounters \`[[ ! -z $UsersName ]] && echo -u $UsersName\`  \`[[ ! -z $UsersPass ]] && echo -p $UsersPass\` \`[[ $ErrOnly -eq 1 ]] && echo --err-only\` $host $@`
  sleep $TimeInterval
  SecondOutput=`interfacecounters \`[[ ! -z $UsersName ]] && echo -u $UsersName\` \`[[ ! -z $UsersPass ]] && echo -p $UsersPass\` \`[[ $ErrOnly -eq 1 ]] && echo --err-only\` $host $@`
  while read -r line; do
    ThisInterface=`echo "$line" | awk '{print $1}'`
    ThisCounter=`echo "$line" | awk '{print $2}'`
    FirstValue=`echo "$line" | awk '{print $3}'`
    # SecondValue=`echo "$SecondOutput" | head -1 | awk '{print $3}'`
    # SecondOutput=`echo "$SecondOutput" | tail -n +2`
    SecondValue=`echo "$SecondOutput" | grep "$ThisInterface $ThisCounter " | awk '{print $3}'`
    [[ "$SecondValue" -lt "$MinValue" ]] && continue
    ThisDiff=$(( SecondValue - FirstValue ))
    [[ "$ThisDiff" -lt "$MinDiff" ]] && continue
    echo `[[ ! -z $PrintHost ]] && echo "$host "` $ThisInterface $ThisCounter $FirstValue $SecondValue $ThisDiff $TimeInterval
  done < <(echo "$FirstOutput")
fi

exit 0