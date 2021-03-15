module DataAccess
    
using SQLite
using DataFrames
using Dates
using ..Model

DB = "data/stockoverview.sqlite"

# store the given exchange rates to DB if they don't exist already
function store_exchange_rates(exchange_rates::EuroExchangeRates)
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