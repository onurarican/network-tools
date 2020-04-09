#!/bin/bash
# Onur

# Pre-requisites:
# imsquery
# jq
# jqflatten
# bc
# interfacecounters

# Next:
# Move DB to /var
# VLAN info
# VLAN routed info
# VRF info

fInitParams() {
  MyName=`basename "$0"`
  ToolDir=/home/oarican/tools/pathfind
  LogDir=$ToolDir/logs; [[ -d $ToolDir && ! -d $LogDir ]] && mkdir -p $LogDir
  LogFile=$LogDir/pathfind.log
  MonitorStartTime=`date '+%Y%m%d-%H%M%S'`
  MemTempFile=/dev/shm/TempFileForScript-$MonitorStartTime; cat /dev/null > $MemTempFile
  HostsFileVar=`cat /etc/hosts`
  CommandCounter=0
  # Colour Codes
  ClNormal="\e[39m" # Was 0 before
  ClWhite="\e[29m"
  ClGreen="\e[32m"
  ClTurquoise="\e[36m"
  ClOrange="\e[33m"
  ClRed="\e[31m"
  ClGray="\e[90m"  # 37 Light gray, 90 Dark gray
  Blue=34
  ImsQryLimit=100
}
fPrintHelp() {
  echo Usage:
  echo "pathfind <HWID_Server> [-t <mon_period_in_sec>] [--bps] [--no-host-info] [--report|--no-report] [--debug]"
  echo "pathfind 1742603"
}
fGetObject() {
  # fGetObject <object> <FlatJsonVar>
  # fGetObject 0.softwareComponents.1.softwareLicense.softwareDescription.longDescription DeviceProperties
  echo "${!2}" | awk -v param="$1" '$1==param' | awk '{$1=""}1' | awk '{$1=$1};1'
}
fListObjects() {
  # fListObjects <FlatJsonVar> <level_1> [<level_2> ... <level_n>]
  # fListObjects DeviceProperties 0 uplinkNetworkComponents 0
  FlatJson=$1;shift
  case "$#" in
    1) echo "${!FlatJson}" | awk -F'.' -v arg1="$1" '$1==arg1';;
    2) echo "${!FlatJson}" | awk -F'.' -v arg1="$1" -v arg2="$2" '$1==arg1 && $2==arg2';;
    3) echo "${!FlatJson}" | awk -F'.' -v arg1="$1" -v arg2="$2" -v arg3="$3" '$1==arg1 && $2==arg2 && $3==arg3';;
    4) echo "${!FlatJson}" | awk -F'.' -v arg1="$1" -v arg2="$2" -v arg3="$3" -v arg4="$4" '$1==arg1 && $2==arg2 && $3==arg3 && $4==arg4';;
    5) echo "${!FlatJson}" | awk -F'.' -v arg1="$1" -v arg2="$2" -v arg3="$3" -v arg4="$4" -v arg5="$5" '$1==arg1 && $2==arg2 && $3==arg3 && $4==arg4 && $5==arg5';;
    6) echo "${!FlatJson}" | awk -F'.' -v arg1="$1" -v arg2="$2" -v arg3="$3" -v arg4="$4" -v arg5="$5" -v arg6="$6" '$1==arg1 && $2==arg2 && $3==arg3 && $4==arg4 && $5==arg5 && $6==arg6';;
    7) echo "${!FlatJson}" | awk -F'.' -v arg1="$1" -v arg2="$2" -v arg3="$3" -v arg4="$4" -v arg5="$5" -v arg6="$6" -v arg7="$7" '$1==arg1 && $2==arg2 && $3==arg3 && $4==arg4 && $5==arg5 && $6==arg6 && $7==arg7';;
    8) echo "${!FlatJson}" | awk -F'.' -v arg1="$1" -v arg2="$2" -v arg3="$3" -v arg4="$4" -v arg5="$5" -v arg6="$6" -v arg7="$7" -v arg8="$8" '$1==arg1 && $2==arg2 && $3==arg3 && $4==arg4 && $5==arg5 && $6==arg6 && $7==arg7 && $8==arg8';;
    *) echo fListObjects: Max 8 parameters are supported. Exiting.; exit 2;;
  esac
}
fListConnections() {
  # fListConnections DeviceProperties indices $DeviceName $LocalBrand $LocalModel
  while read -r index; do
    LocalName=$3
    LocalBrand=$4
    LocalModel=$5
    if [[ $LocalBrand == "server" ]]; then
      LocalInterfaceType=`fGetObject 0.uplinkNetworkComponents.$index.name $1 | sed 's/Uplink TenGigabitEthernet/ten/' | sed 's/Uplink GigabitEthernet/gig/' | sed 's/Uplink Ethernet/eth/'`
    else
      LocalInterfaceType=`fGetObject 0.uplinkNetworkComponents.$index.name $1 | sed '/[a-zA-Z]$/ ! s/$/\//' | sed 's/Uplink TenGigabitEthernet/ten/' | sed 's/Uplink GigabitEthernet/gig/' | sed 's/Uplink Ethernet/eth/'`
    fi
    LocalInterfacePort=`fGetObject 0.uplinkNetworkComponents.$index.port $1`
    if [[ $LocalBrand == "server" ]]; then
      LocalInterfaceName=$LocalInterfaceType$LocalInterfacePort
    else
      LocalsAllInterfacesList=`nodedb $LocalName -i | awk -F'|' '{print $2}'| sort -n | uniq`
      # [[ $DebugMode -eq 1 ]] && { echo "$LocalName - LocalsAllInterfacesList - $LocalInterfaceType$LocalInterfacePort" >> $LogFile; echo "$LocalsAllInterfacesList" >> $LogFile; }
      LocalInterfaceName=`echo "$LocalsAllInterfacesList" | grep "$LocalInterfaceType$LocalInterfacePort" | head -1`
      if [[ -z $LocalInterfaceName ]]; then
        [[ $LocalBrand != "arista" ]] && LocalInterfaceName=$LocalInterfaceType$LocalInterfacePort || LocalInterfaceName=$LocalInterfaceType$LocalInterfacePort/1
      fi
    fi
    RemoteHWID=`fGetObject 0.uplinkNetworkComponents.$index.uplink.uplinkComponent.hardwareId $1`
    [[ -z $RemoteHWID ]] && continue
    UpsHWIndex=`fListObjects $1 0 upstreamHardware | awk -v RemoteHWID="$RemoteHWID" '$2==RemoteHWID' | awk -F'.' '{print $3}'`
    RemoteName=`fGetObject 0.upstreamHardware.$UpsHWIndex.hostname $1`
    # RemoteSysDescr=`zsnmpwalk $RemoteName --sysDescr`
    # for RemoteBrand in cisco arista juniper; do echo "$RemoteSysDescr" | grep -i $RemoteBrand > /dev/null; [[ $? -eq 0 ]] && break; done
    RemotesNodedbOutput=`nodedb $RemoteName`
    if [[ -z $RemotesNodedbOutput ]]; then
      FirstWordAsIs=`echo "$RemoteName" | awk -F'.' '{print $1}'`
      FirstWordWithoutAB=`echo "$FirstWordAsIs" | sed 's/a$//' | sed 's/b$//'`
      RemoteName=`echo "$RemoteName" | sed "s/$FirstWordAsIs/$FirstWordWithoutAB/"`
      RemoteBrand=`nodedb $RemoteName | awk -F'|' '{print $2}'`
    else
      RemoteBrand=`echo $RemotesNodedbOutput | awk -F'|' '{print $2}'`
    fi
    # RemoteModel
    RemoteInterfaceType=`fGetObject 0.uplinkNetworkComponents.$index.uplink.uplinkComponent.name $1 | sed '/[a-zA-Z]$/ ! s/$/\//' | sed 's/TenGigabitEthernet/ten/' | sed 's/GigabitEthernet/gig/' | sed 's/Ethernet/eth/'`
    RemoteInterfacePort=`fGetObject 0.uplinkNetworkComponents.$index.uplink.uplinkComponent.port $1`
    RemotesAllInterfacesList=`nodedb $RemoteName -i | awk -F'|' '{print $2}'| sort -n | uniq`
    # [[ $DebugMode -eq 1 ]] && { echo "$LocalName - RemotesAllInterfacesList - $RemoteInterfaceType$RemoteInterfacePort" >> $LogFile; echo "$RemotesAllInterfacesList" >> $LogFile; }
    RemoteInterfaceName=`echo "$RemotesAllInterfacesList" | grep "$RemoteInterfaceType$RemoteInterfacePort" | head -1`
    if [[ -z $RemoteInterfaceName ]]; then
      [[ $RemoteBrand != "arista" || $LocalBrand == "server" ]] && RemoteInterfaceName=$RemoteInterfaceType$RemoteInterfacePort || RemoteInterfaceName=$RemoteInterfaceType$RemoteInterfacePort/1
    fi
    # LocalsAllInterfacesList and RemotesAllInterfacesList checks are to verify if Node is found in nodedb
    if [[ $LocalBrand != "server" ]]; then
      if [[ -z $LocalsAllInterfacesList ]]; then
        [[ $DebugMode -eq 1 ]] && echo $MonitorStartTime - fListConnections:  LocalName : $LocalName icin girdik >> $LogFile
        FirstWordAsIs=`echo "$LocalName" | awk -F'.' '{print $1}'`
        FirstWordWithoutA=`echo "$FirstWordAsIs" | sed 's/a$//'`
        [[ $DebugMode -eq 1 ]] && echo $MonitorStartTime - fListConnections:  Local icin FirstWordWithoutA : $FirstWordWithoutA >> $LogFile
        LocalName=`echo "$LocalName" | sed "s/$FirstWordAsIs/$FirstWordWithoutA/"`
        [[ $DebugMode -eq 1 ]] && echo $MonitorStartTime - fListConnections:  LocalName : $LocalName olarak cikti >> $LogFile
      fi
    fi
    if [[ -z $RemotesAllInterfacesList ]]; then
      [[ $DebugMode -eq 1 ]] && echo $MonitorStartTime - fListConnections:  RemoteName : $RemoteName icin girdik >> $LogFile
      FirstWordAsIs=`echo "$RemoteName" | awk -F'.' '{print $1}'`
      FirstWordWithoutA=`echo "$FirstWordAsIs" | sed 's/a$//'`
      [[ $DebugMode -eq 1 ]] && echo $MonitorStartTime - fListConnections:  Remote icin FirstWordWithoutA : $FirstWordWithoutA >> $LogFile
      RemoteName=`echo "$RemoteName" | sed "s/$FirstWordAsIs/$FirstWordWithoutA/"`
      [[ $DebugMode -eq 1 ]] && echo $MonitorStartTime - fListConnections:  RemoteName : $RemoteName olarak cikti >> $LogFile
    fi
    echo $LocalName $LocalInterfaceName $RemoteInterfaceName $RemoteName $RemoteHWID $RemoteBrand
  done < <(echo "${!2}")
}
fListNextLevelConnections() {
# fListNextLevelConnections LevelConns
while read -r PreviousLevelNode; do
  NodeName=`echo "$PreviousLevelNode" | awk '{print $1}'`
  NodeHWID=`echo "$PreviousLevelNode" | awk '{print $2}'`
  NodeBrand=`echo "$PreviousLevelNode" | awk '{print $3}'`
  NodeModel=`nodedb $NodeName | awk -F'|' '{print $3}'`
  NodeProperties=`sh -c "imsquery Hardware getAllObjects '{\"id\": {\"operation\": $NodeHWID}}' $ImsQryLimit \"mask[id, hostname, domain, accountId, datacenter, networkVlans, networkManagementIpAddress, primaryBackendIpAddress, primaryIpAddress, softwareComponents[modifyDate, passwords[username, password], softwareLicense[softwareDescriptionId, softwareDescription[longDescription]]], uplinkNetworkComponents[id, name, port, primaryIpAddress, networkVlanId, macAddress, speed, status, uplink[id, uplinkComponent[id, hardwareId, name, port, duplexModeId, maxSpeed, speed, status, networkPortChannelId, networkVlanId]]], upstreamHardware[id, hostname]]\" 2> /dev/null | jqflatten -p"`
  [[ `echo "$NodeProperties" | grep "^1" >/dev/null; echo $?` -eq 0 ]] && { echo More than 1 device found. Exiting.; exit 1; }

  indices=`fListObjects NodeProperties 0 uplinkNetworkComponents | awk -F'.' '{print $3}' | sort | uniq`
  
  fListConnections NodeProperties indices $NodeName $NodeBrand $NodeModel
done < <(echo "${!1}" | awk '{print $4 " " $5 " " $6}' | sort | uniq)
}
fListInterfaceCountersCommands() {
  NodesAndInterfaces=`echo "$Level1Conns" | awk '{print $4 " " $3}';echo "$Level2Conns" | awk '{print $1 " " $2}';echo "$Level2Conns" | awk '{print $4 " " $3}';echo "$Level3Conns" | awk '{print $1 " " $2}';echo "$Level3Conns" | awk '{print $4 " " $3}'`
  NodesAndBrands=`echo "$Level1Conns" | awk '{print $4 " " $6}';echo "$Level2Conns" | awk '{print $4 " " $6}';echo "$Level3Conns" | awk '{print $4 " " $6}'`

  while read -r TheNode; do
    InterfaceList=`echo "$NodesAndInterfaces" | awk -v TheNode="$TheNode" '$1==TheNode {print $2}' | awk 'BEGIN {ORS=" "} {print}' | awk '{$1=$1};1'`
    NodeBrand=`echo "$NodesAndBrands" | awk -v TheNode="$TheNode" '$1==TheNode {print $2}' | head -1`
    if [[ ! -z $UsersName && ! -z $UsersPass ]]; then
      case "$NodeBrand" in
        arista)  echo "interfacecounters -u $UsersName -p $UsersPass -a $TheNode $InterfaceList";;
        cisco)   echo "interfacecounters -u $UsersName -p $UsersPass -c $TheNode $InterfaceList";;
        juniper) echo "interfacecounters -u $UsersName -p $UsersPass -j $TheNode $InterfaceList";;
      esac
    else
      case "$NodeBrand" in
        arista)  echo "interfacecounters -a $TheNode $InterfaceList";;
        cisco)   echo "interfacecounters -c $TheNode $InterfaceList";;
        juniper) echo "interfacecounters -j $TheNode $InterfaceList";;
      esac
    fi
  done < <(echo "$NodesAndBrands" | awk '{print $1}' | sort | uniq)
}
fCalculateCounterDifferences() {
  InterfaceCountersCommand=$@
  [[ ! -z $UsersName && ! -z $UsersPass ]] && Node=`echo "$InterfaceCountersCommand" | awk '{print $7}'` || Node=`echo "$InterfaceCountersCommand" | awk '{print $3}'`
  Brand=`echo "$NodeAndBrandList" | awk -v Node="$Node" '$1==Node {print $2}' | head -1`

  starttime=`date '+%s.%N' | cut -c 1-14`
  case "$Brand" in
    arista)  CountersStart=`$InterfaceCountersCommand | grep -v packets | grep -v cast`;;
    cisco)   CountersStart=`$InterfaceCountersCommand | grep -v t_packets | grep -v o_packet | grep -v packets_i | grep -v packets_o | grep -v broadcast | grep -v multicast`;;
    juniper) CountersStart=`$InterfaceCountersCommand`;;
    *)       echo cikiyoruz; break;;
  esac  
  finishtime=`date '+%s.%N' | cut -c 1-14`
  TimeToWait=`echo $(bc <<< "scale=3; $SamplingPeriod - $finishtime + $starttime ")`
  [[ ${TimeToWait:0:1} != "-" ]] && sleep $TimeToWait
  case "$Brand" in
    arista)  CountersFinish=`$InterfaceCountersCommand | grep -v packets | grep -v cast`;;
    cisco)   CountersFinish=`$InterfaceCountersCommand | grep -v t_packets | grep -v o_packet | grep -v packets_i | grep -v packets_o | grep -v broadcast | grep -v multicast`;;
    juniper) CountersFinish=`$InterfaceCountersCommand`;;
    *)       echo cikiyoruz; break;;
  esac
  while read -r CounterLine; do
    Interface=`echo "$CounterLine" | awk '{print $1}'`
    CounterName=`echo "$CounterLine" | awk '{print $2}'`
    StartValue=`echo "$CounterLine" | awk '{print $3}'`
    FinishValue=`echo "$CountersFinish" | awk -v Interface="$Interface" -v CounterName="$CounterName" '$1==Interface && $2==CounterName {print $3}'`
    ValueDiff=`echo $(bc <<< "scale=3; $FinishValue - $StartValue")`
    [[ $WriteOutputToFile -eq 1 ]] && printf "%25s     %-10s   %-28s %18s %18s %21s\n" "$Node" "$Interface" "$CounterName" "$StartValue" "$FinishValue" "$ValueDiff" >> $CountersOutputFile
    # [[ $ValueDiff -ne 0 ]] && echo $Node $Interface $CounterName $ValueDiff
    echo $Node $Interface $CounterName $StartValue $ValueDiff
  done < <(echo "$CountersStart")
}
fGetNodesInterfaceErrors() {
  # fGetNodesInterfaceErrors node interface [--bps]
  Node=$1
  Interface=$2
  [[ $# -gt 2 ]] && bBps=$3
  IncedCntrList=`echo "$CounterDiffs" | grep -v bytes | awk -v Node="$Node" -v Interface="$Interface" '$1==Node && $2==Interface && ($4!="0" || $5!="0") {print $3 ":" $4 "+" $5}'`
  [[ $bBps != "--bps" ]] && echo "$IncedCntrList" | grep -v bytes | awk 'BEGIN {ORS=" "} {print}' | awk '{$1=$1};1' || echo "$IncedCntrList" | awk 'BEGIN {ORS=" "} {print}' | awk '{$1=$1};1'
  UnchangedCntrNum=`echo "$CounterDiffs" | grep -v bytes | awk -v Node="$Node" -v Interface="$Interface" '$1==Node && $2==Interface && $5=="0" {print $3 ":" $5}' | wc -l`
  AllZeroCntrNum=`echo "$CounterDiffs" | grep -v bytes | awk -v Node="$Node" -v Interface="$Interface" '$1==Node && $2==Interface && $4=="0" && $5=="0" {print $3 ":" $5}' | wc -l`
  ChangedCntrNum=`echo "$CounterDiffs" | grep -v bytes | awk -v Node="$Node" -v Interface="$Interface" '$1==Node && $2==Interface && $5!="0" {print $3 ":" $5}' | wc -l`
  return $(( 40 * $ChangedCntrNum + $AllZeroCntrNum ))
}
fPrintHostInfo() {
  echo -e "\n\e[93mDEVICE INFORMATION\e[1;0m"
  printf "%-16s %s\n" "Hostname: " "`fGetObject 0.hostname DeviceProperties`"
  printf "%-16s %s\n" "Hardware ID: " "`fGetObject 0.id DeviceProperties`"
  printf "%-16s %s\n" "Account ID: " "`fGetObject 0.accountId DeviceProperties`"
  printf "%-16s %s\n" "Datacenter: " "`fGetObject 0.datacenter.name DeviceProperties`"
  printf "%-16s %s\n" "OS Description: " "`fGetObject 0.softwareComponents.0.softwareLicense.softwareDescription.longDescription DeviceProperties`"
  printf "%-16s %s\n" "OS Username: " "`fGetObject 0.softwareComponents.0.passwords.0.username DeviceProperties`"
  printf "%-16s %s\n" "OS Password: " "`fGetObject 0.softwareComponents.0.passwords.0.password DeviceProperties`"
  printf "%-16s %s / %s    "$ClGray"(%s)"$ClNormal"\n" "Device IPs: " "`fGetObject 0.primaryBackendIpAddress DeviceProperties`" "`fGetObject 0.primaryIpAddress DeviceProperties`" "`fGetObject 0.networkManagementIpAddress DeviceProperties`"
}

UsersName=`whoami`
SamplingPeriod=20
bPrintHost=1
[[ $# -lt 1 ]] && { fPrintHelp; exit 1; }

InputParams=""
while [ $# -gt 0 ]; do
  case "$1" in
    -t)              shift;SamplingPeriod=$1;[[ $SamplingPeriod -lt 10 ]] && SamplingPeriod=10;shift;;
    -u)              shift;UsersName=$1;shift;;
    -p)              shift;UsersPass=$1;shift;;
    --bps)           bBps=1;shift;;
    --no-host-info)  bPrintHost=0;shift;;
    --report)        WriteOutputToFile=1;shift;;
    --no-report)     WriteOutputToFile="";shift;;
    --debug)         DebugMode=1;shift;;
    *)               InputParams+=" $1";shift;;
  esac
