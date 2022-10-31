module Model

using Dates

export Location, Company, Security, EuroExchangeRates


struct Location
    address::Union{String,Missing}
    city::Union{String,Missing}
    postal_code::Union{String,Missing}
    country::Union{String,Missing}
end


struct Company
    lei::String
    name::String
    location::Union{Location,Missing}
    profile::Union{String,Missing}
    url::Union{String,Missing}
    founded::Union{Int,Missing}
end

Company(lei, name, address, city, postal_code, country) = Company(lei, name, Location(address, city, postal_code, country), missing, missing, missing)
Company(lei, name) = Company(lei, name, missing, missing, missing, missing)


struct Security
    isin::String
    symbol::Union{String,Missing}
    wkn::Union{String,Missing}
    lei::Union{String,Missing}
    name::Union{String,Missing}
    type::Union{String,Missing}
    main::Union{Bool,Missing}
    outstanding::Union{Int,Missing}
end

Security(isin, wkn, lei, name, type) = Security(isin, missing, wkn, lei, name, type, missing, missing)
Security(isin, wkn, name, type) = Security(isin, wkn, missing, name, type)
Security(isin) = Security(isin, missing, missing, missing)

    
struct EuroExchangeRates
    date::Date
    rates::Dict
end

end # module