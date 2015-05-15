#!/bin/bash
# parse CLIFF JSON outputs
# take lowest level focus - city, state, or country
# take all mentions
# save as TSV
# records id used by output/ids TSV
# TODO
# if mention has same geoid as focus, report its mentions.source.string
# example use: $0 ../output/no_replaceAllDemonyms/ 

indir=$1

# get fields from mentions
function get_mentions { cat $1 | jq '.results.places.mentions[]|[.id,.name,.lat,.lon,.featureClass,.featureCode,.source.string]|@csv'; }
export -f get_mentions
# get fields from cities, states, or countries
function get_focus { cat $1 | jq --arg level $2 '.results.places.focus|select(.[$level] != null)|select(.[$level] != [])|.[$level][]|[.id,.name,.lat,.lon,.featureClass,.featureCode,.score]|@csv';}
export -f get_focus
# for every JSON output from CLIFF, get mentions and get lowest level focus
find $indir -type f |\
parallel '
	#get_mentions {}
	# get the lowest level of focus available
	# NB: but what about the case where one city is found, and two states?
	# NB: rarely there will be cities but no state, etc - odd
	cities=$( get_focus {} cities )
	states=$( get_focus {} states )
	countries=$( get_focus {} countries )
	count_cities=$( echo "$cities" | grep -vE "^$" | wc -l )
	count_states=$( echo "$states" | grep -vE "^$" | wc -l )
	count_countries=$( echo "$countries" | grep -vE "^$" | wc -l )
	echo -e "$count_cities\t$count_states\t$count_countries"
# this prints the JSON if there is a city mentioned *and* state mentioned that does not contain that city (naive method - looks for count)
#	if [[ $count_cities == 1 && $count_states > 1 ]]; then 
#		echo {}
#		echo -e "$count_cities\t$count_states\t$count_countries"
#	fi

# this uses the lowest level available - however, we really ought to keep the lowest level children generally (eg, one city and one state that does not contain that city)
#	if [[ -n "$cities" ]]; then 
#		echo $cities
#	elif [[ -n "$states" ]]; then
#		echo "$states"
#	elif [[ -n "$countries" ]]; then
#		echo "$countries"
#	fi 
'
