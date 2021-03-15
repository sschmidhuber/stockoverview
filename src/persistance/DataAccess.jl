module DataAccess
    
using SQLite
using DataFrames
using Dates
using ..Model

DATA_BASE = "data/stockoverview.sqlite"

# store the given exchange rates to DB if they don't exist already
function store_exchange_rates(exchange_rates::EuroExchangeRates)
    db = SQLite.DB(DATA_BASE)
    n = DBInterface.execute(db, "select * from euro_exchange_rates where date = $(exchange_rates.date);") |> DataFrame |> nrow
    if n != 0
        stmt = SQLite.Stmt(db, "INSERT INTO euro_exchange_rates (date, currency, rate) VALUES (?,?,?);")
    
        foreach(exchange_rates.rates |> keys) do currency
            DBInterface.execute(stmt, [exchange_rates.date |> string, currency, exchange_rates.rates[currency]])
        end
    end
end

# retrieve exchange rates closest to the given date
function get_exchange_rates(date::Date)::EuroExchangeRates
    @warn "not implemented yet"
end

end # module