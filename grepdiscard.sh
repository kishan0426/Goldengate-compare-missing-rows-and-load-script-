grep -h ‘SID =' abc.dsc_20260805_021501 bcd.dsc_20260805_023001 cde.dsc_20260805_031502 | \
cut -d= -f2 | \
awk '{print "insert into SCHEMA.TABLE(DID) values (" $1 ");"}' > insert.sql

grep -wh 'SID =' abc00.dsc_20260413_020001 | \
cut -d= -f2 | \
awk '{print $1}' > insert1.sql