done

fInitParams

[[ ! -f ~/.data/input && ( -z $UsersName || -z $UsersPass ) ]] && { read -s -p "Softlayer Password: " UsersPass; echo ""; }

[[ `echo "$InputParams" | wc -w` -ne 1 ]] && { fPrintHelp; exit 1; }
DeviceHWID=`echo "$InputParams" | awk '{print $1}'`

DeviceProperties=`sh -c "imsquery Hardware getAllObjects '{\"id\": {\"operation\": $DeviceHWID}}' $ImsQryLimit \"mask[id, hostname, domain, accountId, datacenter, networkVlans, networkManagementIpAddress, primaryBackendIpAddress, primaryIpAddress, softwareComponents[modifyDate, passwords[username, password], softwareLicense[softwareDescriptionId, softwareDescription[longDescription]]], uplinkNetworkComponents[id, name, port, primaryIpAddress, networkVlanId, macAddress, speed, status, uplink[id, uplinkComponent[id, hardwareId, name, port, duplexModeId, maxSpeed, speed, status, networkPortChannelId, networkVlanId]]], upstreamHardware[id, hostname]]\" 2> /dev/null | jqflatten -p"`

[[ `echo "$DeviceProperties" | grep "^1" >/dev/null; echo $?` -eq 0 ]] && { echo More than 1 device found. Exiting.; exit 1; }

