#!/bin/bash
# Onur

# Pre-requisites:
# imsquery
# jq
# jqflatten
# bc
# interfacecounters

fInitParams() {
  MyName=`basename "$0"`
  ToolDir=/home/oarican/tools/hostfind
  LogDir=$ToolDir/logs; [[ -d $ToolDir && ! -d $LogDir ]] && mkdir -p $LogDir
  LogFile=$LogDir/hostfind.log
  # Colour Codes
  #ClNormal="\e[39m" # Was 0 before
  ClNormal="\e[0m"
  ClBold="\e[1m"
  ClWhite="\e[29m"
  ClGreen="\e[32m"
  ClTurquoise="\e[36m"
  ClOrange="\e[33m"
  ClRed="\e[31m"
  ClGray="\e[90m"  # 37 Light gray, 90 Dark gray
  Blue=34
  # Others
  ImsQryLimit=200
  NumRegExp='^[0-9]+$'
  L2PathCheckTool=pathfind
}
fPrintHelp() {
  echo Usage:
  echo "hostfind <Primary_IP> [--l2]"
  echo "hostfind <Device_Name> [--l2]"
  echo "hostfind <HW_ID> [--l2]"
  echo ""
  echo "hostfind <HW_ID> --l2 [-t <period>] [--report|--no-report]"
}
fGetObject() {
  # fGetObject <object> <FlatJsonVar>
  # fGetObject 0.softwareComponents.1.softwareLicense.softwareDescription.longDescription DeviceProperties
  echo "${!2}" | awk -v param="$1" '$1==param' | awk '{$1=""}1' | awk '{$1=$1};1'
}
fPrintHostInfo() {
  DeviceHWID=`fGetObject 0.id DeviceProperties`
  echo -e "\n\e[93mDEVICE INFORMATION\e[1;0m"
  printf "%-16s %s\n" "Hostname: " "`fGetObject 0.hostname DeviceProperties`"
  printf "%-16s %s\n" "Hardware ID: " "$DeviceHWID"
  printf "%-16s %s\n" "Account ID: " "`fGetObject 0.accountId DeviceProperties`"
  printf "%-16s %s\n" "Datacenter: " "`fGetObject 0.datacenter.name DeviceProperties`"
  printf "%-16s %s\n" "OS Description: " "`fGetObject 0.softwareComponents.0.softwareLicense.softwareDescription.longDescription DeviceProperties`"
  printf "%-16s %s\n" "OS Username: " "`fGetObject 0.softwareComponents.0.passwords.0.username DeviceProperties`"
  printf "%-16s %s\n" "OS Password: " "`fGetObject 0.softwareComponents.0.passwords.0.password DeviceProperties`"
  printf "%-16s %s / %s    "$ClGray"(%s)"$ClNormal"\n" "Device IPs: " "`fGetObject 0.primaryBackendIpAddress DeviceProperties`" "`fGetObject 0.primaryIpAddress DeviceProperties`" "`fGetObject 0.networkManagementIpAddress DeviceProperties`"
  [[ $bCheckL2Path -eq 1 ]] && $L2PathCheckTool $DeviceHWID --no-host-info `[[ ! -z $UsersName && ! -z $UsersPass ]] && echo " -u $UsersName -p $UsersPass"` `[[ ! -z $bSamplingPeriod ]] && echo " -t $bSamplingPeriod"` `[[ ! -z $bWriteOutputToFile ]] && echo " --report" || echo " --no-report"`
}
fPrintAccountInfo() {
  echo -e "\n\e[93mACCOUNT INFORMATION\e[1;0m"
  printf "%-12s %s\n" "Name: " "`fGetObject 0.companyName AccountProperties`"
  printf "%-12s %s\n" "Account ID: " "`fGetObject 0.id AccountProperties`"
  printf "%-12s %s\n" "Country: " "`fGetObject 0.country AccountProperties`"
}
fInputIsHWID() {
  DeviceProperties=`sh -c "imsquery Hardware getAllObjects '{\"id\": {\"operation\": "$DeviceHWID"}}' $ImsQryLimit \"mask[id, hostname, domain, accountId, datacenter, networkVlans, networkManagementIpAddress, primaryBackendIpAddress, primaryIpAddress, softwareComponents[modifyDate, passwords[username, password], softwareLicense[softwareDescriptionId, softwareDescription[longDescription]]], uplinkNetworkComponents[id, name, port, primaryIpAddress, networkVlanId, macAddress, speed, status, uplink[id, uplinkComponent[id, hardwareId, name, port, duplexModeId, maxSpeed, speed, status, networkPortChannelId, networkVlanId]]], upstreamHardware[id, hostname]]\" 2> /dev/null | jqflatten -p"`
  [[ `echo "$DeviceProperties" | grep "^1" >/dev/null; echo $?` -eq 0 ]] && { echo More than 1 device found. Exiting.; exit 1; }
  fPrintHostInfo
}
fInputIsIP() {
  DeviceProperties=`sh -c "imsquery Hardware getAllObjects '{\"primaryBackendIpAddress\": {\"operation\": \"$DeviceIP\"}}' $ImsQryLimit \"mask[id, hostname, domain, accountId, datacenter, networkVlans, networkManagementIpAddress, primaryBackendIpAddress, primaryIpAddress, softwareComponents[modifyDate, passwords[username, password], softwareLicense[softwareDescriptionId, softwareDescription[longDescription]]], uplinkNetworkComponents[id, name, port, primaryIpAddress, networkVlanId, macAddress, speed, status, uplink[id, uplinkComponent[id, hardwareId, name, port, duplexModeId, maxSpeed, speed, status, networkPortChannelId, networkVlanId]]], upstreamHardware[id, hostname]]\" 2> /dev/null | jqflatten -p"`
  [[ `echo "$DeviceProperties" | grep "^1" >/dev/null; echo $?` -eq 0 ]] && { echo More than 1 device found. Exiting.; exit 1; }
  [[ `echo "$DeviceProperties" | grep "^0" >/dev/null; echo $?` -eq 0 ]] && { fPrintHostInfo; exit 0; }
  DeviceProperties=`sh -c "imsquery Hardware getAllObjects '{\"primaryIpAddress\": {\"operation\": \"$DeviceIP\"}}' $ImsQryLimit \"mask[id, hostname, domain, accountId, datacenter, networkVlans, networkManagementIpAddress, primaryBackendIpAddress, primaryIpAddress, softwareComponents[modifyDate, passwords[username, password], softwareLicense[softwareDescriptionId, softwareDescription[longDescription]]], uplinkNetworkComponents[id, name, port, primaryIpAddress, networkVlanId, macAddress, speed, status, uplink[id, uplinkComponent[id, hardwareId, name, port, duplexModeId, maxSpeed, speed, status, networkPortChannelId, networkVlanId]]], upstreamHardware[id, hostname]]\" 2> /dev/null | jqflatten -p"`
  [[ `echo "$DeviceProperties" | grep "^1" >/dev/null; echo $?` -eq 0 ]] && { echo More than 1 device found. Exiting.; exit 1; }
  [[ `echo "$DeviceProperties" | grep "^0" >/dev/null; echo $?` -eq 0 ]] && { fPrintHostInfo; exit 0; } || { echo No device found. Exiting.; exit 1; }
}
fInputIsHostname() {
  DeviceProperties=`sh -c "imsquery Hardware getAllObjects '{\"hostname\": {\"operation\": \"$DeviceName\"}}' $ImsQryLimit \"mask[id, hostname, domain, accountId, datacenter, networkVlans, networkManagementIpAddress, primaryBackendIpAddress, primaryIpAddress, softwareComponents[modifyDate, passwords[username, password], softwareLicense[softwareDescriptionId, softwareDescription[longDescription]]], uplinkNetworkComponents[id, name, port, primaryIpAddress, networkVlanId, macAddress, speed, status, uplink[id, uplinkComponent[id, hardwareId, name, port, duplexModeId, maxSpeed, speed, status, networkPortChannelId, networkVlanId]]], upstreamHardware[id, hostname]]\" 2> /dev/null | jqflatten -p"`
  [[ `echo "$DeviceProperties" | grep "^0" >/dev/null; echo $?` -ne 0 ]] && { echo No device found. Exiting.; exit 1; }
  [[ `echo "$DeviceProperties" | grep "^1" >/dev/null; echo $?` -ne 0 ]] && { fPrintHostInfo; exit 0; }
  TotalNumOfDevices=`echo "$DeviceProperties" | tail -1 | awk -F'.' '{print $1}'`
  echo -e "\n\e[1mNUM     Device Domain                        HW_ID Loc  Acc_ID  Company\e[1;0m"
  for index in `seq 0 $TotalNumOfDevices`; do
    accountId=`fGetObject $index.accountId DeviceProperties`
    AccountProperties=`sh -c "imsquery Account getAllObjects '{\"id\": {\"operation\": \"$accountId\"}}' $ImsQryLimit 2> /dev/null | jqflatten -p 2> /dev/null"`
    printf "%3s " "$index"
    # printf "%10s" "`fGetObject $index.uplinkNetworkComponents.0.status DeviceProperties`"
    printf "%10s " "$DeviceName"
    printf "%-26s" "`fGetObject $index.domain DeviceProperties`"
    printf "%9s" "`fGetObject $index.id DeviceProperties`"
    printf "%4s" "`fGetObject 0.country AccountProperties`"
    printf "%8s" "$accountId"
    printf "  %s\n" "`fGetObject 0.companyName AccountProperties`"
  done
  printf "\nYour Selection (NUM): "
  read -r NUM
  [[ $NUM -le $TotalNumOfDevices ]] && { DeviceHWID=`fGetObject $NUM.id DeviceProperties`; fInputIsHWID; }
}
fListAccountHardware() {
  TotalNumOfHardwares=`echo "$AccountHardwareList" | tail -1 | awk -F'.' '{print $1}'`
  echo -e "\n\e[1mNUM                    Device Domain                   HW_ID  Private_IP      Public_IP             Username     Password   OS\e[1;0m"
  counter=0
  for index in `seq 0 $TotalNumOfHardwares`; do
    SoftwareName=`fGetObject $index.softwareComponents.0.softwareLicense.softwareDescription.longDescription AccountHardwareList`
    [[ -z $SoftwareName ]] && continue
    let "counter++"
    printf "%3s" "$counter"
    printf "%26s " "`fGetObject $index.hostname AccountHardwareList | cut -c-25`"
    printf "%-21s" "`fGetObject $index.domain AccountHardwareList | cut -c-20`"
    printf "%9s  " "`fGetObject $index.id AccountHardwareList`"
    printf "%-16s" "`fGetObject $index.primaryBackendIpAddress AccountHardwareList`"
    printf "%-16s" "`fGetObject $index.primaryIpAddress AccountHardwareList`"
    printf "%14s " "`fGetObject $index.softwareComponents.0.passwords.0.username AccountHardwareList`"
    printf "%12s   " "`fGetObject $index.softwareComponents.0.passwords.0.password AccountHardwareList`"
    printf "%-s\n" "$SoftwareName"
  done
}
fListAccountVirtGuest() {
  TotalNumOfVirtGuests=`echo "$AccountVirtGuestList" | tail -1 | awk -F'.' '{print $1}'`
  echo -e "\n\e[1mNUM                    Device Domain                   HW_ID  Private_IP      Public_IP             Username     Password   OS\e[1;0m"
  counter=0
  for index in `seq 0 $TotalNumOfVirtGuests`; do
    SoftwareName=`fGetObject $index.softwareComponents.0.softwareLicense.softwareDescription.longDescription AccountVirtGuestList`
    [[ -z $SoftwareName ]] && continue
    let "counter++"
    printf "%3s" "$counter"
    printf "%26s " "`fGetObject $index.hostname AccountVirtGuestList | cut -c-25`"
    printf "%-21s" "`fGetObject $index.domain AccountVirtGuestList | cut -c-20`"
    printf "%9s  " "`fGetObject $index.id AccountVirtGuestList`"
    printf "%-16s" "`fGetObject $index.primaryBackendIpAddress AccountVirtGuestList`"
    printf "%-16s" "`fGetObject $index.primaryIpAddress AccountVirtGuestList`"
    printf "%14s " "`fGetObject $index.softwareComponents.0.passwords.0.username AccountVirtGuestList`"
    printf "%12s   " "`fGetObject $index.softwareComponents.0.passwords.0.password AccountVirtGuestList`"
    printf "%-s\n" "$SoftwareName"
  done
}
fAccountContent() {
  AccountProperties=`sh -c "imsquery Account getAllObjects '{\"id\": {\"operation\": \"$accountId\"}}' $ImsQryLimit 2> /dev/null | jqflatten -p 2> /dev/null"`
  fPrintAccountInfo
  AccountHardwareList=`sh -c "imsquery Hardware getAllObjects '{\"accountId\": {\"operation\": \"$accountId\"}}' $ImsQryLimit \"mask[id, hostname, domain, accountId, datacenter, networkVlans, networkManagementIpAddress, primaryBackendIpAddress, primaryIpAddress, softwareComponents[modifyDate, passwords[username, password], softwareLicense[softwareDescriptionId, softwareDescription[longDescription]]], uplinkNetworkComponents[id, name, port, primaryIpAddress, networkVlanId, macAddress, speed, status, uplink[id, uplinkComponent[id, hardwareId, name, port, duplexModeId, maxSpeed, speed, status, networkPortChannelId, networkVlanId]]], upstreamHardware[id, hostname]]\" 2> /dev/null | jqflatten -p"`
  [[ `echo "$AccountHardwareList" | grep "^0" >/dev/null; echo $?` -eq 0 ]] && fListAccountHardware
  AccountVirtGuestList=`sh -c "imsquery Virtual_Guest getAllObjects '{\"accountId\": {\"operation\": \"$accountId\"}}' $ImsQryLimit \"mask[id, hostname, domain, accountId, datacenter, networkVlans, primaryBackendIpAddress, primaryIpAddress, softwareComponents[modifyDate, passwords[username, password], softwareLicense[softwareDescriptionId, softwareDescription[longDescription]]]]\" 2> /dev/null | jqflatten -p"`
  [[ `echo "$AccountVirtGuestList" | grep "^0" >/dev/null; echo $?` -eq 0 ]] && fListAccountVirtGuest
}

