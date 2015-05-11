all : aiddata2_1%.sql



aiddata2_1%.sql : aiddata2_1_full_inserts_sql.zip
	-mkdir inserts/
	unzip -d inserts/ aiddata2_1_full_inserts_sql.zip
	touch inserts/*

aiddata2_1_full_inserts_sql.zip :
	wget -c https://data.itpir.wm.edu/aiddatascratch/aiddata/researchrelease/aiddata2_1_full_inserts_sql.zip
