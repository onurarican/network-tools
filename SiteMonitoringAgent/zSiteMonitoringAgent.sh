#!/bin/bash
# Onur

fInitParams() {
  ToolDir=/home/oarican/tools/SiteMonitoringAgent
  UsersName=`whoami`
  SiteConfigFile=$ToolDir/SiteMonitoringAgent.conf
  ThreadFeederFile=$ToolDir/ThreadFeeder.list
  [[ -f $ThreadFeederFile ]] && cat /dev/null > $ThreadFeederFile || touch $ThreadFeederFile
  MasterUtilityServer=utilitymasterdal1001
  MultiThreading=20
  ThreadMaxProcessingTime=180
}
fPrintHelp() {
echo Usage:
echo "zSiteMonitoringAgent"
# dat file format
#          Device            |                  Last Sample                |                 Z-1 Sample                  |                  Z-2 Sample                
#     |         |            |Epoch in UTC|  hours  |     |          | /hr |Epoch in UTC|  hours  |     |          | /hr |Epoch in UTC|  hours  |     |          | /hr
#  1  |    2    |      3     |     4      |    5    |  6  |     7    |  8  |     9      |    10   | 11  |    12    | 13  |     14     |   15    | 16  |    17    | 18  
# name|interface|counter_name|   time     |time_diff|value|value_diff|rate |   time     |time_diff|value|value_diff|rate |   time     |time_diff|value|value_diff|rate
}
fCleaning() {
  DCList=`fGetConfParam DCs`
  cd $ToolDir
  for ThisDC in $DCList; do
    find $ThisDC | grep "\-1\.dat$" | xargs rm -f
    find $ThisDC -type f -empty | xargs rm -f
  done
}
fSendReport() {
  DCList=`fGetConfParam DCs`
  cd $ToolDir
  zsshpass $MasterUtilityServer "hostname" > /dev/null 2>&1
  for ThisDC in $DCList; do
    sshpass -f ~/.data/input rsync -av $ThisDC $MasterUtilityServer:$ToolDir/reports/
  done
}
fGetConfParam() {
  # Usage : fGetConfParam <param>
  grep "^$1" $SiteConfigFile | awk -F'=' '{print $2}' | awk '{$1=$1};1' | sed 's/ /\n/g'
}
fSetConfParam() {
  # Usage : fSetConfParam <param> "val1 val2 ... valN"
  var1=$1
  var2=$2
  TempVar=`awk -F'=' -v OFS="=" -v var2="$var2" '{if ($1 ~ /^'"$var1"' *$/) {$2=" " var2; print} else {print}}' $SiteConfigFile`
  echo "$TempVar" > $SiteConfigFile
}
fGetLineFromData() {
  # Usage : fGetLineFromData <file> <name>
  # Usage : fGetLineFromData <file> <name> <int>
  # Usage : fGetLineFromData <file> <name> <int> <counter>
  case "$#" in
    2)   grep "^$2" $1;rc=$?;;
    3)   grep "^$2|$3" $1;rc=$?;;
    4)   grep "^$2|$3|$4" $1;rc=$?;;
  esac
  return $rc
}
fInsertSampleToDataFile() {
  # Usage : fInsertSampleToDataFile <file> <name> <int> <counter> <time> <t_diff> <value> <v_diff> <rate>
  FileNodeType=$1
  FileMin1NodeType=`echo "$1" | sed 's/\.dat$/-1.dat/'`
  ExistingNodeIntCntLine=`grep "^$2|$3|$4|" $FileMin1NodeType`
  rc=$?
  [[ $rc -eq 1 ]] && { echo "$2|$3|$4|$5|$6|$7|$8|$9|||||||||||" >> $1; return 1; }
  NewNodeIntCntLine=`echo -n "$2|$3|$4|$5|$6|$7|$8|$9|"; echo "$ExistingNodeIntCntLine" | awk -F'|' '{print $4 "|" $5 "|" $6 "|" $7 "|" $8 "|" $9 "|" $10 "|" $11 "|" $12 "|" $13}'`
  echo "$NewNodeIntCntLine" >> $1
  return 0
}
fProcessTheNode() {
  NodeName=$1
  NodeType=$2
  DCName=$3
  FileNodeType=$ToolDir/$DCName/$NodeType.dat
  FilePrevNodeType=$ToolDir/$DCName/$NodeType-1.dat
  ConfTimeMinusUTC=`fGetConfParam ConfTimeMinusUTC`
  AbsConfTimeMinusUTC=`echo "$ConfTimeMinusUTC" | sed 's/-//'`
  [[ `echo "$ConfTimeMinusUTC" | cut -c-1` == "-" ]] && TimeInEpochUtc=`date -d "now + $AbsConfTimeMinusUTC hours" +%s` || TimeInEpochUtc=`date -d "now - $AbsConfTimeMinusUTC hours" +%s`
  LastTime=""
  T_Diff=""
  while read -r line; do
    ThisInterface=`echo "$line" | awk '{print $2}'`
    ThisCounter=`echo "$line" | awk '{print $3}'`
    ThisValue=`echo "$line" | awk '{print $4}'`
    ExistingLine=`fGetLineFromData $FilePrevNodeType $NodeName $ThisInterface $ThisCounter`
    rc=$?
    if [[ $rc -eq 0 ]]; then
      [[ -z $LastTime ]] && LastTime=`echo "$ExistingLine" | awk -F'|' '{print $4}'`
      LastValue=`echo "$ExistingLine" | awk -F'|' '{print $6}'`
      [[ -z $T_Diff || $T_Diff == "na" ]] && T_Diff=$(( (TimeInEpochUtc - LastTime)/3600 ))
      [[ $T_Diff -eq 0 ]] && T_Diff=1
      [[ $ThisValue -ge $LastValue ]] && V_Diff=$(( ThisValue - LastValue )) || V_Diff=0
      ThisRate=$(( V_Diff / T_Diff ))
    else
      T_Diff=na
      V_Diff=na
      ThisRate=na
    fi
    fInsertSampleToDataFile $FileNodeType $NodeName $ThisInterface $ThisCounter $TimeInEpochUtc $T_Diff $ThisValue $V_Diff $ThisRate
  done < <(timeout $ThreadMaxProcessingTime interfacecounters --all-phy --min-value 1 --err-only --print-host $NodeName)
  sed -i -- '/^'"${NodeName}"'/d' $ThreadFeederFile
}

