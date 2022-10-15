CREATE TABLE "company" (
	"lei"	TEXT,
	"name"	TEXT,
	"address"	TEXT,
	"city"	TEXT,
	"postal_code"	TEXT,
	"country"	TEXT,
	"profile" TEXT,
	"url" TEXT,
	"founded" TEXT,
	PRIMARY KEY("lei")
) WITHOUT ROWID;


CREATE TABLE "industry" (
	"lei" TEXT,
	"industry" TEXT,
	FOREIGN KEY("lei") REFERENCES company("lei")
);


CREATE TABLE "schedule" (
	"lei" TEXT,
	"date" TEXT,
	"name" TEXT,
	"description"	TEXT,
	FOREIGN KEY("lei") REFERENCES company("lei")
);


CREATE TABLE "security" (
	"isin"	TEXT,
	"symbol"	TEXT,
	"wkn"	TEXT,
	"lei"	TEXT,
	"name"	TEXT,
	"type"	TEXT,
	"primary"	BOOLEAN,
	"outstanding"	INTEGER,
	PRIMARY KEY("isin"),
	FOREIGN KEY("lei") REFERENCES company("lei")
) WITHOUT ROWID;


CREATE TABLE "stock_index" (
	"isin"	TEXT,
	"symbol"	TEXT,
	"wkn"	TEXT,
	"name"	TEXT,
	"security" TEXT,
	PRIMARY KEY("isin")
) WITHOUT ROWID;


CREATE TABLE "index_security" (
	"index"	TEXT,
	"security"	TEXT,
	FOREIGN KEY("index") REFERENCES stock_index("isin"),
	FOREIGN KEY("security") REFERENCES security("isin")
);


CREATE TABLE "price" (
	"isin" TEXT,
	"timestamp" TEXT,
	"exchange" TEXT,
	"price" REAL,
	"currency" TEXT,
	FOREIGN KEY("isin") REFERENCES security("isin")
);


CREATE TABLE "dividend" (
	"isin"	TEXT,
	"year"	TEXT,
	"dividend"	REAL,
	"currency"	TEXT,
	PRIMARY KEY("isin", "year")
);


CREATE TABLE "annual_report" (
	"lei"	TEXT,
	"year"	INTEGER,
	"turnover"	INTEGER,
	"results_of_operations"	INTEGER,
	"income_after_tax"	INTEGER,
	"current_assets"	INTEGER,
	"capital_assets"	INTEGER,
	"equity"	INTEGER,
	"total_liabilities"	INTEGER,
	"total_assets"	INTEGER,
	"currency"	TEXT,
	"employees"	INTEGER,
	PRIMARY KEY("lei","year")
) WITHOUT ROWID;


CREATE TABLE "exchange_rate" (
	"date"	TEXT,
	"currency"	TEXT,
	"rate"	REAL,
	PRIMARY KEY("date","currency")
) WITHOUT ROWID;