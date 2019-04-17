#!/bin/bash

# Usage:
# ./zPrintPath.sh <count> <timeout> <IP> <tcp_port>

for probeindex in $(eval echo "{1..$1}"); do array[$probeindex]=`sudo traceroute -Tq 1 $3 -p $4 -w $2`; done

exit 0
