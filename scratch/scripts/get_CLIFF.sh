#!/bin/bash
# get 
# user args: 1) TSV in the form: "recipient_iso3\tstart_year\tend_year", 2) postgres db with AidData2.1 inserts, 3) CLIFF server string up to and including "?q=", 4) directory for outputs, which will be replaced and take the form $outdir/{replaceAllDemonyms,no_replaceAllDemonyms}
# NB: outdir will be replaced!
# NB: CLIFF_server_string needed to show CLIFF version number, port
# example use: $0 adt21CountryYears.tsv aiddata21 "http://geocoder.aiddata.wm.edu:8080/CLIFF-2.1.1/parse/text?q=" ../output

intsv=$1
db=$2
CLIFF_server_string=$3
outdir=$4

# function to make outdir directories
function mk_outdirs {
	# NB: outdir will be replaced!
	rm -rf $outdir/
	mkdir -p $outdir/{input,replaceAllDemonyms,no_replaceAllDemonyms}
}

# function to build SQL based on input user arg TSV w/ country, start year, end year, and to pass that SQL to postgres
function get_intxt {
	# input TSV in the form: "recipient_iso3\tstart_year\tend_year"
	# apostraphe for GNU parallel
	a="'"
	# for every recipient country and its year ranges, get pipe separated title,short_description,long_description along with a comma separated list of aiddata_id
	cat $intsv |\
	parallel --gnu --colsep '\t' --header : '
		echo "COPY 
			( SELECT 
				-- prepend with text of country-startyear-endyear so we can make directories later
				'$a'{1}-{2}-{3}'$a',
				string_agg(aiddata_id::text,'$a','$a') AS aiddata_ids,
				title,
				short_description,
				long_description 
			FROM 
				aiddata2_1 
			WHERE 
				recipient_iso3 = '$a'{1}'$a' 
				AND YEAR >= '$a'{2}'$a' 
				AND YEAR <= '$a'{3}'$a' 
			GROUP BY 
				title,short_description,long_description )
		 TO STDOUT WITH DELIMITER '$a'|'$a';" |\
		psql '$db'
	'
}

# function to actually pass URL encoded strings to CLIFF
function pass_to_CLIFF {
	# pass URL encoded title,short_description,long_description to CLIFF
	# first pass is default, without replaceAllDemonyms
	curl -s "http://geocoder.aiddata.wm.edu:8080/CLIFF-2.1.1/parse/text?q=${1}${2}" |\
	# use jq to pretty print JSON CLIFF response
	jq '.' 
}

# function to append IDs to a lookup table ($outdir/ids), and to deposit inputs into $outdir/input and JSON output into $outdir/{replaceAllDemonyms,no_replaceAllDemonyms}
function get_json {
	# start an id variable so that id filenames are not too long for the filesystem
	id=1
	# start a lookup table for ids
	echo -e "id\tcountry-start-end-projects_id" > $outdir/ids
	# for each unique title,short_description,long_description from aiddata2.1, pass to CLIFF for NER and geocoding
	while read line
	do 
		# find which country-startyear-endyear-projects (csep) we are working on
		csep_id=$(
			echo "$line" |\
			mawk -F'|' '{OFS="-";print $1,$2}' 
		)
		# append id (for filenames) and csep_id (actual request meaning) to a lookup table 
		echo -e "$id\t$csep_id" >> $outdir/ids
		url_encode=$( 
			echo "$line" |\
			# get just title,short_description,long_description
			# we do not want to pass aiddata_ids to CLIFF
			mawk -F'|' '{OFS="|";print $3,$4,$5}' |\
			# URL encode STDIN
			perl -MURI::Escape -e 'print uri_escape(<STDIN>); print "\n";'
		)
		# pass URL encoded title,short_description,long_description to CLIFF
		# do this both with replaceAllDemonyms and no_replaceAllDemonyms
		for i in replaceAllDemonyms no_replaceAllDemonyms
		do
			if [[ $i == "replaceAllDemonyms" ]]; then
				string="&replaceAllDemonyms=TRUE"
			else
				string=""
			fi
			pass_to_CLIFF "$url_encode" $string > $outdir/$i/$id
		done
		# report the original input, including pipe separated title,short_description,long_description along with a comma separated list of aiddata_id
		echo "$line" > $outdir/input/$id
		# increment lookup id
		id=$(($id+1))
	done
}

mk_outdirs
get_intxt |\
get_json
