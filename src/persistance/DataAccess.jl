module DataAccess
    
using SQLite
using DataFrames
using Dates
using ..Model

DB = "../data/stockoverview.sqlite"

# insert the given company to DB or update if it exists already
function insert_update_company(company::Company)
    db = SQLite.DB(DB)
    n = DBInterface.execute(db, "select * from company where lei = '$(company.lei)';") |> DataFrame  |> nrow
    if n == 0
        stmt = SQLite.Stmt(db, "INSERT INTO company (lei, name, address, city, country, postal_code) VALUES (?,?,?,?,?,?);")
        DBInterface.execute(stmt, [company.lei, company.name, company.location.address, company.location.city, company.location.country, company.location.postal_code])
    else
        stmt = SQLite.Stmt(db, "UPDATE company SET lei = ?, name = ?, address = ?, city = ?, country = ?, postal_code = ? where lei = ?;")
        DBInterface.execute(stmt, [company.lei, company.name, company.location.address, company.location.city, company.location.country, company.location.postal_code, company.lei])
    end
end


function load_companies(companies::Vector{Company})
    df = DataFrame(:lei => [], :name => [], :address => [], :city => [], :country => [], :postal_code => [])

    foreach(companies) do company
        push!(df, (lei = company.lei, name = company.name, address = company.location.address, city = company.location.city, country = company.location.country, postal_code = company.location.postal_code))
    end

    db = SQLite.DB(DB)
    df |> SQLite.load!(db, "company")
end

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
function insert_exchange_rates(exchange_rates::EuroExchangeRates)
    db = SQLite.DB(DB)
    n = DBInterface.execute(db, "select * from euro_exchange_rates where date = $(exchange_rates.date);") |> DataFrame |> nrow
    if n != 0
        stmt = SQLite.Stmt(db, "INSERT INTO euro_exchange_rates (date, currency, rate) VALUES (?,?,?);")
    
        foreach(exchange_rates.rates |> keys) do currency
            DBInterface.execute(stmt, [exchange_rates.date |> string, currency, exchange_rates.rates[currency]])
        end
    end
end

# returns latest available euro exchange rates
function get_exchange_rates()::Union{EuroExchangeRates,Nothing}
    db = SQLite.DB(DB)
    rs = DBInterface.execute(db, "select * from euro_exchange_rates where date = (select max(date) from euro_exchange_rates);") |> DataFrame

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