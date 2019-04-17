#!/bin/bash

# Usage:
# ./zPrintPath.sh <count> <timeout> <IP> <tcp_port>

MaxHopsWithinAllPaths=0

for pathindex in $(eval echo "{1..$1}"); do
  echo -en "\rPath $pathindex / $1"
  array[$pathindex]=`sudo traceroute -Tq 1 $3 -p $4 -w $2`
  MaxHopsThisPath=`echo "${array[$pathindex]}" | awk '{print $1}' | tail -1`
  [[ $MaxHopsThisPath -gt $MaxHopsWithinAllPaths ]] && MaxHopsWithinAllPaths=$MaxHopsThisPath
done

for hopindex in $(eval echo "{1..$MaxHopsWithinAllPaths}"); do
  for pathindex in $(eval echo "{1..$1}"); do
    This_Hops_IP=`echo "${array[$pathindex]}" | awk -v hopindex="$hopindex" '$1==hopindex { print $0 }' | awk -F  "[()]" '{print $2}'`
    [[ -z "$This_Hops_IP" ]] && continue
    This_Hops_Name=`echo "${array[$pathindex]}" | awk -v hopindex="$hopindex" '$1==hopindex { print $0 }' | sed 's/(.*$//' | awk '{print $2}'`
    This_Hops_Latency=`echo "${array[$pathindex]}" | awk -v hopindex="$hopindex" '$1==hopindex { print $0 }' | sed 's/^.*)//' | awk '{print $1 " " $2}'`
    RawOutput=`echo "$RawOutput";echo $hopindex $This_Hops_IP $This_Hops_Name $This_Hops_Latency`
  done
done

echo "$RawOutput"

exit 0
