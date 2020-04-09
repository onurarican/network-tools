#!/bin/bash
# Onur

fInitParams() {
  ToolDir=/home/oarican/tools/nodedb
  NodeDbDir=$ToolDir/db
  [[ ! -d $NodeDbDir ]] && NodeDbDir=/var/tools/nodedb/db
  BackupsMineDir=$ToolDir/backups.mine
  DCList=`ls $NodeDbDir`
  NonCsList=`echo -e "fas\nbas\nfcr\nbcr\ndar\nmbr\nppr\nbbr\ncbs\nxcr\nxcs\nslr\nrr\nbrr\nirr\nerr\nnpr\nnps\nfpr\nmsr\nmss\nir\nlbr\nlbs\nzer"`
  TftpConfigsDir=/var/lib/tftpboot/backups.git
  TftpDCList=`ls $TftpConfigsDir 2> /dev/null`
  HostsOutput=`cat /etc/hosts`
  AllIrrList=`echo "$HostsOutput" | grep " irr\| lo0.irr" | awk '{print $2}' | sed 's/^lo0.//g' | sort -n | uniq`
  AllErrList=`echo "$HostsOutput" | grep " err\| lo0.err" | awk '{print $2}' | sed 's/^lo0.//g' | sort -n | uniq`
}
fPrintHelp() {
  echo Usage:
  echo "nodedb <node_name> [-i [<interface>]]"
  echo "nodedb <dc_name> <pattern>"
  echo "nodedb all <pattern>"  
  echo "nodedb <IP>"
  echo "nodedb { { --populate-confs } | { [--build-db-nodetype] [--build-db-nodeintf] } }"
}
fCreateNonExistentDirs() {
  for tftplistdc in $TftpDCList; do [[ ! -d $NodeDbDir/$tftplistdc ]] && mkdir $NodeDbDir/$tftplistdc; done
}
fConvertIpSnLinesToCIDR() {
  # fConvertIpSnLinesToCIDR <IntfIpConf_Var>
  while read -r IpLine; do
    [[ `echo "$IpLine" | awk '{print $3}' | awk -F'/' '$2!=""' | wc -l` -eq 1 ]] && { echo "$IpLine"; continue; }
    PossSn=`echo "$IpLine" | awk '{print $4}'`
    PossPrefix=`ipcalc -ps $(echo "$IpLine" | awk '{print $3}') $PossSn | awk -F'=' '{print $2}'`
    [[ $? -eq 0 ]] && echo "$IpLine" | awk -v PossPrefix="$PossPrefix" '{ $3 = $3"/"PossPrefix; $4 = ""; print $0; }' || echo "$IpLine"
  done < <(echo "${!1}")
}
fPopulateBackupsMine() {
  for ThisNode in $AllIrrList $AllErrList; do
    ThisDCPortion=`echo "$ThisNode" | awk -F'.' '{print $NF}'`
    ThisRole=`echo "$ThisNode" | sed 's/[^a-zA-Z].*$//'`

    # Assuming all devices under backups.mine directory are juniper
    ThisConf=`timeout 90 zsshpass $ThisNode "show configuration | display set" 2> /dev/null | egrep -A 100000 -m 1 "show configuration " | egrep -B 100000 -m 1 "^$" | grep -v "show configuration \|^$"`
    [[ -z $ThisConf ]] && continue
    [[ ! -d $BackupsMineDir/$ThisDCPortion/$ThisRole ]] && mkdir -p $BackupsMineDir/$ThisDCPortion/$ThisRole
    echo "$ThisConf" > $BackupsMineDir/$ThisDCPortion/$ThisRole/$ThisNode.cfg
  done
}
fCreateNodeTypeList() {
  # fCreateNodeTypeList <dc> {fcs|bcs|noncs} <nodetype>.list
  # fCreateNodeTypeList dal13 fcs fcs.list
  dcname=$1
  nodetype=$2
  outfile=$3

  # nodetypesfilelist=`ls -t $TftpConfigsDir/$dcname/$nodetype | grep "\.cfg$"; ls -t $BackupsMineDir/$dcname/$nodetype | grep "\.cfg$"`
  nodetypesfilenamelist=`echo "$HostsOutput" | awk '{print $2}' | grep "\.$dcname$" | sed 's/^lo.\.//' | grep "^$nodetype" | sort -n | uniq`
  # nodetypesfilelist=`find $TftpConfigsDir/$dcname/$nodetype -mtime -21 -type f -printf '%f\n' | grep "\.cfg$"`
  [[ -z $nodetypesfilenamelist ]] && return 1
  for nodename in $nodetypesfilenamelist; do
    # Check if node is listening to TCP port 22
    nc -z $nodename 22 -w 1 > /dev/null; [[ $? -ne 0 ]] && continue
    typesfile=$nodename.cfg
    # typesaltfile=`echo "$typesfile" | sed 's/\./a\./'`
    noderole=`echo "$nodename" | sed 's/[^a-zA-Z].*$//'`
    nodebrand=""
    # if [[ -f $TftpConfigsDir/$dcname/$nodetype/$typesaltfile && ! -f $TftpConfigsDir/$dcname/$nodetype/$typesfile ]] && typesfile=$typesaltfile
    # If $nodename.cfg doesn't exist in $TftpConfigsDir retrieve the config and locate in $BackupsMineDir
    if [[ ! -f $TftpConfigsDir/$dcname/$nodetype/$typesfile ]]; then
      ThisConf=`timeout 90 zsshpass $nodename "show configuration | display set" 2> /dev/null | sed $'s/[^[:print:]\t]//g' | egrep -A 200000 -m 1 "command 1 start" | egrep -B 200000 -m 1 "^$" | grep -v "command 1 \|^$"`
      [[ `echo "$ThisConf" | wc -l` -lt 20 ]] && ThisConf=`timeout 90 zsshpass -d 30 $nodename "show run" 2> /dev/null | sed $'s/[^[:print:]\t]//g' | egrep -A 200000 -m 1 "command 1 start" | egrep -B 200000 -m 1 "command 1 finish" | grep -v "command 1 "`
      [[ ! -d $BackupsMineDir/$dcname/$noderole ]] && mkdir -p $BackupsMineDir/$dcname/$noderole
      # [[ $nodename == "bcr01.dal06" ]] && { echo 1 $nodename; echo "$ThisConf" | wc -l; }
      [[ `echo "$ThisConf" | wc -l` -ge 20 ]] && echo "$ThisConf" > $BackupsMineDir/$dcname/$noderole/$nodename.cfg
    # If $nodename.cfg exist in $TftpConfigsDir, but incorrect display format (too many '{'s) retrieve the config and locate in $BackupsMineDir
    # Or $nodename.cfg isn't Juniper (no ^set), and contains less than 4 interfaces (^interface) in it, retrieve the config and locate in $BackupsMineDir
    elif [[ `grep "^ *}" $TftpConfigsDir/$dcname/$nodetype/$typesfile | wc -l` -gt 5 || ( `grep "^set" $TftpConfigsDir/$dcname/$nodetype/$typesfile | wc -l` -eq 0 && `grep "^interface" $TftpConfigsDir/$dcname/$nodetype/$typesfile | wc -l` -lt 4 ) ]]; then
      ThisConf=`timeout 90 zsshpass $nodename "show configuration | display set" 2> /dev/null | sed $'s/[^[:print:]\t]//g' | egrep -A 200000 -m 1 "command 1 start" | egrep -B 200000 -m 1 "^$" | grep -v "command 1 \|^$"`
      [[ `echo "$ThisConf" | wc -l` -lt 20 ]] && ThisConf=`timeout 90 zsshpass -d 30 $nodename "show run" 2> /dev/null | sed $'s/[^[:print:]\t]//g' | egrep -A 200000 -m 1 "command 1 start" | egrep -B 200000 -m 1 "command 1 finish" | grep -v "command 1 "`
      [[ ! -d $BackupsMineDir/$dcname/$noderole ]] && mkdir -p $BackupsMineDir/$dcname/$noderole
      # [[ $nodename == "bcr01.dal06" ]] && { echo 2 $nodename; echo "$ThisConf" | wc -l; }
      [[ `echo "$ThisConf" | wc -l` -ge 20 ]] && echo "$ThisConf" > $BackupsMineDir/$dcname/$noderole/$nodename.cfg
    else
      rm -f $BackupsMineDir/$dcname/$nodetype/$nodename.cfg 2> /dev/null
    fi
    nodeinfoline=""
    [[ -f $BackupsMineDir/$dcname/$nodetype/$nodename.cfg ]] && nodeinfoline=`head -200 $BackupsMineDir/$dcname/$nodetype/$nodename.cfg` || nodeinfoline=`head -200 $TftpConfigsDir/$dcname/$nodetype/$typesfile`
    [[ -z $nodeinfoline ]] && continue
    infospecifictoarista=`echo "$nodeinfoline" | awk -v nodename="$nodename" '$2=="device:" && $3==nodename'`
    [[ ! -z $infospecifictoarista ]] && { nodebrand=arista; nodemodel=`echo "$infospecifictoarista" | awk '{print $4}' | sed 's/^(//' | sed 's/,$//'`; nodeswver=`echo "$infospecifictoarista" | awk '{print $5}' | sed 's/)$//'`; }
    infospecifictocisconexus=`echo "$nodeinfoline" | awk '$1=="!Command:" && $2=="show" && ($3=="startup-config" || $3=="running-config")'`
    versionspecifictocisco=`echo "$nodeinfoline" | awk '$1=="version" {print $2}'`
    [[ ! -z $infospecifictocisconexus ]] && { nodebrand=cisco; nodemodel=""; nodeswver=$versionspecifictocisco; }
    [[ -z $infospecifictocisconexus && ! -z $versionspecifictocisco ]] && { nodebrand=cisco; nodemodel=6509; nodeswver=$versionspecifictocisco; }
    infospecifictojuniper=`echo "$nodeinfoline" | awk '$1=="set" && $2=="version"'`
    [[ ! -z $infospecifictojuniper ]] && { nodebrand=juniper; nodemodel=""; nodeswver=`echo "$infospecifictojuniper" | awk '{print $3}'`; }
    if [[ ! -z $nodebrand ]]; then
      case "$nodebrand" in
        cisco)    RealHostName=`echo "$nodeinfoline" | awk '$1=="hostname" && $3=="" {print $2}'`;
                  ShVerOutput=`sh -c "timeout 90 zsshpass -l $RealHostName \"show version\" 2> /dev/null" | sed $'s/[^[:print:]\t]//g'`;
                  nodemodel=`echo "$ShVerOutput" | sed 's/Nexus /Nexus/g' | awk '$1=="cisco" {print $2}' | head -1`;;
        arista)   RealHostName=`echo "$nodeinfoline" | awk '$1=="hostname" && $3=="" {print $2}'`;;
        juniper)  RealHostName=`echo "$nodeinfoline" | awk '$1=="set" && $2=="groups" && $3=="re0" && $4=="system" && $5=="host-name" && $7=="" {print $6}' | sed 's/-re0$//'`;
                  [[ -z $RealHostName ]] && RealHostName=`echo "$nodeinfoline" | awk '$1=="set" && $2=="system" && $3=="host-name" && $5=="" {print $4}' | sed 's/-re0$//'`;
                  ShVerOutput=`sh -c "timeout 90 zsshpass -l $RealHostName \"show version\" 2> /dev/null" | sed $'s/[^[:print:]\t]//g'`;
                  nodemodel=`echo "$ShVerOutput" | awk '$1=="Model:" {print $2}' | head -1`;
                  nodeswver=`echo "$ShVerOutput" | awk '$1=="Junos:" {print $2}' | head -1`;
                  [[ -z $nodeswver ]] && nodeswver=`echo "$infospecifictojuniper" | awk '{print $3}'`;;
        *)        continue;;
      esac
      [[ `awk -F'|' -v RealHostName="$RealHostName" '$1==RealHostName' $outfile | wc -l` -eq 0 ]] && echo "$RealHostName|$nodebrand|$nodemodel|$nodeswver" >> $outfile
    fi
  done
}
fCreateNodeInterfaceList() {
  # fCreateNodeInterfaceList <dc> {fcs|bcs|noncs} <nodetype>.list
  # fCreateNodeInterfaceList dal13 fcs fcs.list
  dcname=$1
  nodetype=$2
  outfile=$3

  # nodetypesfilelist=`ls -t $TftpConfigsDir/$dcname/$nodetype | grep "\.cfg$"; ls -t $BackupsMineDir/$dcname/$nodetype | grep "\.cfg$"`
  nodetypesfilenamelist=`echo "$HostsOutput" | awk '{print $2}' | grep "\.$dcname$" | sed 's/^lo.\.//' | grep "^$nodetype" | sort -n | uniq`
  # nodetypesfilelist=`find $TftpConfigsDir/$dcname/$nodetype -mtime -21 -type f -printf '%f\n' | grep "\.cfg$"`
  [[ -z $nodetypesfilenamelist ]] && return 1
  for nodename in $nodetypesfilenamelist; do
    # Check if node is listening to TCP port 22
    nc -z $nodename 22 -w 1 > /dev/null; [[ $? -ne 0 ]] && continue
    typesfile=$nodename.cfg
    # typesaltfile=`echo "$typesfile" | sed 's/\./a\./'`
    # [[ -f $TftpConfigsDir/$dcname/$nodetype/$typesaltfile && ! -f $TftpConfigsDir/$dcname/$nodetype/$typesfile ]] && typesfile=$typesaltfile

    NodeCfgVar=""
    [[ -f $BackupsMineDir/$dcname/$nodetype/$nodename.cfg ]] && NodeCfgVar=`cat $BackupsMineDir/$dcname/$nodetype/$nodename.cfg` || NodeCfgVar=`cat $TftpConfigsDir/$dcname/$nodetype/$typesfile`
    [[ -z $NodeCfgVar ]] && continue

    nodeinfoline=`echo "$NodeCfgVar" | head -200`
    infospecifictoarista=`echo "$nodeinfoline" | awk -v nodename="$nodename" '$2=="device:" && $3==nodename'`
    if [[ ! -z $infospecifictoarista ]]; then
      RealHostName=`echo "$nodeinfoline" | awk '$1=="hostname" && $3=="" {print $2}'`
      [[ `awk -F'|' -v RealHostName="$RealHostName" '$1==RealHostName' $outfile | wc -l` -ne 0 ]] && continue
      LldpOutput=`timeout 90 lldpneighbors $RealHostName`
      while read -r IntfName; do
        PoOfIntf=""; LogSysOfIntf=""; VrfOfIntf=""; VlanOfIntf=""; IpOfIntf=""; DescrOfIntf=""; NeigDevice=""; NeigInterface=""; LldpNeigDevice=""; LldpNeigInterface=""
        IntfConfig=`echo "$NodeCfgVar" | egrep -A 100 "^interface $IntfName$" | grep -v "^interface $IntfName$" | egrep -B 100 -m 1 -v "^ " | head -n -1`
        VlanOfIntf=`echo $IntfName | grep -i vlan | cut -c 5-`
        [[ -z $VlanOfIntf ]] && VlanOfIntf=`echo "$IntfConfig" | awk '$1=="switchport" && $2=="access" && $3=="vlan" {print $4}'`
        IntfDescr=`echo "$IntfConfig" | awk '$1=="description" {$1 = ""; print $0; }' | awk '{$1=$1};1'`
        DescrOfIntf=`echo "$IntfDescr" | sed 's/|/-/g'`
        PossibleRemoteInfo=`echo "$IntfDescr" | awk -F'|' '{print $2}'`
        if [[ ! -z $PossibleRemoteInfo ]]; then
          NeigDevice=`echo "$PossibleRemoteInfo" | sed 's/::/ /g' | awk '{print $2}'`
          NeigInterface=`echo "$PossibleRemoteInfo" | sed 's/::/ /g' | awk '{print $3}'`
        fi
        IntfIpConfig=`echo "$IntfConfig" | awk '$1=="ip" && $2=="address"'`
        IpOfIntf=`fConvertIpSnLinesToCIDR IntfIpConfig | awk '$1=="ip" && $2=="address" {print $3}' | sed ':a;N;$!ba;s/\n/,/g'`
        PoOfIntf=`echo "$IntfConfig" | awk '$1=="channel-group" {print "port-channel" $2}'`
        VrfOfIntf=`echo "$IntfConfig" | awk '$1=="vrf" && ( $2=="member" || $2=="forwarding" ) && $4=="" {print $3}'`
        IntfName=`echo "$IntfName" | sed 's/HundredGigE/hun/g' | sed 's/TenGigabitEthernet/ten/g' | sed 's/GigabitEthernet/gig/g' | sed 's/Ethernet/eth/g' | sed 's/Te/ten/g' | sed 's/Eth/eth/g' | sed 's/.ort-.hannel/po/' | sed 's/Po/po/' | sed 's/Vlan/vlan/' | sed 's/loopback/lo/' | sed 's/Loopback/lo/' | sed 's/Management/management/'`
        LldpNeigDevice=`echo "$LldpOutput" | awk -F'|' -v IntfName="$IntfName" '$2==IntfName {print $4}'`
        LldpNeigInterface=`echo "$LldpOutput" | awk -F'|' -v IntfName="$IntfName" '$2==IntfName {print $3}'`
        echo "$RealHostName|$IntfName|$PoOfIntf|$LogSysOfIntf|$VrfOfIntf|$VlanOfIntf|$IpOfIntf|$DescrOfIntf|$NeigDevice|$NeigInterface|$LldpNeigDevice|$LldpNeigInterface" >> $outfile
      done < <(echo "$NodeCfgVar" | awk '$1=="interface" && $3=="" {print $2}')
    fi
    versionspecifictocisco=`echo "$nodeinfoline" | awk '$1=="version" {print $2}'`
    if [[ ! -z $versionspecifictocisco ]]; then
      RealHostName=`echo "$nodeinfoline" | awk '$1=="hostname" && $3=="" {print $2}'`
      [[ `awk -F'|' -v RealHostName="$RealHostName" '$1==RealHostName' $outfile | wc -l` -ne 0 ]] && continue
      LldpOutput=`timeout 90 lldpneighbors $RealHostName`
      while read -r IntfName; do
        PoOfIntf=""; LogSysOfIntf=""; VrfOfIntf=""; VlanOfIntf=""; IpOfIntf=""; DescrOfIntf=""; NeigDevice=""; NeigInterface=""; LldpNeigDevice=""; LldpNeigInterface=""
        IntfConfig=`echo "$NodeCfgVar" | egrep -A 100 "^interface $IntfName$" | grep -v "^interface $IntfName$" | egrep -B 100 -m 1 -v "^ " | head -n -1`
        VlanOfIntf=`echo $IntfName | grep -i vlan | cut -c 5-`
        [[ -z $VlanOfIntf ]] && VlanOfIntf=`echo "$IntfConfig" | awk '$1=="switchport" && $2=="access" && $3=="vlan" {print $4}'`
        IntfDescr=`echo "$IntfConfig" | awk '$1=="description" {$1 = ""; print $0; }' | awk '{$1=$1};1'`
        DescrOfIntf=`echo "$IntfDescr" | sed 's/|/-/g'`
        PossibleRemoteInfo=`echo "$IntfDescr" | awk -F'|' '{print $2}'`
        if [[ ! -z $PossibleRemoteInfo ]]; then
          NeigDevice=`echo "$PossibleRemoteInfo" | sed 's/::/ /g' | awk '{print $2}'`
          NeigInterface=`echo "$PossibleRemoteInfo" | sed 's/::/ /g' | awk '{print $3}'`
        fi
        IntfIpConfig=`echo "$IntfConfig" | awk '$1=="ip" && $2=="address"'`
        IpOfIntf=`fConvertIpSnLinesToCIDR IntfIpConfig | awk '$1=="ip" && $2=="address" {print $3}' | sed ':a;N;$!ba;s/\n/,/g'`
        PoOfIntf=`echo "$IntfConfig" | awk '$1=="channel-group" {print "port-channel" $2}'`
        VrfOfIntf=`echo "$IntfConfig" | awk '$1=="vrf" && ( $2=="member" || $2=="forwarding" ) && $4=="" {print $3}'`
        IntfName=`echo "$IntfName" | sed 's/HundredGigE/hun/g' | sed 's/TenGigabitEthernet/ten/g' | sed 's/GigabitEthernet/gig/g' | sed 's/Ethernet/eth/g' | sed 's/Te/ten/g' | sed 's/Eth/eth/g' | sed 's/.ort-.hannel/po/' | sed 's/Po/po/' | sed 's/Vlan/vlan/' | sed 's/loopback/lo/' | sed 's/Loopback/lo/' | sed 's/Management/management/'`
        LldpNeigDevice=`echo "$LldpOutput" | awk -F'|' -v IntfName="$IntfName" '$2==IntfName {print $4}'`
        LldpNeigInterface=`echo "$LldpOutput" | awk -F'|' -v IntfName="$IntfName" '$2==IntfName {print $3}'`
        echo "$RealHostName|$IntfName|$PoOfIntf|$LogSysOfIntf|$VrfOfIntf|$VlanOfIntf|$IpOfIntf|$DescrOfIntf|$NeigDevice|$NeigInterface|$LldpNeigDevice|$LldpNeigInterface" >> $outfile
      done < <(echo "$NodeCfgVar" | awk '$1=="interface" && $3=="" {print $2}')
    fi
    infospecifictojuniper=`echo "$nodeinfoline" | awk '$1=="set" && $2=="version"'`
    if [[ ! -z $infospecifictojuniper ]]; then
      RealHostName=`echo "$nodeinfoline" | awk '$1=="set" && $2=="groups" && $3=="re0" && $4=="system" && $5=="host-name" && $7=="" {print $6}' | sed 's/-re0$//'`
      [[ -z $RealHostName ]] && RealHostName=`echo "$nodeinfoline" | awk '$1=="set" && $2=="system" && $3=="host-name" && $5=="" {print $4}' | sed 's/-re0$//'`
      [[ `awk -F'|' -v RealHostName="$RealHostName" '$1==RealHostName' $outfile | wc -l` -ne 0 ]] && continue
      LldpOutput=`timeout 90 lldpneighbors $RealHostName`
      NodeCfgVar=`echo "$NodeCfgVar" | sed 's/ unit /\./g'`
      while read -r IntfName; do
        PoOfIntf=""; LogSysOfIntf=""; VrfOfIntf=""; VlanOfIntf=""; IpOfIntf=""; DescrOfIntf=""; NeigDevice=""; NeigInterface=""; LldpNeigDevice=""; LldpNeigInterface=""
        VrfOfIntf=`echo "$NodeCfgVar" | awk -v IntfName="$IntfName" '$1=="set" && $2=="routing-instances" && $4=="interface" && $5==IntfName {print $3}'`
        IntfBaseName=`echo "$IntfName" | sed 's/\..*$//'`
        IntfBaseConfig=`echo "$NodeCfgVar" | awk -v IntfBaseName="$IntfBaseName" '$1=="set" && $2=="interfaces" && $3==IntfBaseName {$1=""; $2=""; $3=""; print $0; }'`
        IntfConfig=`echo "$NodeCfgVar" | awk -v IntfName="$IntfName" '$1=="set" && $2=="interfaces" && $3==IntfName {$1=""; $2=""; $3=""; print $0; }'`
        VlanOfIntf=`echo "$IntfConfig" | awk '$1=="vlan-id" {print $2}'`
        IntfDescr=`echo "$IntfBaseConfig" | awk '$1=="description" {$1 = ""; print $0; }' | sed 's/\"//g' | awk '{$1=$1};1'`
        DescrOfIntf=`echo "$IntfDescr" | sed 's/|/-/g'`
        PossibleRemoteInfo=`echo "$IntfDescr" | awk -F'|' '{print $2}'`
        if [[ ! -z $PossibleRemoteInfo ]]; then
          NeigDevice=`echo "$PossibleRemoteInfo" | sed 's/::/ /g' | awk '{print $2}'`
          NeigInterface=`echo "$PossibleRemoteInfo" | sed 's/::/ /g' | awk '{print $3}'`
        fi
        PoOfIntf=`echo "$IntfConfig" | awk '($1=="gigether-options" || $1=="ether-options") && $2=="802.3ad" {print $3}'`
        IpOfIntf=`echo "$IntfConfig" | awk '$1=="family" && $2=="inet" && $3=="address" {print $4}' | sort -n | uniq | sed ':a;N;$!ba;s/\n/,/g'`
        LldpNeigDevice=`echo "$LldpOutput" | awk -F'|' -v IntfName="$IntfName" '$2==IntfName {print $4}'`
        LldpNeigInterface=`echo "$LldpOutput" | awk -F'|' -v IntfName="$IntfName" '$2==IntfName {print $3}'`
        echo "$RealHostName|$IntfName|$PoOfIntf|$LogSysOfIntf|$VrfOfIntf|$VlanOfIntf|$IpOfIntf|$DescrOfIntf|$NeigDevice|$NeigInterface|$LldpNeigDevice|$LldpNeigInterface" >> $outfile
      done < <(echo "$NodeCfgVar" | awk '$1=="set" && $2=="interfaces" {print $3}' | sort -n | uniq)
      while read -r IntfName; do
        PoOfIntf=""; LogSysOfIntf=""; VrfOfIntf=""; VlanOfIntf=""; IpOfIntf=""; DescrOfIntf=""; NeigDevice=""; NeigInterface=""; LldpNeigDevice=""; LldpNeigInterface=""
        LogSysOfIntf=`echo "$NodeCfgVar" | awk -v IntfName="$IntfName" '$1=="set" && $2=="logical-systems" && $4=="interfaces" && $5==IntfName {print $3}' | head -1`
        VrfOfIntf=`echo "$NodeCfgVar" | awk -v IntfName="$IntfName" '$1=="set" && $2=="routing-instances" && $4=="interface" && $5==IntfName {print $3}'`
        IntfBaseName=`echo "$IntfName" | sed 's/\..*$//'`
        IntfBaseConfig=`echo "$NodeCfgVar" | awk -v IntfBaseName="$IntfBaseName" '$1=="set" && $2=="interfaces" && $3==IntfBaseName {$1=""; $2=""; $3=""; print $0; }'`
        if [[ -z $LogSysOfIntf ]]; then
          IntfConfig=`echo "$NodeCfgVar" | awk -v IntfName="$IntfName" '$1=="set" && $2=="interfaces" && $3==IntfName {$1=""; $2=""; $3=""; print $0; }'`
        else
          IntfConfig=`echo "$NodeCfgVar" | awk -v LogSysOfIntf="$LogSysOfIntf" -v IntfName="$IntfName" '$1=="set" && $2=="logical-systems" && $3==LogSysOfIntf && $4=="interfaces" && $5==IntfName {$1=""; $2=""; $3=""; $4=""; $5=""; print $0; }'`
        fi
        VlanOfIntf=`echo "$IntfConfig" | awk '$1=="vlan-id" {print $2}'`
        IntfDescr=`echo "$IntfBaseConfig" | awk '$1=="description" {$1 = ""; print $0; }' | sed 's/\"//g' | awk '{$1=$1};1'`
        DescrOfIntf=`echo "$IntfDescr" | sed 's/|/-/g'`
        PossibleRemoteInfo=`echo "$IntfDescr" | awk -F'|' '{print $2}'`
        if [[ ! -z $PossibleRemoteInfo ]]; then
          NeigDevice=`echo "$PossibleRemoteInfo" | sed 's/::/ /g' | awk '{print $2}'`
          NeigInterface=`echo "$PossibleRemoteInfo" | sed 's/::/ /g' | awk '{print $3}'`
        fi
        PoOfIntf=`echo "$IntfConfig" | awk '($1=="gigether-options" || $1=="ether-options") && $2=="802.3ad" {print $3}'`
        IpOfIntf=`echo "$IntfConfig" | awk '$1=="family" && $2=="inet" && $3=="address" {print $4}' | sort -n | uniq | sed ':a;N;$!ba;s/\n/,/g'`
        LldpNeigDevice=`echo "$LldpOutput" | awk -F'|' -v IntfName="$IntfName" '$2==IntfName {print $4}'`
        LldpNeigInterface=`echo "$LldpOutput" | awk -F'|' -v IntfName="$IntfName" '$2==IntfName {print $3}'`
        echo "$RealHostName|$IntfName|$PoOfIntf|$LogSysOfIntf|$VrfOfIntf|$VlanOfIntf|$IpOfIntf|$DescrOfIntf|$NeigDevice|$NeigInterface|$LldpNeigDevice|$LldpNeigInterface" >> $outfile
      done < <(echo "$NodeCfgVar" | awk '$1=="set" && $2=="logical-systems" && $4=="interfaces" {print $5}' | sort -n | uniq)
    fi
  done
}
fBuildNodeDbDb() {
  # fcs.list, bcs.list, noncs.list content formats:
  # <Node>|<Brand>|<Model>|<SW_Version>
  fCreateNonExistentDirs
  if [[ $bBuildNodeTypeDb -eq 1 ]]; then
    for BuildersDataCenter in $TftpDCList; do
    # for BuildersDataCenter in fra01 fra02 fra03 fra04 fra05; do
      BuildersDCdir=$NodeDbDir/$BuildersDataCenter
      [[ -d $TftpConfigsDir/$BuildersDataCenter/fcs ]] && { cat /dev/null > $BuildersDCdir/fcs.list; fCreateNodeTypeList $BuildersDataCenter fcs $BuildersDCdir/fcs.list; }
      [[ -d $TftpConfigsDir/$BuildersDataCenter/bcs ]] && { cat /dev/null > $BuildersDCdir/bcs.list; fCreateNodeTypeList $BuildersDataCenter bcs $BuildersDCdir/bcs.list; }
      cat /dev/null > $BuildersDCdir/noncs.list
      for NonCsNodeType in $NonCsList; do fCreateNodeTypeList $BuildersDataCenter $NonCsNodeType $BuildersDCdir/noncs.list; done
    done
  fi
  # fcs-interface.list, bcs-interface.list, noncs-interface.list content formats:
  #   1   |     2     | 3  |    4    |  5  |  6   |   7   |  8   |  9   |    10    |       11       |        12         "
  # <Node>|<Interface>|<po>|<log_sys>|<vrf>|<vlan>|<IP/nm>|<desc>|<neig>|<neig_int>|<LldpNeigDevice>|<LldpNeigInterface>"
  if [[ $bBuildNodeInterfaceDb -eq 1 ]]; then
    for BuildersDataCenter in $TftpDCList; do
    # for BuildersDataCenter in dal10; do
    # for BuildersDataCenter in dal10 dal11 dal12 dal13 den01 fra01 fra02 fra03 fra04 fra05 hkg01 hkg02 hkg03 hou00 hou02 lax01 lon01 lon02 lon03 lon04 lon05 lon06 mel01 mel02 mel03 mex01 mia01 mil01 mil02 mon01 mon02 nyc01 osa01 osk01 osl01 osl02 pal01 par01 par02 per01 sao01 sao02 sea01 sea02 seo01 seo02 sjc01 sjc02 sjc03 sjc04 sng01 sng02 sto01 syd01 syd02 syd03 syd04 syd05 tok01 tok02 tok03 tok04 tok05 tor01 tor02 wdc01 wdc02 wdc03 wdc04 wdc05 wdc06 wdc07; do
      BuildersDCdir=$NodeDbDir/$BuildersDataCenter
      [[ -d $TftpConfigsDir/$BuildersDataCenter/fcs ]] && { cat /dev/null > $BuildersDCdir/fcs-interface.list; fCreateNodeInterfaceList $BuildersDataCenter fcs $BuildersDCdir/fcs-interface.list; }
      [[ -d $TftpConfigsDir/$BuildersDataCenter/bcs ]] && { cat /dev/null > $BuildersDCdir/bcs-interface.list; fCreateNodeInterfaceList $BuildersDataCenter bcs $BuildersDCdir/bcs-interface.list; }
      cat /dev/null > $BuildersDCdir/noncs-interface.list
      for NonCsNodeType in $NonCsList; do fCreateNodeInterfaceList $BuildersDataCenter $NonCsNodeType $BuildersDCdir/noncs-interface.list; done
    done
  fi
}