[[ $# -lt 1 ]] && { fPrintHelp; exit 10; }

UsersName=`whoami`
bSamplingPeriod=20

InputParams=""
while [ $# -gt 0 ]; do
  case "$1" in
    -a)              shift;accountId=$1;shift;;
    -t)              shift;bSamplingPeriod=$1;[[ $bSamplingPeriod -lt 10 ]] && bSamplingPeriod=10;shift;;
    -u)              shift;UsersName=$1;shift;;
    -p)              shift;UsersPass=$1;shift;;
    --l2)            shift;bCheckL2Path=1;;
    --report)        bWriteOutputToFile="1";shift;;
    --no-report)     bWriteOutputToFile="";shift;;
    --debug)         DebugMode=1;shift;;
    *)               InputParams+=" $1";shift;;
  esac
done
InputParams=`echo "$InputParams" | awk '{$1=$1};1'`

fInitParams

[[ ! -f ~/.data/input && ( -z $UsersName || -z $UsersPass ) && ! -z $bCheckL2Path ]] && { read -s -p "Softlayer Password: " UsersPass; echo ""; }

[[ ! -z $accountId ]] && { fAccountContent; exit 0;}

[[ `echo "$InputParams" | wc -w` -ne 1 ]] && { fPrintHelp; echo inek; exit 10; }

[[ $InputParams =~ $NumRegExp ]] && { DeviceHWID=$InputParams; fInputIsHWID; exit 0;}
ipcalc -sc $InputParams
[[ $? -eq 0 ]] && { DeviceIP=$InputParams; fInputIsIP; exit 0;}
DeviceName=$InputParams; fInputIsHostname

exit 0