fInitParams

# CurrentTimeDiff=$(( `date '+%H'` - `date -u '+%H'` ))
# [[ `fGetConfParam ConfTimeMinusUTC` != "$CurrentTimeDiff" ]] && fSetConfParam ConfTimeMinusUTC $CurrentTimeDiff

DCList=`fGetConfParam DCs`
for ThisDC in $DCList; do
  DCDir=$ToolDir/$ThisDC
  [[ ! -d $DCDir ]] && mkdir -p $DCDir
  NodeTypeList=`fGetConfParam NodeTypesToMonitor`
  for ThisNodeType in $NodeTypeList; do
    [[ ! -f $DCDir/$ThisNodeType.dat ]] && touch $DCDir/$ThisNodeType.dat
  	cp $DCDir/$ThisNodeType.dat $DCDir/$ThisNodeType-1.dat
  	cat /dev/null > $DCDir/$ThisNodeType.dat
    NodeList=`nodedb $ThisDC $ThisNodeType | awk -F'|' '{print $1}'`
    for ThisNode in $NodeList; do
      while true; do
      	# Every minute clear idle processes
      	if [[ `echo $(date '+%S') | sed 's/^0//' | sed 's/^0//'` -eq 0 ]]; then
      	  CurrentTime=$(date '+%s')
      	  CurrentPreocesses=`cat $ThreadFeederFile`
          while read -r processline; do
            NodeNameOfProcess=`echo "$processline" | awk '{print $1}'`
            TimeStampOfProcess=`echo "$processline" | awk '{print $2}'`
            echo CurrentTime TimeStampOfProcess ThreadMaxProcessingTime - $CurrentTime $TimeStampOfProcess $ThreadMaxProcessingTime
            [[ $(( CurrentTime - TimeStampOfProcess )) -gt $ThreadMaxProcessingTime ]] && sed -i -- '/^'"${NodeNameOfProcess}"'/d' $ThreadFeederFile
          done < <(echo "$CurrentPreocesses")
      	fi
        ActiveThreadCount=`cat $ThreadFeederFile | wc -l`
        [[ "$ActiveThreadCount" -ge "$MultiThreading" ]] && sleep 1 || break
      done
      # Now call the process
      fProcessTheNode $ThisNode $ThisNodeType $ThisDC &
      echo $ThisNode $(date '+%s') >> $ThreadFeederFile
    done
  done
done

# Wait all remaining active threads to finish or time out
for index in $(eval echo {1..$ThreadMaxProcessingTime}); do
 [[ `cat $ThreadFeederFile | wc -l` -eq 0 ]] && break
 sleep 1
done

fCleaning
fSendReport

exit 0