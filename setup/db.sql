CREATE TABLE "euro_exchange_rate" (
	"date"	TEXT,
	"currency"	TEXT,
	"rate"	REAL,
	PRIMARY KEY("date","currency")
) WITHOUT ROWID;


CREATE TABLE "company" (
	"lei"	TEXT,
	"name"	TEXT,
	"address"	TEXT,
	"city"	TEXT,
	"country"	TEXT,
	"postal_code"	TEXT,
	PRIMARY KEY("lei")
) WITHOUT ROWID;