[[ $bPrintHost -eq 1 ]] && fPrintHostInfo

# Status update notification for user
echo -ne "Building connections & Collecting first samples...\r"

ListOfuplinkNetworkComponents=`fListObjects DeviceProperties 0 uplinkNetworkComponents`
[[ $DebugMode -eq 1 ]] && echo "$ListOfuplinkNetworkComponents" > $LogDir/ListOfuplinkNetworkComponents.dat

DeviceName=`fGetObject 0.hostname DeviceProperties`
CountersOutputFile=$DeviceName-$MonitorStartTime-Counters.txt

indices=`fListObjects DeviceProperties 0 uplinkNetworkComponents | awk -F'.' '{print $3}' | sort | uniq`
[[ $DebugMode -eq 1 ]] && echo "$indices" > $LogDir/indices.dat

# Status update notification for user
echo -ne "Building switching level-1 connections...               \r"
Level1Conns=`fListConnections DeviceProperties indices $DeviceName server linux`
[[ $DebugMode -eq 1 ]] && { echo "Level1Conns" >> $LogFile; echo "$Level1Conns" >> $LogFile; }
# Status update notification for user
echo -ne "Building switching level-2 connections...               \r"
Level2Conns=`fListNextLevelConnections Level1Conns`
[[ $DebugMode -eq 1 ]] && { echo "Level2Conns" >> $LogFile; echo "$Level2Conns" >> $LogFile; }
# Status update notification for user
echo -ne "Building switching level-3 connections & Collecting first samples...\r"
Level3Conns=`fListNextLevelConnections Level2Conns`
[[ $DebugMode -eq 1 ]] && { echo "Level3Conns" >> $LogFile; echo "$Level3Conns" >> $LogFile; }

