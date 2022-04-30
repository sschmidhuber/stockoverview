module DataAccess
    
using SQLite
using DataFrames
using Dates

using ..Models

DB = "data/$(ENV["database"])"

"""
return string to database file
"""
function getdbfile()
    return DB
end

# get security table as DataFrame
function get_securities()
    try
        db = SQLite.DB(DB)
        rs = DBInterface.execute(db, "SELECT * FROM security;") |> DataFrame
    catch
        @warn "couldn't read securities from DB"
    end
        
end


# insert the given security to DB
function insert_security(security::Security)
    db = SQLite.DB(DB)
    stmt = SQLite.Stmt(db, "INSERT INTO security (isin, symbol, wkn, lei, name, type) VALUES (?,?,?,?,?,?);")

    try
        DBInterface.execute(stmt, [security.isin, security.symbol, security.wkn, security.lei, security.name, security.type])
    catch e
        @warn "failed to insert $(security.isin) : $(security.name)"
        showerror(stdout, e)
        print("\n")
        GC.gc()
    end
end

# insert the given company to DB or update if a record with the same LEI exists already
function insert_update_company(company::Company)
    db = SQLite.DB(DB)
    insert_update_company_common(db, company)
end

# insert a vector of companies to DB or update if a record with the same LEI exists already
function insert_update_company(companies::Vector{Company})
    db = SQLite.DB(DB)
    for company in companies
        insert_update_company_common(db, company)
    end
end

# the common part of insert_update_company methods, not supposed to be used from outside the module
function insert_update_company_common(db, company)
    n = DBInterface.execute(db, "select * from company where lei = '$(company.lei)';") |> DataFrame  |> nrow
    if n == 0
        stmt = SQLite.Stmt(db, "INSERT INTO company (lei, name, address, city, country, postal_code) VALUES (?,?,?,?,?,?);")
        DBInterface.execute(stmt, [company.lei, company.name, company.location.address, company.location.city, company.location.country, company.location.postal_code])
    else
        stmt = SQLite.Stmt(db, "UPDATE company SET lei = ?, name = ?, address = ?, city = ?, country = ?, postal_code = ? where lei = ?;")
        DBInterface.execute(stmt, [company.lei, company.name, company.location.address, company.location.city, company.location.country, company.location.postal_code, company.lei])
    end
end

# insert vector of companies, thow error if insert fails
function insert_company(companies::Vector{Company})
    db = SQLite.DB(DB)
    stmt = SQLite.Stmt(db, "INSERT INTO company (lei, name, address, city, country, postal_code) VALUES (?,?,?,?,?,?);")
    for company in companies
        try
            DBInterface.execute(stmt, [company.lei, company.name, company.location.address, company.location.city, company.location.country, company.location.postal_code]) 
        catch e
            @warn "failed to insert company: " * company.name * " (LEI: " * company.lei * ")"
        end
    end
end

# insert a vector of companies into DB
function load_companies(companies::Vector{Company})
    df = DataFrame(:lei => [], :name => [], :address => [], :city => [], :country => [], :postal_code => [])

    foreach(companies) do company
        push!(df, (lei = company.lei, name = company.name, address = company.location.address, city = company.location.city, country = company.location.country, postal_code = company.location.postal_code))
    end

    db = SQLite.DB(DB)
    df |> SQLite.load!(db, "company")
end

# insert a vector of companies into DB (but implemented as loop)
function insert_companies(companies::Vector{Company})
    db = SQLite.DB(DB)
    stmt = SQLite.Stmt(db, "INSERT INTO company (lei, name, address, city, country, postal_code) VALUES (?,?,?,?,?,?);")

    foreach(companies) do company
        try
            DBInterface.execute(stmt, [company.lei, company.name, company.location.address, company.location.city, company.location.country, company.location.postal_code])
        catch e
            @warn "failed to insert $(company.lei) : $(company.name)"
            showerror(stdout, e)
            print("\n")
            GC.gc()
        end
    end
end

# insert the given exchange rates to DB if they don't exist already
function insert_exchange_rate(exchange_rate::EuroExchangeRates)
    db = SQLite.DB(DB)
    n = DBInterface.execute(db, "select * from exchange_rate where date = $(exchange_rate.date);") |> DataFrame |> nrow
    if n != 0
        stmt = SQLite.Stmt(db, "INSERT INTO exchange_rate (date, currency, rate) VALUES (?,?,?);")
    
        foreach(exchange_rate.rates |> keys) do currency
            DBInterface.execute(stmt, [exchange_rate.date |> string, currency, exchange_rate.rates[currency]])
        end
    end
end

# returns latest available euro exchange rates
function get_exchange_rate()::Union{EuroExchangeRates,Nothing}
    db = SQLite.DB(DB)
    rs = DBInterface.execute(db, "select * from exchange_rate where date = (select max(date) from exchange_rate);") |> DataFrame

    if nrow(rs) == 0
        # not exchange rates available
        return nothing
    end

    rates = Dict()
    for i in 1:length(rs.currency)
        rates[rs.currency[i]] = rs.rate[i]
    end

    return EuroExchangeRates(rs.date |> first |> Date, rates)
end

end # module