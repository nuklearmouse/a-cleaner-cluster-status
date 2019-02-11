#!/bin/bash
#Beau LaChance
#Technical Support Engineer for Splunk, Inc
#2/8/2018

#idxscan.sh :
#  A differently organized way of looking at Splunk's indexer cluster/peer info. This is quite similar
#  to the "show cluster-status" command, except with aggregates.

#NOTE: jq package is required for this to work right - we use it to parse JSON response. So we run a check for jq :
command -v jq >/dev/null 2>&1 || { echo >&2 "This script requires jq but it's not installed.  Aborting."; exit 1; }


#CONFIG OPTIONS
cmuri=hostname.com #Can also be an IP.
mgmtport=8089   #This is the default
password=somepassword
#No, I don't care about my plaintext password stored in a script. You might. The curl command can be changed to forgo the password and you will be prompted at run time.

#Pull down cluster peer info as JSON (our default XML return sucks, and I hate parsing it), then run it through jq.
rest_return=$(curl -sk -u admin:$password https://$cmuri:$mgmtport/services/cluster/master/peers?output_mode=json)


if [ $(echo "$rest_return" | grep -c Unauthorized ) == "1" ]; then
     echo -e "The REST call returned an authorization error:\n" $rest_return "\nPlease check your credentials. Aborting."
     exit 1
fi


if [ -z "$rest_return" ]; then
     echo "A valid response was not received. Please check your Cluster Master hostname/IP and management port for connectivity, and that the Splunk process is running."
     exit 1
fi


#Define variables for our shenanigans / final aggregations.
#  MANY more options exist for what values to return. You can fairly easily change or add counters by looking at the JSON response and including variables/loops for those fields.
#  In later versions I may include a config in the script for what values to include, for modularity.
#  EG: More status for peers; last_heartbeat; indexing_disk_space; replication factor, etc

numpeers=$(echo "$rest_return" | jq '.entry' | grep -c name)
bucketcount=0
uppeers=0
downpeers=0
searchablepeers=0

#Output CM name
cmname=$(echo "$rest_return" | jq '.origin' | awk -F: '{print $2}' | cut -c3-)
echo -e "Information on the indexer cluster controlled by $cmname :\n"


#Iterate through the JSON results, for the number of peers returned, to collect status. For whatever reason, jq requires I use |tonumber in order to convert variable type.
# This is essentially the juicy part / workhorse of the script.

for ((i=0;i<numpeers;i++)); do
#PER HOST
     HOST=$(echo "$rest_return" | jq --arg i "$i" '.entry[$i|tonumber].content.label' | sed s/\"//g)
     GUID=$(echo "$rest_return" | jq --arg i "$i" '.entry[$i|tonumber].name' | sed s/\"//g)
     SITE=$(echo "$rest_return" | jq --arg i "$i" '.entry[$i|tonumber].content.site' | sed s/\"//g)
     SEARCHABLE=$(echo "$rest_return" | jq --arg i "$i" '.entry[$i|tonumber].content.is_searchable' | sed s/\"//g)
     BUCKETS=$(echo "$rest_return" | jq --arg i "$i" '.entry[$i|tonumber].content.bucket_count' | sed s/\"//g)
     STATUS=$(echo "$rest_return" | jq --arg i "$i" '.entry[$i|tonumber].content.status' | sed s/\"//g)

#The sed commands are not required, but I wanted to strip out quotes from the values.

#CLUSTER TOTALS
     bucketcount=$(($bucketcount+$BUCKETS))         #Running addition of bucket count
     if [ "$SEARCHABLE" == "true" ]; then
          searchablepeers=$(($searchablepeers+1))   #Running addition of searchable peers
     fi
     if [ "$STATUS" == "Up" ]; then
          uppeers=$(($uppeers+1))                   #Running addition of peers with "Up" status
     fi
     if [ "$STATUS" == "Down" ]; then
          downpeers=$(($downpeers+1))               #Running addition of peers with "Down" status
     fi
#More counters can be added. I am lazy.

#Output per host info
     echo -e "Host:\t\033[4m$HOST\033[0m\tGUID:\t\033[4m$GUID\033[0m\tSite:\t\033[4m$SITE\033[0m\t\tStatus:\t\033[4m$STATUS\033[0m\t\tSearchable:\t\033[4m$SEARCHABLE\033[0m\tBuckets:\t\033[4m$BUCKETS\033[0m"

done

#Output cluster totals. Again, more can be added by implementing more counters.

echo -e '\n\n\033[7mOverall Cluster Status\033[0m'
echo "Cluster contains " $bucketcount " buckets."
echo $uppeers " out of " $numpeers " indexer peers are up."
echo $downpeers " out of " $numpeers " indexer peers are down."
echo $searchablepeers " out of " $numpeers " indexer peers are searchable."
