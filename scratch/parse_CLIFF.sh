#!/bin/bash
# parse CLIFF JSON outputs
# take lowest level focus - city, state, or country
# take all mentions
# save as CSV
# records id used by output/ids TSV
# if no user args are found then it is assumed to read pipe separated values from STDIN
# where each line is a record, and the first field is the comma separated list of aiddata projects
# example use: $0 ../output/no_replaceAllDemonyms/ 
# example use: cat foo.txt | $0 
indir=$1
# path to hash_diff.pl - great for comparing unordered lists
hash_diff=./hash_diff.pl
# apostraphe for gnu parallel 
a="'"
# function to get blacklist of geoids from focus - states that have cities mentioned, countries that have states mentioned, countries that have cities mentioned
# this is intended to blacklist any parents whose children are present - in other words, take only leaves of the tree
function get_geoid_blacklist { 
	hash_diff=$2
	cities_state_ids=$( cat $1 | jq '.results.places.focus.cities[]|.stateGeoNameId|tonumber' 2>/dev/null )
	state_ids=$( cat $1 | jq '.results.places.focus.states[]|.id' 2>/dev/null )
	ignore_states_parent_cities=$( $hash_diff -a <(echo "$cities_state_ids" | grep -vE "^$") -b <( echo "$state_ids"|grep -vE "^$" ) | grep equal | grep -oE "^[^:]*" )
	states_country_ids=$( cat $1 | jq '.results.places.focus.states[]|.countryGeoNameId|tonumber' 2>/dev/null )
	country_ids=$( cat $1 | jq '.results.places.focus.countries[]|.id' 2>/dev/null )
	ignore_countries_parent_states=$( $hash_diff -a <(echo "$states_country_ids" | grep -vE "^$") -b <( echo "$country_ids"|grep -vE "^$" ) | grep equal | grep -oE "^[^:]*" )
	cities_country_ids=$( cat $1 | jq '.results.places.focus.cities[]|.countryGeoNameId|tonumber' 2>/dev/null )
	ignore_countries_parent_cities=$( $hash_diff -a <(echo "$cities_country_ids" | grep -vE "^$") -b <( echo "$country_ids"|grep -vE "^$" ) | grep equal | grep -oE "^[^:]*" )
	blacklist_geoids=$( cat <(echo "$ignore_states_parent_cities") <(echo "$ignore_countries_parent_states") <(echo "$ignore_countries_parent_cities") | sort | uniq | grep -vE "^$" )
	echo "$blacklist_geoids"
}
# make available to gnu parallel
export -f get_geoid_blacklist
# now for every json in the input dir, find the blacklist of geoids and get a csv from the json.  ignore any record with blacklisted geoid
# if there are no user args then it is assumed we read from STDIN and each line a pipe separated record, where the first field is to be appended to the output csv from json
if [[ -z $indir ]]; then
	# input is STDIN
	cat |\
	parallel --gnu '
		# first send into to CLIFF
		tocliff=$(
			echo {} |\
			# ignore first column
			mawk -F"|" "{\$1==\"\";print \$0}" |\
			# URI escape the rest
			perl -MURI::Escape -e '$a'print uri_escape(<STDIN>); print "\n";'$a'
		)
		# make tmp file for cliff json
		cliffjson=$(mktemp)
		curl -s "http://geocoder.aiddata.wm.edu:8080/CLIFF-2.1.1/parse/text?q=${tocliff}" > $cliffjson
		# get first field from STDIN
		id_field=$(
			echo {} |\
			mawk -F"|" "{print \$1}"
		)	
		# get blacklist of geoids - these are geoids of parents in focus that also have children in focus
		blacklist_geoids=$( get_geoid_blacklist $cliffjson '$hash_diff' )
		# get the following fields from mentions and focus as csv
		# NB jq csv outs very messy in terms of escaped double quotes
		# geonames id,placename,lat,lng,featureClass,featureCode,is_mention,is_focus,focus level,focus score 
		tmpcsv=$(cat $cliffjson |\
		jq '$a'[(.results.places.mentions[]|[.id,.name,.lat,.lon,.featureClass,.featureCode,1,0,"NA","NA"]),(.results.places.focus.cities[]|[.id,.name,.lat,.lon,.featureClass,.featureCode,0,1,"cities",.score]),(.results.places.focus.states[]|[.id,.name,.lat,.lon,.featureClass,.featureCode,0,1,"states",.score]),(.results.places.focus.countries[]|[.id,.name,.lat,.lon,.featureClass,.featureCode,0,1,"countries",.score])|@csv]'$a' 2>/dev/null |\
		grep -vE "^\[|^\]" |\
		sed "s:^\s\+::g;s:\s\+$::g" |\
		sed "s:^\"\|\"$::g;s:\\\::g" |\
		sed "s:\"\+:\":g" | sed "s:,$::g" )
		# if there is an tmpcsv to speak of them clean up formatting and append json file basename
		if [[ $(echo "$tmpcsv" | grep -vE "^$" | wc -l) > 0 ]]; then
			grep -vEf <(echo "$blacklist_geoids" | sed "s:^:^:g;s:$:,:g") <( echo "$tmpcsv") | sort | uniq | sed "s:^:${id_field},:g"
		fi
		rm $cliffjson
	'
else	
	# input is directory of files
	find $indir -type f |\
	parallel --gnu '
		# get blacklist of geoids - these are geoids of parents in focus that also have children in focus
		blacklist_geoids=$( get_geoid_blacklist {} '$hash_diff' )
		# get the following fields from mentions and focus as csv
		# NB jq csv outs very messy in terms of escaped double quotes
		# geonames id,placename,lat,lng,featureClass,featureCode,is_mention,is_focus,focus level,focus score 
		tmpcsv=$(cat {} |\
		jq '$a'[(.results.places.mentions[]|[.id,.name,.lat,.lon,.featureClass,.featureCode,1,0,"NA","NA"]),(.results.places.focus.cities[]|[.id,.name,.lat,.lon,.featureClass,.featureCode,0,1,"cities",.score]),(.results.places.focus.states[]|[.id,.name,.lat,.lon,.featureClass,.featureCode,0,1,"states",.score]),(.results.places.focus.countries[]|[.id,.name,.lat,.lon,.featureClass,.featureCode,0,1,"countries",.score])|@csv]'$a' 2>/dev/null |\
		grep -vE "^\[|^\]" |\
		sed "s:^\s\+::g;s:\s\+$::g" |\
		sed "s:^\"\|\"$::g;s:\\\::g" |\
		sed "s:\"\+:\":g" | sed "s:,$::g" )
		# if there is an tmpcsv to speak of them clean up formatting and append json file basename
		if [[ $(echo "$tmpcsv" | grep -vE "^$" | wc -l) > 0 ]]; then
			grep -vEf <(echo "$blacklist_geoids" | sed "s:^:^:g;s:$:,:g") <( echo "$tmpcsv") | sort | uniq | sed "s:^:$( basename {} ),:g"
		fi
	'
fi