fInitParams

InputParams=""
# [[ $# -lt 1 ]] && { fPrintHelp; exit 1; }
while [ $# -gt 0 ]; do
  case "$1" in
    --build-db-nodetype) shift;bBuildNodeTypeDb=1;;
    --build-db-nodeintf) shift;bBuildNodeInterfaceDb=1;;
    --populate-confs)    shift;bPopulateBackupsMine=1;;
    -i)                  shift;bListNodesInterfaces=1;[[ ! -z $1 ]] && { bInputIntf=$1; shift; };;
    --help)              fPrintHelp;exit 1;;
    -h)                  fPrintHelp;exit 1;;
    *)                   InputParams+=" $1";shift;;
  esac
done

[[ ! -z $bPopulateBackupsMine ]] && { fPopulateBackupsMine; exit 0; }
[[ ! -z $bBuildNodeTypeDb || ! -z $bBuildNodeInterfaceDb ]] && { fBuildNodeDbDb; exit 0; }

# Print set of DCs, then exit successfully
[[ -z $InputParams ]] && { ls $NodeDbDir; exit 0; }

[[ `echo "$InputParams" | wc -w` -gt 2 ]] && { fPrintHelp; exit 1; }

for param in $InputParams; do
  [[ `echo "$DCList" | awk -v param="$param" '$1==param' | wc -l` -eq 1 || $param == "all" ]] && { DcInQuery=$param; continue; }
  PatternInQuery=$param
