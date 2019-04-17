#!/bin/bash

# Usage:
# ./zPrintPath.sh <count> <timeout> <IP> <tcp_port>

MaxHopsWithinAllPaths=0

for pathindex in $(eval echo "{1..$1}"); do
  echo "Path $pathindex / $1"
  array[$pathindex]=`sudo traceroute -Tq 1 $3 -p $4 -w $2`
  MaxHopsThisPath=`echo "${array[$pathindex]}" | awk '{print $1}' | tail -1`
  [[ $MaxHopsThisPath -gt $MaxHopsWithinAllPaths ]] && MaxHopsWithinAllPaths=$MaxHopsThisPath
done

for hopindex in $(eval echo "{1..$MaxHopsWithinAllPaths}"); do
  for pathindex in $(eval echo "{1..$1}"); do
    This_Hops_IP=`echo "${array[$pathindex]}" | awk -v hopindex="$hopindex" '$1==hopindex { print $0 }' | awk -F  "[()]" '{print $2}'`
    echo $hopindex - $This_Hops_IP
  done
done

exit 0
