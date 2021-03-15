CREATE TABLE "euro_exchange_rate" (
	"date"	TEXT,
	"currency"	TEXT,
	"rate"	REAL,
	PRIMARY KEY("date","currency")
) WITHOUT ROWID;