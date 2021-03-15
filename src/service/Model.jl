module Model

using Dates

export EuroExchangeRates

    
struct EuroExchangeRates
    date::Date
    rates::Dict
end

end # module