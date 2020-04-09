#!/bin/bash
# Onur

fInitParams() {
  ToolDir=/home/oarican/tools/SiteMonitoringAgent
  ReportsDir=$ToolDir/reports
  WebDir=/var/www/html/reports/counters
  TemplatesDir=$ToolDir/templates
  GraphLinkTemplateFile=$TemplatesDir/graphnlinktemplate.html
  CounterPageTemplateFile=$TemplatesDir/counterpagetemplate.html
  IndexPageTemplateFile=$TemplatesDir/indextemplate.html
  ContentsDir=$WebDir/content; [[ ! -d $ContentsDir ]] && mkdir -p $ContentsDir
  BackupsDir=$ToolDir/backups
  MaxBackupFileAgeInDays=183
  UsersName=`whoami`
  CounterList=`echo -e "CRC\nPAUSE_input\nPAUSE_output\nrunts\ngiants\ninput_error\nalignment\nsymbol\ninput_discard\noutput_error\ncollision\nlate_collision\ndeferred\noutput_discard\nstorm_suppression\nno_buffer\nshort_frame\noverrun\nunderrun\nignored\nwatchdog\nbad_etype_drop\nbad_proto_drop\nif_down_drop\ninput_with_dribble\nlost_carrier\nno_carrier\nbabble\nFraming_errors\nPoliced_discards\nL3_incompletes\nL2_channel_errors\nL2_mismatch_timeouts\nFIFO_errors\nResource_errors\nCarrier_transitions\nAged_packets\nPCS_Bit_errors\nPCS_Errored_blocks\nOutput_packet_error_count"`
  DCList=`echo all;ls $ReportsDir`
}
fContentBackup() {
  CurrentTime=`date '+%Y%m%d-%H%M%S'`
  tar -cvzf $BackupsDir/$CurrentTime-content.tgz -C $ContentsDir .
  find $BackupsDir -name "*.tgz" -type f -mtime +`echo $MaxBackupFileAgeInDays` -exec rm -f {} \;
}

fInitParams

# Backup every Monday at 00:00
[[ `date '+%u%H'` == "100" ]] && fContentBackup

