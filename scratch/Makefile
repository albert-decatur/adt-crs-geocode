# get AidData 2.1 into Postgres, pull out recipient country/years according to a TSV of the form "crs\t\t"
# NB
# user must have postgres permissions to createdb
# TODO 
# do not download zip when unzipped inserts/ exists
# do not unzip to inserts/ when inserts/ exists

db = foo

all : insert

aiddata2_1_full_inserts_sql.zip :
	wget -c https://data.itpir.wm.edu/aiddatascratch/aiddata/researchrelease/aiddata2_1_full_inserts_sql.zip

aiddata2_1%.sql : aiddata2_1_full_inserts_sql.zip
	-mkdir inserts/
	unzip -d inserts/ aiddata2_1_full_inserts_sql.zip
	touch inserts/*
	rm aiddata2_1_full_inserts_sql.zip

insert : aiddata2_1%.sql
	dropdb $(db)
	createdb $(db)
	cat inserts/aiddata2_1_create_table.sql | psql $(db)
	cat inserts/aiddata2_1_full_inserts.sql | psql $(db)
	
