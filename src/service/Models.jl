module Models

using Dates

export Location, Company, Security, EuroExchangeRates


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


struct Security
    isin::String
    symbol::Union{String,Missing}
    wkn::Union{String,Missing}
    lei::Union{String,Missing}
    name::Union{String,Missing}
    type::Union{String, Missing}
end

Security(isin, wkn, name, type) = Security(isin, missing, wkn, missing, name, type)
Security(isin) = Security(isin, missing, missing, missing)

    
struct EuroExchangeRates
    date::Date
    rates::Dict
end

end # module