Lev1Backends=`echo "$Level1Conns" | awk '$4 ~ /^ *b/' | sort -nk4 | awk '{print $1 " " $2 " " $3 " " $4}'`
Lev2Backends=`echo "$Level2Conns" | awk '$1 ~ /^ *b/' | sort -n | awk '{print $1 " " $2 " " $3 " " $4}'`
Lev3Backends=`echo "$Level3Conns" | awk '$1 ~ /^ *b/' | sort -n | awk '{print $1 " " $2 " " $3 " " $4}'`
Lev1Frontends=`echo "$Level1Conns" | awk '$4 ~ /^ *f/' | sort -nk4 | awk '{print $1 " " $2 " " $3 " " $4 " " $6}'; echo ""`
Lev2Frontends=`echo "$Level2Conns" | awk '$1 ~ /^ *f/' | sort -n | awk '{print $1 " " $2 " " $3 " " $4 " " $6}'; echo ""`
Lev3Frontends=`echo "$Level3Conns" | awk '$1 ~ /^ *f/' | sort -n | awk '{print $1 " " $2 " " $3 " " $4 " " $6}'; echo ""`

ListOfInterfaceCountersCommands=`fListInterfaceCountersCommands`

NodeAndBrandList=`echo "$Level1Conns" | awk '{print $4 " " $6}';echo "$Level2Conns" | awk '{print $4 " " $6}';echo "$Level3Conns" | awk '{print $4 " " $6}'`

