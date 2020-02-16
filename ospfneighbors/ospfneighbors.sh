#!/bin/bash
# Onur

fPrintHelp() {
  echo Usage:
  echo "ospfneighbors <Device>"
}
fInitParams() {
  MyHome=/home/oarican
  ToolDir=$MyHome/tools/neighbors
  # Colour Codes
  ClBold="\e[1m"
  ClDim="\e[2m"
  # ClNormal="\e[39m"
  # ClNormal="\e[21m"
  ClNormal="\e[0m"
  ClWhite="\e[29m"
  ClGreen="\e[32m"
  ClTurquoise="\e[36m"
  ClOrange="\e[33m"
  ClRed="\e[31m"
  ClBlue="\e[34m"
  ClGray="\e[90m"  # 37 Light gray, 90 Dark gray
  ClLGray="\e[37m"
  ClTest="\e[136m"
}
fListCiscoArista() {
  OspfNeiCmdOut=`zsshpass $NodeName "show ip ospf neighbor" 2> /dev/null | sed $'s/[^[:print:]\t]//g' | egrep -A 100000 -m 1 "command 1 start" | egrep -B 100000 -m 1 "command 1 finish" | grep -v "command 1 " | egrep -A 100000 -m 1 "Neighbor ID" | grep -v "Neighbor ID\|^$"`
  OspfIntfs=`echo "$OspfNeiCmdOut" | awk '{print $7}' | sed 's/.ort-.hannel/po/' | sed 's/Po/po/' | sed 's/Vlan/vlan/'`
  NeighCount=`echo "$OspfIntfs" | wc -l`
  commands=`echo "$OspfIntfs" | sed 's/^/\"show ip ospf interface /g' | sed 's/$/" /g' | awk '{ printf "%s", $0 }'`
  CommandsOutput=`sh -c "zsshpass $NodeName $commands 2> /dev/null" | sed $'s/[^[:print:]\t]//g' | sed 's/\r//g'| sed 's/\t/ /g'`
  for cmdindex in $(eval echo {1..$NeighCount}); do
    ThisIntf=`echo "$OspfIntfs" | sed "${cmdindex}q;d"`
    ThisCmdOutput=`echo "$CommandsOutput" | egrep -A 100000 "command $cmdindex start" | egrep -B 100000 "command $cmdindex finish" | grep -v "command $cmdindex"`
    ThisAreaLong=`echo "$ThisCmdOutput" | grep "area\|Area" | sed 's/,/\n/g' | grep "area\|Area" | awk '{print $NF}'`
    [[ $ThisAreaLong == "0.0.0.0" || $ThisAreaLong == "0" ]] && ThisAreaShort=0 || ThisAreaShort=`echo "$ThisAreaLong" | sed 's/^[0\.]*//g'`
    ThisCost=`echo "$ThisCmdOutput" | grep "cost\|Cost:" | sed 's/,/\n/g' | grep "cost\|Cost:" | awk '{print $NF}'`
    ThisType=`echo "$ThisCmdOutput" | grep "type\|Type" | sed 's/,/\n/g' | grep "type\|Type" | awk '{print $NF}' | sed 's/POINT_TO_POINT/P2P/' | sed 's/Point-To-Point/P2P/' | sed 's/Broadcast/Bcst/'`
    OspfProperties=`echo "$OspfProperties";echo $ThisIntf $ThisAreaShort $ThisCost $ThisType`
  done
  OspfProperties=`echo "$OspfProperties" | grep -v "^$"`
  counter=0
  while read -r line; do
    LocalInterfaceName=""; LinkArea=""; LinkCost=""; LinkType=""; NeighInterfaceName=""; PossNeighVRF=""; PossNeighLS=""; NeighName=""
    let "counter++"
    NeighNodeIP=`echo "$line" | awk '{print $6}'`
    NeighNodeRtrID=`echo "$line" | awk '{print $1}'`
    LocalInterfaceName=`echo "$line" | awk '{print $7}' | sed 's/.ort-.hannel/po/' | sed 's/Po/po/' | sed 's/Vlan/vlan/'`
    NeighIdMatchedLines=`nodedb $NeighNodeRtrID`
    # If NeighId matches one type of node, we found the NeighName
    TempVar=`echo "$NeighIdMatchedLines" | awk -F'|' '{print $1}' | sort -n | uniq -c`
    [[ `echo "$TempVar" | wc -l` -eq 1 ]] && NeighName=`echo "$TempVar" | awk '{print $2}'`
    NeighIpMatchedLines=`nodedb $NeighNodeIP`
    if [[ -z $NeighName ]]; then
      # If NeighIp matches one type of node, we found the NeighName
      TempVar=`echo "$NeighIpMatchedLines" | awk -F'|' '{print $1}' | sort -n | uniq -c`
      [[ `echo "$TempVar" | wc -l` -eq 1 ]] && NeighName=`echo "$TempVar" | awk '{print $2}'`
      if [[ -z $NeighName ]]; then
        TempVar=`echo "$NeighIdMatchedLines" | awk -F'|' '{print $1}' | sort -n | uniq; echo "$NeighIpMatchedLines" | awk -F'|' '{print $1}' | sort -n | uniq`
        [[ `echo "$TempVar" | sort -n | uniq -c | awk '$1!="1"' | wc -l` -eq 1 ]] && NeighName=`echo "$TempVar" | sort -n | uniq -c | awk '$1!="1" {print $2}'`
      fi
    fi
    [[ -z $NeighName ]] && continue
    NeighInterfaceInfo=`echo "$NeighIpMatchedLines" | awk -F'|' -v NeighName="$NeighName" '$1==NeighName'`
    [[ `echo "$NeighInterfaceInfo" | wc -l` -ne 1 ]] && NeighInterfaceInfo=`echo "$NeighInterfaceInfo" | awk -F'|' '$5!="GUARD" && $5!="SERVICES"'`
    [[ `echo "$NeighInterfaceInfo" | wc -l` -ne 1 ]] && continue
    NeighInterfaceName=`echo "$NeighInterfaceInfo" | awk -F'|' '{print $2}' | sed 's/.ort-.hannel/po/' | sed 's/Po/po/' | sed 's/Vlan/vlan/'`
    PossNeighLS=`echo "$NeighInterfaceInfo" | awk -F'|' '{print $4}'`
    PossNeighVRF=`echo "$NeighInterfaceInfo" | awk -F'|' '{print $5}'`
    LinkArea=`echo "$OspfProperties" | awk -v LocalInterfaceName="$LocalInterfaceName" '$1==LocalInterfaceName {print $2}'`
    LinkCost=`echo "$OspfProperties" | awk -v LocalInterfaceName="$LocalInterfaceName" '$1==LocalInterfaceName {print $3}'`
    LinkType=`echo "$OspfProperties" | awk -v LocalInterfaceName="$LocalInterfaceName" '$1==LocalInterfaceName {print $4}'`
    printf "%-16s" "$NodeName"
    printf ""$ClGray"%-10s "$ClNormal"" "$LocalVrf"
    printf "%10s     -------- area:%2s -- cost:%3s -- type:%s --------     " "$LocalInterfaceName" "$LinkArea" "$LinkCost" "$LinkType"
    printf "%-10s" "$NeighInterfaceName"
    printf ""$ClGray"%-10s "$ClNormal"" "$PossNeighVRF"
    [[ ! -z $PossNeighLS ]] && printf ""$ClGreen"%10s"$ClNormal"" "$PossNeighLS"
    printf "%17s\n" "$NeighName"
  done < <(echo "$OspfNeiCmdOut")
}
fListJuniper() {
  OspfNeiCmdOut=`zsshpass $NodeName "show ospf neighbor instance all" 2> /dev/null | sed $'s/[^[:print:]\t]//g' | egrep -A 100000 -m 1 "command 1 start" | egrep -B 100000 -m 1 "command 1 finish" | grep -v "command 1 " | egrep -A 100000 -m 1 "^Instance: master" | tac | egrep -A 100000 "^$" | tac | grep -v "^Address\|^{master\|^$"`
  while read -r line; do
    [[ $line == "" ]] && continue
    echo "$line" | grep "^Instance:" > /dev/null
    [[ $? -eq 0 ]] && { ThisVrf=`echo "$line" | awk '{print $2}'`; continue; }
    echo "$line" | grep "Interface" > /dev/null
    [[ $? -eq 0 ]] && continue
    ThisIntf=`echo "$line" | awk '{print $2}'`
    [[ $ThisVrf == "master" ]] && OspfIntfs=`echo "$OspfIntfs";echo $ThisIntf` || OspfIntfs=`echo "$OspfIntfs";echo $ThisIntf instance $ThisVrf`
  done < <(echo "$OspfNeiCmdOut")
  OspfIntfs=`echo "$OspfIntfs" | grep -v "^$"`
  NeighCount=`echo "$OspfIntfs" | wc -l`
  commands=`echo "$OspfIntfs" | sed 's/^/\"show ospf interface /g' | sed 's/$/ extensive" /g' | awk '{ printf "%s", $0 }'`
  CommandsOutput=`sh -c "zsshpass $NodeName $commands 2> /dev/null" | sed $'s/[^[:print:]\t]//g' | sed 's/\r//g'| sed 's/\t/ /g'`
  for cmdindex in $(eval echo {1..$NeighCount}); do
    ThisIntf=`echo "$OspfIntfs" | sed "${cmdindex}q;d" | awk '{print $1}'`
    ThisCmdOutput=`echo "$CommandsOutput" | egrep -A 100000 "command $cmdindex start" | egrep -B 100000 "command $cmdindex finish" | grep -v "command $cmdindex"`
    ThisAreaLong=`echo "$ThisCmdOutput" | egrep -A 1 "^Interface" | sed "2q;d" | awk '{print $3}'`
    [[ $ThisAreaLong == "0.0.0.0" ]] && ThisAreaShort=0 || ThisAreaShort=`echo "$ThisAreaLong" | sed 's/^[0\.]*//g'`
    ThisCost=`echo "$ThisCmdOutput" | grep Address | sed 's/,/\n/g' | grep Cost | awk '{print $NF}'`
    ThisType=`echo "$ThisCmdOutput" | grep Address | sed 's/,/\n/g' | grep Type | awk '{print $NF}'`
    OspfProperties=`echo "$OspfProperties";echo $ThisIntf $ThisAreaShort $ThisCost $ThisType`
  done
  OspfProperties=`echo "$OspfProperties" | grep -v "^$"`
  counter=0
  while read -r line; do
    LocalInterfaceName=""; LinkArea=""; LinkCost=""; LinkType=""; NeighInterfaceName=""; PossNeighVRF=""; PossNeighLS=""; NeighName=""
    PossLocalVrf=`echo "$line" | awk '$1=="Instance:" {print $2}'`
    [[ ! -z $PossLocalVrf ]] && { [[ $PossLocalVrf != "master" ]] && { LocalVrf=$PossLocalVrf; echo ""; } || LocalVrf=""; continue; }
    let "counter++"
    NeighNodeIP=`echo "$line" | awk '{print $1}'`
    NeighNodeRtrID=`echo "$line" | awk '{print $4}'`
    LocalInterfaceName=`echo "$line" | awk '{print $2}' | sed 's/.ort-.hannel/po/'`
    NeighIdMatchedLines=`nodedb $NeighNodeRtrID`
    # If NeighId matches one type of node, we found the NeighName
    TempVar=`echo "$NeighIdMatchedLines" | awk -F'|' '{print $1}' | sort -n | uniq -c`
    [[ `echo "$TempVar" | wc -l` -eq 1 ]] && NeighName=`echo "$TempVar" | awk '{print $2}'`
    NeighIpMatchedLines=`nodedb $NeighNodeIP`
    if [[ -z $NeighName ]]; then
      # If NeighIp matches one type of node, we found the NeighName
      TempVar=`echo "$NeighIpMatchedLines" | awk -F'|' '{print $1}' | sort -n | uniq -c`
      [[ `echo "$TempVar" | wc -l` -eq 1 ]] && NeighName=`echo "$TempVar" | awk '{print $2}'`
      if [[ -z $NeighName ]]; then
        TempVar=`echo "$NeighIdMatchedLines" | awk -F'|' '{print $1}' | sort -n | uniq; echo "$NeighIpMatchedLines" | awk -F'|' '{print $1}' | sort -n | uniq`
        [[ `echo "$TempVar" | sort -n | uniq -c | awk '$1!="1"' | wc -l` -eq 1 ]] && NeighName=`echo "$TempVar" | sort -n | uniq -c | awk '$1!="1" {print $2}'`
      fi
    fi
    [[ -z $NeighName ]] && continue
    NeighInterfaceInfo=`echo "$NeighIpMatchedLines" | awk -F'|' -v NeighName="$NeighName" '$1==NeighName'`
    [[ `echo "$NeighInterfaceInfo" | wc -l` -ne 1 ]] && NeighInterfaceInfo=`echo "$NeighInterfaceInfo" | awk -F'|' '$5!="GUARD" && $5!="SERVICES"'`
    [[ `echo "$NeighInterfaceInfo" | wc -l` -ne 1 ]] && continue
    NeighInterfaceName=`echo "$NeighInterfaceInfo" | awk -F'|' '{print $2}' | sed 's/.ort-.hannel/po/' | sed 's/Po/po/' | sed 's/Vlan/vlan/'`
    PossNeighLS=`echo "$NeighInterfaceInfo" | awk -F'|' '{print $4}'`
    PossNeighVRF=`echo "$NeighInterfaceInfo" | awk -F'|' '{print $5}'`
    [[ `echo "$OspfProperties" | sed "${counter}q;d" | awk '{print $1}'` != "$LocalInterfaceName" ]] && continue
    LinkArea=`echo "$OspfProperties" | sed "${counter}q;d" | awk '{print $2}'`
    LinkCost=`echo "$OspfProperties" | sed "${counter}q;d" | awk '{print $3}'`
    LinkType=`echo "$OspfProperties" | sed "${counter}q;d" | awk '{print $4}'`
    # LinkCost=`echo "$OspfProperties" | awk -v LocalInterfaceName="$LocalInterfaceName" '$1==LocalInterfaceName {print $3}'`
    # LinkType=`echo "$OspfProperties" | awk -v LocalInterfaceName="$LocalInterfaceName" '$1==LocalInterfaceName {print $4}'`
    printf "%-16s" "$NodeName"
    printf ""$ClGray"%-10s "$ClNormal"" "$LocalVrf"
    printf "%10s     -------- area:%2s -- cost:%3s -- type:%s --------     " "$LocalInterfaceName" "$LinkArea" "$LinkCost" "$LinkType"
    printf "%-10s" "$NeighInterfaceName"
    printf ""$ClGray"%-10s "$ClNormal"" "$PossNeighVRF"
    [[ ! -z $PossNeighLS ]] && printf ""$ClGreen"%10s"$ClNormal"" "$PossNeighLS"
    printf "%17s\n" "$NeighName"
  done < <(echo "$OspfNeiCmdOut")
}

fInitParams

NodeName=$1
NodeInfo=`nodedb $NodeName`
NodeBrand=`echo "$NodeInfo" | awk -F'|' '{print $2}'`
NodeModel=`echo "$NodeInfo" | awk -F'|' '{print $3}'`

case "$NodeBrand" in
  cisco)   fListCiscoArista;;
  arista)  fListCiscoArista;;
  juniper) fListJuniper;;
  *)       exit 1;;
esac

exit 0