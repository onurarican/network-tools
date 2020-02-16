#!/bin/bash
# Onur

fInitParams() {
ToolDir=/home/oarican/tools/countergraph
PagesDir=$ToolDir/pages
TemplatesDir=$ToolDir/templates

ConfFile=$ToolDir/countergraph.conf
}

fInitParams
CurrentMin=`date +'%M'`
CurrentHr=`date +'%H'`

PageList=`awk -F':' '$1=="page"' $ToolDir/countergraph.conf`

while read pageline; do
  ThisPage=`echo "$pageline" | awk '{print $1}' | awk -F':' '{print $2}'`
  ThisDayLeft=`echo "$pageline" | awk '{print $2}' | awk -F':' '{print $2}' | awk -F'-' '{print $1}' | sed 's/d$//1'`
  ThisHrLeft=`echo "$pageline" | awk '{print $2}' | awk -F':' '{print $2}' | awk -F'-' '{print $2}' | sed 's/h$//1'`
  ThisGranularity=`echo "$pageline" | awk '{print $3}' | awk -F':' '{print $2}' | sed 's/m$//1'`

  [[ $(($CurrentMin %$ThisGranularity)) -ne 0 ]] && continue
  [[ $(($ThisDayLeft + $ThisHrLeft)) -eq 0 ]] && continue

  DeviceList=`sed -e '1,/page:'"${ThisPage}"'/d' -e '/endofpage:'"${ThisPage}"'/,$d' $ConfFile | sed 's/\t/ /g' | sed '/^[[:space:]]*$/d' | awk '{$1=$1};1' | sed 's/\ \ */ /g' | sed '/^#/d'`
  [[ -z $DeviceList ]] && continue

  [[ ! -d $PagesDir/$ThisPage ]] && mkdir -p $PagesDir/$ThisPage/data

  while read deviceline; do
    node=`echo $deviceline | awk '{print $1}'`
    deviceflag=`echo $deviceline | awk '{print $2}'`
    inputarguments=`echo $deviceline | awk '{ t = $1; $1 = $2; $2 = t; print; }'`
    [[ $deviceflag == "-c" ]] && devicecounters=`interfacecounters $inputarguments | grep -v t_packets | grep -v o_packet | sed -e 's/ /_/1' | sed '1 i\Date Date'`
    [[ $deviceflag == "-a" ]] && devicecounters=`interfacecounters $inputarguments | grep -v packets | grep -v cast | sed -e 's/ /_/1' | sed '1 i\Date Date'`
    [[ $deviceflag == "-j" ]] && devicecounters=`interfacecounters $inputarguments | sed -e 's/ /_/1' | sed '1 i\Date Date'`
    [[ ! -f $PagesDir/$ThisPage/data/$node.txt ]] && echo "$devicecounters" | awk '{print $1}' | awk 'BEGIN {ORS=" "} {print} END {print "\n"}' > $PagesDir/$ThisPage/data/$node.txt
    echo "$devicecounters" | awk '{print $2}' | awk 'BEGIN {ORS=" "} {print} END {print "\n"}' >> $PagesDir/$ThisPage/data/$node.txt
  done < <(echo "$DeviceList")

  NewHrLeft=$ThisHrLeft;NewDayLeft=$ThisDayLeft
  [[ $(($CurrentMin + $ThisHrLeft)) -eq 0 ]] && { NewHrLeft=23; let "NewDayLeft--"; } || let "NewHrLeft--"
  [[ $CurrentMin -eq 0 ]] && sed -i -- 's/page:'"${ThisPage}"'\ .*timeleft:'"${ThisDayLeft}"'d-'"${ThisHrLeft}"'h/page:'"${ThisPage}"'     timeleft:'"${NewDayLeft}"'d-'"${NewHrLeft}"'h/1' $ToolDir/countergraph.conf
done < <(echo "$PageList")

exit 0