while read -r ThisInterfaceCountersCommand; do
  let "CommandCounter=$CommandCounter+1"
  fCalculateCounterDifferences $ThisInterfaceCountersCommand >> $MemTempFile &
  pids[${CommandCounter}]=$!
done < <(echo "$ListOfInterfaceCountersCommands")

# Status update notification for user
# Countdown notifier
for index in $(eval echo {$SamplingPeriod..1}); do
 [[ $index -gt 9 ]] && echo -ne "Waiting before collecting second samples $index                           \r" || echo -ne "Waiting before collecting second samples 0$index                           \r"
 sleep 1
done
echo -ne "Collecting second samples...                   \r"

# wait for all pids
for pid in ${pids[*]}; do
  wait $pid
done

CounterDiffs=`cat $MemTempFile`; rm -f $MemTempFile

# Clear status update notification for user
echo -ne "                                                         \r"

# Print Backends then Frontends
for nwsection in Lev1Backends Lev2Backends Lev3Backends Lev1Frontends Lev2Frontends Lev3Frontends; do
  [[ $nwsection == "Lev1Backends" ]] && echo -e "\n\e[93mBACKEND NETWORK CONNECTIONS\e[1;0m"
  [[ $nwsection == "Lev1Frontends" ]] && echo -e "\n\e[93mFRONTEND NETWORK CONNECTIONS\e[1;0m"
  while read -r line; do
    LeftNode=`echo "$line" | awk '{print $1}'`
    LeftInterface=`echo "$line" | awk '{print $2}'`
    if [[ $nwsection == "Lev1Backends" || $nwsection == "Lev1Frontends" ]]; then
      LeftIntPortNum=`echo "${LeftInterface: -1}"`
      LeftIntFlattenId=`echo "$ListOfuplinkNetworkComponents" | awk -F'.' -v LeftIntPortNum="$LeftIntPortNum" '$4=="port "LeftIntPortNum {print $3}'`
      LeftIntIP=`fGetObject 0.uplinkNetworkComponents.$LeftIntFlattenId.primaryIpAddress DeviceProperties`
      LeftIntMAC=`fGetObject 0.uplinkNetworkComponents.$LeftIntFlattenId.macAddress DeviceProperties`
    fi
    [[ -z $bBps ]] && LeftErrors=`fGetNodesInterfaceErrors $LeftNode $LeftInterface` || LeftErrors=`fGetNodesInterfaceErrors $LeftNode $LeftInterface --bps`
    RetVal=$?
    LeftSuccessNum=$(( $RetVal % 40 ))
    LeftChangedNum=$(( ( $RetVal - $LeftSuccessNum ) / 40 ))
    RightNode=`echo "$line" | awk '{print $4}'`
    RightInterface=`echo "$line" | awk '{print $3}'`
    [[ -z $bBps ]] && RightErrors=`fGetNodesInterfaceErrors $RightNode $RightInterface` || RightErrors=`fGetNodesInterfaceErrors $RightNode $RightInterface --bps`
    RetVal=$?
    RightSuccessNum=$(( $RetVal % 40 ))
    RightChangedNum=$(( ( $RetVal - $RightSuccessNum ) / 40 ))
    [[ $nwsection == "Lev1Backends" || $nwsection == "Lev1Frontends" ]] && printf "%36s%18s %28s %9s " "$LeftIntIP" "$LeftIntMAC" "$LeftNode" "$LeftInterface" || printf ""$ClGray"%50s \xE2\x9C\x94%-2s"$ClNormal" %28s %9s " "$LeftErrors" "$LeftSuccessNum" "$LeftNode" "$LeftInterface"
    printf "-"
    if [[ -z $LeftErrors ]]; then
      if [[ $LeftSuccessNum -ne 0 ]]; then
        printf ""$ClGreen"\xE2\x9C\x94"$ClNormal""
      else
        if [[ $nwsection == "Lev1Backends" || $nwsection == "Lev1Frontends" ]]; then
          printf "-"
        else
          printf ""$ClOrange"?"$ClNormal""
        fi
      fi
    else
      if [[ $LeftChangedNum -eq 0 ]]; then
        printf ""$ClOrange"\x21"$ClNormal""
      else
        printf ""$ClRed"\x21"$ClNormal""
      fi
    fi
    echo -n "--"
    if [[ -z $RightErrors ]]; then
      if [[ $RightSuccessNum -ne 0 ]]; then
        printf ""$ClGreen"\xE2\x9C\x94"$ClNormal""
      else
        printf ""$ClOrange"?"$ClNormal""
      fi
    else
      if [[ $RightChangedNum -eq 0 ]]; then
        printf ""$ClOrange"\x21"$ClNormal""
      else
        printf ""$ClRed"\x21"$ClNormal""
      fi
    fi
    printf "-"
    printf " %-9s %-28s"$ClGray"\xE2\x9C\x94%-2s %-50s"$ClNormal"" "$RightInterface" "$RightNode" "$RightSuccessNum" "$RightErrors"; echo ""
  done < <(echo "${!nwsection}"); echo ""
done

if [[ $WriteOutputToFile -eq 1 ]]; then
  CountersOutputVar=`cat $CountersOutputFile`
  printf "%25s     %-10s   %-28s %18s %18s %21s\n" "Node" "Interface" "Counter" "Value (Before)" "Value (After)" "ValueDiff in $SamplingPeriod sec" > $CountersOutputFile
  echo "$CountersOutputVar" | sort -n >> $CountersOutputFile
fi

exit 0