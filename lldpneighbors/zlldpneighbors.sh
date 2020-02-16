#!/bin/bash
# Onur

# Output Format
# Node|Interface|PoOfIt|NeigInterface|NeigDevice

fPrintHelp() {
  echo Usage:
  echo -e "zlldpneighbors <Device>\n"
}

fInitParams() {
  MyHome=/home/oarican
  ToolDir=$MyHome/tools/neighbors
}
fListForCisco() {
  if [[ $NodeModel != "WS-C6509-V-E" ]]; then
    LldpNeighborsCmdOutput=`sh -c "zsshpass $NodeName \"sh lldp nei\" 2> /dev/null" | sed $'s/[^[:print:]\t]//g' | egrep -A 100000 "command 1 start" | egrep -B 100000 "command 1 finish" | grep -v "command 1 "`
    echo "$LldpNeighborsCmdOutput" | sed 's/Device ID.*$//g' | egrep -A 100000 "^$" | grep -v "Total entries displayed\|^$" | awk -v NodeName="$NodeName" '{print NodeName "|" $2 "|" $5 "|" $1}' | sed 's/HundredGigE/hun/g' | sed 's/TenGigabitEthernet/ten/g' | sed 's/GigabitEthernet/gig/g' | sed 's/Ethernet/eth/g' | sed 's/Te/ten/g' | sed 's/Eth/eth/g' | sed 's/\.networklayer\.com$//' | sed 's/-re.$//'
  else
    LldpNeighborsCmdOutput=`sh -c "zsshpass $NodeName \"sh lldp nei det | i System|Port|Intf\" 2> /dev/null" | sed $'s/[^[:print:]\t]//g' | egrep -A 100000 "command 1 start" | egrep -B 100000 "command 1 finish" | grep -v "command 1 "`
    LocIntf=""; RemIntf=""; RemNode=""
    while read -r line; do
      FirstWord=`echo "$line" | awk '{print $1}'`
      case "$FirstWord" in
        Local)  LocIntf=`echo "$line" | awk '$1=="Local" && $2=="Intf:" {print $3}'`;;
        Port)   RemIntf=`echo "$line" | awk '$1=="Port" && $2=="id:" {print $3}'`;;
        System) RemNode=`echo "$line" | awk '$1=="System" && $2=="Name:" {print $3}'`;;
      esac
      [[ ! -z $LocIntf && ! -z $RemIntf && ! -z $RemNode ]] && { echo "$NodeName|$LocIntf|$RemIntf|$RemNode" | sed 's/HundredGigE/hun/g' | sed 's/TenGigabitEthernet/ten/g' | sed 's/GigabitEthernet/gig/g' | sed 's/Ethernet/eth/g' | sed 's/Te/ten/g' | sed 's/Eth/eth/g' | sed 's/\.networklayer\.com$//' | sed 's/-re.$//'; LocIntf=""; RemIntf=""; RemNode=""; }
    done < <( echo "$LldpNeighborsCmdOutput" | grep "Local Intf:\|Port id:\|System Name:")
  fi
}
fListForArista() {
  LldpNeighborsCmdOutput=`sh -c "zsshpass $NodeName \"sh lldp nei\" 2> /dev/null" | egrep -A 100000 "command 1 start" | egrep -B 100000 "command 1 finish" | grep -v "command 1 "`
  echo "$LldpNeighborsCmdOutput" | egrep -A 100000 "Neighbor Device ID" | grep -v "Neighbor Device ID" | awk -v NodeName="$NodeName" '{print NodeName "|" $1 "|" $3 "|" $2}' | sed 's/HundredGigE/hun/g' | sed 's/TenGigabitEthernet/ten/g' | sed 's/GigabitEthernet/gig/g' | sed 's/Ethernet/eth/g' | sed 's/Te/ten/g' | sed 's/Eth/eth/g' | sed 's/\.networklayer\.com$//' | sed 's/-re.$//'
}
fListForJuniper() {
  LldpNeighborsCmdOutput=`sh -c "zsshpass $NodeName \"show lldp neighbors\" 2> /dev/null" | egrep -A 100000 "command 1 start" | egrep -B 100000 "command 1 finish" | grep -v "command 1 "`
  case "$NodeModel" in
    qfx10008 | qfx10002-72q)
              LldpLocalInterfaces=`echo "$LldpNeighborsCmdOutput" | egrep -A 100000 "Parent Interface" | egrep -B 100000 "{master" | grep -v "Parent Interface\|{master\|^$" | awk '{print $1}'`
              commands=`echo "$LldpLocalInterfaces" | sed 's/^/\"show lldp neighbors interface /g' | sed 's/$/\ | match \\\"^Port ID|^System name|^Local interface|^Parent interface\\\"" /g' | awk '{   printf "%s", $0 }'`
              LldpNeighborsInterfacesCmdOutput=`sh -c "zsshpass $NodeName $commands 2> /dev/null"`
              NumOfInterfaces=`echo "$LldpLocalInterfaces" | wc -l`
              for index in $(eval echo {1..$NumOfInterfaces}); do
                ConnectionInfo=`echo "$LldpNeighborsInterfacesCmdOutput" | egrep -A 100000 "command $index start" | egrep -B 100000 "command $index finish" | grep -v "command $index "`
                LocIntf=`echo "$ConnectionInfo" | awk '$1=="Local" && $2=="Interface" {print $4}'`
                RemIntf=`echo "$ConnectionInfo" | awk '$1=="Port" && $2=="ID" {print $4}'`
                RemNode=`echo "$ConnectionInfo" | awk '$1=="System" && $2=="name" {print $4}'`
                echo "$NodeName|$LocIntf|$RemIntf|$RemNode" | sed 's/HundredGigE/hun/g' | sed 's/TenGigabitEthernet/ten/g' | sed 's/GigabitEthernet/gig/g' | sed 's/Ethernet/eth/g' | sed 's/Te/ten/g' | sed 's/Eth/eth/g' | sed 's/\.networklayer\.com$//' | sed 's/-re.$//'
              done;;
    mx80-t)   echo "$LldpNeighborsCmdOutput" | egrep -A 100000 "^Local Interface" | egrep -B 100000 -m 1 "^$" | grep -v "^Local Interface\|{master}\|^$" | awk -v NodeName="$NodeName" '{print NodeName "|" $1 "|" $3 "|" $4}' | sed 's/HundredGigE/hun/g' | sed 's/TenGigabitEthernet/ten/g' | sed 's/GigabitEthernet/gig/g' | sed 's/Ethernet/eth/g' | sed 's/Te/ten/g' | sed 's/Eth/eth/g' | sed 's/\.networklayer\.com$//' | sed 's/-re.$//';;
    *)        echo "$LldpNeighborsCmdOutput" | egrep -A 100000 "^Local Interface" | egrep -B 100000 -m 1 "^$" | grep -v "^Local Interface\|{master\|^$" | awk -v NodeName="$NodeName" '{print NodeName "|" $1 "|" $4 "|" $5}' | sed 's/HundredGigE/hun/g' | sed 's/TenGigabitEthernet/ten/g' | sed 's/GigabitEthernet/gig/g' | sed 's/Ethernet/eth/g' | sed 's/Te/ten/g' | sed 's/Eth/eth/g' | sed 's/\.networklayer\.com$//' | sed 's/-re.$//';;
  esac
}

fInitParams

NodeName=$1
NodeInfo=`nodedb $NodeName`
NodeBrand=`echo "$NodeInfo" | awk -F'|' '{print $2}'`
NodeModel=`echo "$NodeInfo" | awk -F'|' '{print $3}'`

case "$NodeBrand" in
  cisco)   fListForCisco;;
  arista)  fListForArista;;
  juniper) fListForJuniper;;
  *)       fPrintHelp;exit 1;;
esac

exit 0