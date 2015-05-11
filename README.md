# adt-crs-geocode


### grab and store CLIFF JSON output for further parsing

Automatically geocode the OECD CRS using CLIFF-CLAVIN:

* Makefile downloads AidData 2.1 static dataset and puts it in PostgreSQL
  * which is enriched CRS compiled with an accretive year-on-year model
* run.sh stores PostgreSQL inputs under output/input as well as CLIFF JSON outputs under output/{no_replaceAllDemonyms,replaceAllDemonyms} depending on whether replaceAllDemonyms was used
  * files are named according to sequential ids whose real meaning (recipient_iso3,startYear,endYear,projectIDs) is stored in output/ids