done

ipcalc -sc $PatternInQuery
if [[ $? -eq 0 ]]; then
  ThePrefix=`ipcalc -sp $PatternInQuery | awk -F'=' '{print $2}'`
  if [[ -z $ThePrefix ]]; then
    cat $NodeDbDir/*/*-interface.list | grep "|$PatternInQuery/\|,$PatternInQuery/"
  else
    cat $NodeDbDir/*/*-interface.list | grep "|$PatternInQuery|\|,$PatternInQuery|\||$PatternInQuery,\|,$PatternInQuery,"
  fi
  exit 0
fi

# Print set of Node Roles in given DC, then exit successfully
[[ ! -z $DcInQuery && -z $PatternInQuery ]] && { cat $NodeDbDir/$DcInQuery/*s.list | awk -F'|' '{print $1}' | awk -F'.' '{print $1}' | sed 's/[^a-zA-Z].*$//' | sort | uniq; exit 0; }

# Print set of Nodes matching given DC and name pattern, then exit successfully
PossDCPortion=`echo "$PatternInQuery" | awk -F'.' '{print $NF}'`
if [[ `echo "$DCList" | awk -v PossDCPortion="$PossDCPortion" '$1==PossDCPortion' | wc -l` -ne 1 ]]; then
  [[ $DcInQuery == "all" ]] && { cat $NodeDbDir/*/*s.list | grep "^$PatternInQuery"; exit 0; }
  [[ ! -z $DcInQuery ]] && { cat $NodeDbDir/$DcInQuery/*s.list | grep "^$PatternInQuery"; exit 0; }
  cat $NodeDbDir/*/*s.list | grep "^$PatternInQuery"
  exit 0
fi

NodeHostName=$PatternInQuery
NodesDCPortion=`echo "$NodeHostName" | awk -F'.' '{print $NF}'`
[[ `echo "$DCList" | awk -v NodesDCPortion="$NodesDCPortion" '$1==NodesDCPortion' | wc -l` -ne 1 ]] && exit 1

NodesTypePortion=`echo "$NodeHostName" | cut -c 1-3`
if [[ $bListNodesInterfaces -ne 1 ]]; then
  case "$NodesTypePortion" in
    fcs)      cat "$NodeDbDir/$NodesDCPortion/fcs.list" | awk -F'|' -v NodeHostName="$NodeHostName" '$1==NodeHostName';;
    bcs)      cat "$NodeDbDir/$NodesDCPortion/bcs.list" | awk -F'|' -v NodeHostName="$NodeHostName" '$1==NodeHostName';;
    *)        cat "$NodeDbDir/$NodesDCPortion/noncs.list" | awk -F'|' -v NodeHostName="$NodeHostName" '$1==NodeHostName';;
  esac
