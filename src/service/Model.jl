module Model

using Dates

export Location, Company, EuroExchangeRates


struct Location
    address::String
    city::String
    country::String
    postal_code::String
end


struct Company
    lei::String
    name::String
    location::Location
end

    
struct EuroExchangeRates
    date::Date
    rates::Dict
end

end # module