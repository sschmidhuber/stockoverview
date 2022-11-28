module DBAccess
    
using ..Model
using DataFrames
using Dates
using SQLite

export insert_update_company, insert_update_security, getsecurities, getcompanies

const DB = "../data/$(ENV["database"])"


"""
    getsecurities()::DataFrame

Returns the security table as DataFrame.
"""
function getsecurities()::DataFrame
    try
        db = SQLite.DB(DB)
        rs = DBInterface.execute(db, "SELECT * FROM security;") |> DataFrame
    catch
        @warn "couldn't read securities from DB"
    end        
end


"""
    getcompanies()::DataFrame

Returns the company table as DataFrame.
"""
function getcompanies()::DataFrame
    try
        db = SQLite.DB(DB)
        rs = DBInterface.execute(db, "SELECT * FROM company;") |> DataFrame
    catch
        @warn "couldn't read securities from DB"
    end
end


# insert the given security to DB
function insert_update_security(security::Security)
    db = SQLite.DB(DB)
    insert_update_security_common(db, security)
end

function insert_update_security(securities::Vector{Security})
    db = SQLite.DB(DB)
    nrecords = 0
    for security in securities
        nrecords += insert_update_security_common(db, security)
    end

    return nrecords
end

function insert_update_security_common(db, security)
    try
        if DBInterface.execute(db, "select * from security where isin = '$(security.isin)';") |> isempty
            stmt = SQLite.Stmt(db, "INSERT INTO security (isin, symbol, wkn, lei, name, type, main, outstanding) VALUES (?,?,?,?,?,?,?,?);")
            DBInterface.execute(stmt, [security.isin, security.symbol, security.wkn, security.lei, security.name, security.type, security.main, security.outstanding])
        else
            stmt = SQLite.Stmt(db, "UPDATE security SET symbol=?, wkn=?, lei=?, name=?, type=?, main=?, outstanding=? where isin=?;")
            DBInterface.execute(stmt, [security.symbol, security.wkn, security.lei, security.name, security.type, security.main, security.outstanding, security.isin])
        end

        return 1
    catch e
        @warn "failed to insert/update security: $(security.isin)"
        println(e)
        GC.gc()

        return 0
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
    nrecords = 0
    for company in companies
        nrecords += insert_update_company_common(db, company)
    end

    return nrecords
end

# the common part of insert_update_company methods, not supposed to be used from outside the module
function insert_update_company_common(db, company)
    try
        if DBInterface.execute(db, "select * from company where lei = '$(company.lei)';") |> isempty
            stmt = SQLite.Stmt(db, "INSERT INTO company (lei, name, address, city, postal_code, country, profile, url, founded) VALUES (?,?,?,?,?,?,?,?,?);")
            DBInterface.execute(stmt, [company.lei, company.name, company.location.address, company.location.city, company.location.postal_code, company.location.country, company.profile, company.url, company.founded])
        else
            stmt = SQLite.Stmt(db, "UPDATE company SET name=?, address=?, city=?, postal_code=?, country=?, profile=?, url=?, founded=? where lei=?;")
            DBInterface.execute(stmt, [company.name, company.location.address, company.location.city, company.location.postal_code, company.location.country, company.profile, company.url, company.founded, company.lei])
        end

        return 1
    catch e
        @warn "failed to insert/update company: $(company.lei)"
        println(e)
        GC.gc()

        return 0
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