for ThisCounter in $CounterList; do
  CounterDir=$ContentsDir/$ThisCounter
  [[ -d $CounterDir/temp ]] && rm -rf $CounterDir/temp
  case "$ThisCounter" in
    PAUSE_input)    searchpattern="PAUSE_input\|rx_pause";;
    PAUSE_output)   searchpattern="PAUSE_output\|tx_pause";;
    input_discard)  searchpattern="input_discard\|rx_Drops";;
    input_error)    searchpattern="input_error\|rx_Errors";;
    output_discard) searchpattern="output_discard\|tx_Drops";;
    output_error)   searchpattern="output_error\|tx_Errors";;
    runts)          searchpattern="runts\|Runts";;
    giants)         searchpattern="giants\|MTU_errors";;
    collision)      searchpattern="collision\|Collision";;
    *)              searchpattern=$ThisCounter
  esac
  for ThisDC in $DCList; do
  	[[ "$ThisDC" == "all" ]] && GrepDcPattern="." || GrepDcPattern=$ThisDC
  	ErrorList=`grep "$searchpattern" -hr $ReportsDir | grep $GrepDcPattern | awk -F'|' '$8!="0" && $8!="na"' | sort -rnk8 -t'|'`
    [[ -z $ErrorList ]] && continue
    count1=`echo "$ErrorList" | wc -l`
    count2=`grep "$searchpattern" -hr $ReportsDir | grep $GrepDcPattern | awk -F'|' '$8>=100/24 && $8!="na"' | wc -l`
    count3=`grep "$searchpattern" -hr $ReportsDir | grep $GrepDcPattern | awk -F'|' '$8>=1000/24 && $8!="na"' | wc -l`
    count4=`grep "$searchpattern" -hr $ReportsDir | grep $GrepDcPattern | awk -F'|' '$8>=10000/24 && $8!="na"' | wc -l`
    count5=`grep "$searchpattern" -hr $ReportsDir | grep $GrepDcPattern | awk -F'|' '$8>=100000/24 && $8!="na"' | wc -l`
    count6=`grep "$searchpattern" -hr $ReportsDir | grep $GrepDcPattern | awk -F'|' '$8>=1000000/24 && $8!="na"' | wc -l`
    count7=`grep "$searchpattern" -hr $ReportsDir | grep $GrepDcPattern | awk -F'|' '$8>=10000000/24 && $8!="na"' | wc -l`

    count1=$((count1-count2))
    count2=$((count2-count3))
    count3=$((count3-count4))
    count4=$((count4-count5))
    count5=$((count5-count6))
    count6=$((count6-count7))

    [[ ! -d $CounterDir || ! -d $CounterDir/temp ]] && mkdir -p $CounterDir/temp
    sed 's/thetitle/'"${ThisDC}"' - '"${ThisCounter}"'/' $GraphLinkTemplateFile | sed 's/thetextfileref/'"${ThisCounter}"'-'"${ThisDC}"'.txt/' | sed 's/thedc/'"${ThisDC}"'/' | sed 's/thecounter/'"${ThisCounter}"'/' | sed 's/1to100/'"${count1}"'/' | sed 's/100to1000/'"${count2}"'/' | sed 's/1000to10000/'"${count3}"'/' | sed 's/10000to100000/'"${count4}"'/' | sed 's/100000to1000000/'"${count5}"'/' | sed 's/1000000to10000000/'"${count6}"'/' | sed 's/10000000above/'"${count7}"'/' > $CounterDir/temp/$ThisCounter-$ThisDC.html
    printf "%20s %20s %20s %20s\n" "Device" "Interface" "Counter" "Error Rate (/hr)" > $CounterDir/temp/$ThisCounter-$ThisDC.txt
    echo " -------------------  -------------------  -------------------  -------------------" >> $CounterDir/temp/$ThisCounter-$ThisDC.txt
    echo "$ErrorList" | awk -F'|' '{printf "%20s %20s %20s %20d\n", $1, $2, $3, $8}' >> $CounterDir/temp/$ThisCounter-$ThisDC.txt
  done
  rm -f $CounterDir/*.txt
  rm -f $CounterDir/*.html
  cp $CounterDir/temp/* $CounterDir/
  rm -rf $CounterDir/temp
  # Build Counter's HTML file
  cp -f $CounterPageTemplateFile $ContentsDir/$ThisCounter.html
  index=`grep -n iframes $ContentsDir/$ThisCounter.html | awk -F':' '{print $1}'`
  CounterDCList=`ls $CounterDir/*.txt | sed 's/^.*\///' | sed 's/\.txt$//'`
  for ThisCounterDC in $CounterDCList; do
    let "index++"
    ThisDC=`echo "$ThisCounterDC" | awk -F'-' '{print $1}'`
    string=`echo "<iframe src=\"$ThisDC/$ThisCounterDC.html\" height=\"285\" width=\"510\"></iframe>"`
    sed  -i -- ''"${index}"' i\'"${string}"'' $ContentsDir/$ThisCounter.html
  done
done

# Create index.html and populate dropdown menu of index.html and Counter's HTML files
cp -f $IndexPageTemplateFile $WebDir/index.html
index1=`grep -n "div class=.dropdown-content" $WebDir/index.html | awk -F':' '{print $1}'`
index2=`grep -n "div class=.dropdown-content" $CounterPageTemplateFile | awk -F':' '{print $1}'`
CounterDirectoriesList=`du $ContentsDir | sort -rn | tail -n +2 | awk '{print $2}' | sed 's/^.*\///g'`
for ThisCounter in $CounterDirectoriesList; do
  let "index1++"
  let "index2++"
  string1=`echo "      <a href=\"content/$ThisCounter.html\">$ThisCounter</a>"`
  sed  -i -- ''"${index1}"' i\'"${string1}"'' $WebDir/index.html
  string2=`echo "      <a href=\"$ThisCounter.html\">$ThisCounter</a>"`
  while read -r ThisCounterHtmlFile; do
    sed  -i -- ''"${index2}"' i\'"${string2}"'' $ThisCounterHtmlFile
  done < <(ls $ContentsDir/*.html)
done

exit 0