else
  if [[ ! -z $bInputIntf ]]; then
    case "$NodesTypePortion" in
      fcs)      cat "$NodeDbDir/$NodesDCPortion/fcs-interface.list" | awk -F'|' -v NodeHostName="$NodeHostName" -v bInputIntf="$bInputIntf" '$1==NodeHostName && $2==bInputIntf' | sed 's/.ort-.hannel/po/' | sed 's/Po/po/' | sed 's/Vlan/vlan/';;
      bcs)      cat "$NodeDbDir/$NodesDCPortion/bcs-interface.list" | awk -F'|' -v NodeHostName="$NodeHostName" -v bInputIntf="$bInputIntf" '$1==NodeHostName && $2==bInputIntf' | sed 's/.ort-.hannel/po/' | sed 's/Po/po/' | sed 's/Vlan/vlan/';;
      *)        cat "$NodeDbDir/$NodesDCPortion/noncs-interface.list" | awk -F'|' -v NodeHostName="$NodeHostName" -v bInputIntf="$bInputIntf" '$1==NodeHostName && $2==bInputIntf' | sed 's/.ort-.hannel/po/' | sed 's/Po/po/' | sed 's/Vlan/vlan/';;
    esac
  else
    case "$NodesTypePortion" in
      fcs)      cat "$NodeDbDir/$NodesDCPortion/fcs-interface.list" | awk -F'|' -v NodeHostName="$NodeHostName" '$1==NodeHostName' | sed 's/.ort-.hannel/po/' | sed 's/Po/po/' | sed 's/Vlan/vlan/';;
      bcs)      cat "$NodeDbDir/$NodesDCPortion/bcs-interface.list" | awk -F'|' -v NodeHostName="$NodeHostName" '$1==NodeHostName' | sed 's/.ort-.hannel/po/' | sed 's/Po/po/' | sed 's/Vlan/vlan/';;
      *)        cat "$NodeDbDir/$NodesDCPortion/noncs-interface.list" | awk -F'|' -v NodeHostName="$NodeHostName" '$1==NodeHostName' | sed 's/.ort-.hannel/po/' | sed 's/Po/po/' | sed 's/Vlan/vlan/';;
    esac
  fi
fi

exit 0