CREATE TABLE "company" (
	"lei"	TEXT,
	"name"	TEXT,
	"address"	TEXT,
	"city"	TEXT,
	"postal_code"	TEXT,
	"country"	TEXT,
	"profile"	TEXT,
	"url"	TEXT,
	"founded"	TEXT,
	"updated"	TEXT,
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
	"main"	BOOLEAN,
	"outstanding"	INTEGER,
	"updated"	TEXT,
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
	"free_cashflow"	INTEGER,
	"currency"	TEXT,
	"employees"	INTEGER,
	"updated"	TEXT,
	PRIMARY KEY("lei","year")
) WITHOUT ROWID;


CREATE TABLE "metrics" (
	"isin"	TEXT,
	"market_cap"	INTEGER,
	"price_earning_ratio"	REAL,
	"price_book_ratio"	REAL,
	"dividend_return_ratio"	REAL,
	"dividend_return_ratio_avg3"	REAL,
	"dividend_payout_ratio"	REAL,
	"dividend_payout_ratio_avg3"	REAL,
	"price_cashflow_ratio" REAL,
	PRIMARY KEY("isin")
) WITHOUT ROWID;


CREATE TABLE "exchange_rate" (
	"date"	TEXT,
	"currency"	TEXT,
	"rate"	REAL,
	PRIMARY KEY("date","currency")
) WITHOUT ROWID;