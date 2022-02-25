CREATE TABLE "company" (
	"lei"	TEXT,
	"name"	TEXT,
	"address"	TEXT,
	"city"	TEXT,
	"country"	TEXT,
	"postal_code"	TEXT,
	PRIMARY KEY("lei")
) WITHOUT ROWID;


CREATE TABLE "security" (
	"isin"	TEXT,
	"symbol"	TEXT,
	"wkn"	TEXT,
	"lei"	TEXT,
	"name"	TEXT,
	"type"	TEXT,
	"shares_outstanding"	INTEGER,
	PRIMARY KEY("isin"),
	FOREIGN KEY("lei") REFERENCES company("lei")
) WITHOUT ROWID;


CREATE TABLE "price" (
	"isin" TEXT,
	"price" REAL,
	"timestamp" TEXT,
	"currency" TEXT,
	PRIMARY KEY("isin")
) WITHOUT ROWID;


CREATE TABLE "annual_report" (
	"lei"	TEXT,
	"year"	INTEGER,
	PRIMARY KEY("lei")
) WITHOUT ROWID;


CREATE TABLE "metrics" (
	"isin" TEXT,
	"price_earnings_ratio" REAL,
	"price_book_ratio" REAL,
	"dividend_return_ratio" REAL,
	PRIMARY KEY("isin")
) WITHOUT ROWID;


CREATE TABLE "exchange_rate" (
	"date"	TEXT,
	"currency"	TEXT,
	"rate"	REAL,
	PRIMARY KEY("date","currency")
) WITHOUT ROWID;