#!/bin/bash
#Beau LaChance
#2/8/2018
#A differently organized way of looking at Splunk's indexer cluster/peer info.
#For pure shits and giggles

#NOTE: jq package is required for this to work right.
command -v jq >/dev/null 2>&1 || { echo >&2 "This script requires jq but it's not installed.  Aborting."; exit 1; }
cmuri=yoursplunkclustermaster.com #Can also be an IP.
mgmtport=8089   #This is the default
password=somepassword
#No, I don't care about my plaintext password. You might.

#Pull down cluster peer info as JSON (default XML return sucks) and run it through jq. 
rest_return=$(curl -sk -u admin:$password https://$cmuri:$mgmtport/services/cluster/master/peers?output_mode=json | jq)

#Define variables for shenanigans
numpeers=$(echo "$rest_return" |grep -c name)
bucketcount=0
uppeers=0
searchablepeers=0

#Iterate through the JSON results, for the number of peers returned, to collect status. For whatever reason, jq requires I use |tonumber in order to convert variable type.
for ((i=0;i<numpeers;i++)); do
#PER HOST
     HOST=$(echo "$rest_return" | jq --arg i "$i" '.entry[$i|tonumber].content.label' | sed s/\"//g)
     GUID=$(echo "$rest_return" | jq --arg i "$i" '.entry[$i|tonumber].name' | sed s/\"//g)
     SITE=$(echo "$rest_return" | jq --arg i "$i" '.entry[$i|tonumber].content.site' | sed s/\"//g)
     SEARCHABLE=$(echo "$rest_return" | jq --arg i "$i" '.entry[$i|tonumber].content.is_searchable' | sed s/\"//g)
     BUCKETS=$(echo "$rest_return" | jq --arg i "$i" '.entry[$i|tonumber].content.bucket_count' | sed s/\"//g)
     STATUS=$(echo "$rest_return" | jq --arg i "$i" '.entry[$i|tonumber].content.status' | sed s/\"//g)

#The sed commands are not required, but I wanted to strip out quotes.

#CLUSTER TOTALS
     bucketcount=$(($bucketcount+$BUCKETS))         #Running addition of bucket count
     if [ "$SEARCHABLE" == "true" ]; then
          searchablepeers=$(($searchablepeers+1))   #Running addition of searchable peers
     fi
     if [ "$STATUS" == "Up" ]; then
          uppeers=$(($uppeers+1))                   #Running addition of peers with "Up" status
     fi
#More counters can be added. I am lazy.

#Output per host info
     echo -e "Host:\t\033[4m$HOST\033[0m\tGUID:\t\033[4m$GUID\033[0m\tSite:\t\033[4m$SITE\033[0m\t\tStatus:\t\033[4m$STATUS\033[0m\t\tSearchable:\t\033[4m$SEARCHABLE\033[0m\tBuckets:\t\033[4m$BUCKETS\033[0m"

done

#Output cluster totals. Again, more can be added by implementing more counters.

echo -e '\n\n\033[7mOverall Cluster Status\033[0m'
echo "Cluster contains " $bucketcount " buckets."
echo $uppeers " out of " $numpeers " indexer peers are up."
echo $searchablepeers " out of " $numpeers " indexer peers are searchable."
