#!/bin/bash
# Onur

# Pre-requisites:
# sshpass

fInitParams() {
ListOfOld=`echo -e "\
CISCO7609-S\n\
WS-C2960+48TC-L\n\
WS-C3560E-48TD\n\
WS-C3750X-48\n\
WS-C6509\n\
WS-C6509-E\n\
WS-C6509-V-E"`
}
fPrintHelp() {
echo Usage:
echo "zsshpass [-u <user> -p <pass>] [-d <Delay_for_long_in_seconds>] [-t <ConnTimeout_in_seconds>] [-l] <hostname> \"<command_1>\" [ \"<command_2>\" ... \"<command_n>\" ]"
echo ""
echo "Input arguments: $@"
}

[[ $# -lt 2 ]] && { fPrintHelp; exit 1; }

fInitParams

usernm=`whoami`
cmdparameter="-f"
passwd=~/.data/input

while [ $# -gt 2 ]; do
  case "$1" in
    -t)   shift; ConnTimeout=$1; shift;;
    -d)   shift; DelayOfLong=$1; shift;;
    # -u)   shift; usernm=`echo $1 | awk -F'/' '{print $1}'`; passwd=`echo $1 | awk -F'/' '{print $2}'`; cmdparameter="-p"; shift;;
    -u)   shift; usernm=$1; shift;;
    -p)   shift; passwd=$1;cmdparameter="-p"; shift;;
    -l)   shift; bLongMode=1;;
    *)    break;;
  esac
done

[[ $cmdparameter == "-f" && ! -f ~/.data/input ]] && { read -s -p "Softlayer Password: " passwd; echo ""; cmdparameter="-p"; }

TheHost=$1; shift
[[ ! -z "$ConnTimeout" ]] && SSHCOMMAND="ssh $usernm@$TheHost -o StrictHostKeyChecking=no -o ConnectTimeout=$ConnTimeout" || SSHCOMMAND="ssh $usernm@$TheHost -o StrictHostKeyChecking=no"

HostInfo=`nodedb $TheHost`
if [[ -z $HostInfo ]]; then
  FirstWordOfHost=`echo "$TheHost" | awk -F'.' '{print $1}'`
  [[ ${FirstWordOfHost: -1} =~ ^[0-9]+$ ]] && FirstWordWithA=`echo "$FirstWordOfHost"a`
  NodeDbHost=`echo "$TheHost" | sed "s/$FirstWordOfHost/$FirstWordWithA/"`
  HostInfo=`nodedb $NodeDbHost`
fi
HostModel=`echo "$HostInfo" | awk -F'|' '{print $3}'`
echo hop 1
CmdIndex=0
if [[ $bLongMode -ne 1 && ! -z $HostModel && `echo "$ListOfOld" | awk -v HostModel="$HostModel" '$1==HostModel' | wc -l` -eq 0 ]]; then
  sshpass $cmdparameter $passwd $SSHCOMMAND << EOF_run_commands
  `while [[ $# -ge 1 ]]; do let "CmdIndex=$CmdIndex+1"; echo "echo \"## command $CmdIndex start ##\""; echo "$1"; shift; echo "echo \"## command $CmdIndex finish ##\"";  done`
EOF_run_commands
else
  while [[ $# -ge 1 ]]; do
    let "CmdIndex=$CmdIndex+1"
    echo "## command $CmdIndex start ##"
    sshpass $cmdparameter $passwd $SSHCOMMAND "$1"
    [[ ! -z $DelayOfLong ]] && sleep $DelayOfLong
    shift
    echo -e "\n## command $CmdIndex finish ##"
  done
fi

exit 0