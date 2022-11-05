module Service

using ..DBAccess
using ..DataRetrieval
using ..Model
using Query
using DataFrames

export preparesecurities


"""
    preparesecurities()

Returns a DataFrame of security data, prapered to display in frontend.
"""
function preparesecurities()::DataFrame
    securities = getsecurities()
    companies = getcompanies()

    securities |>
        @join(companies, _.lei, _.lei, {_.isin, _.name, __.country, __.city}) |>
        @rename(:isin => :ISIN, :name => :Name, :country => :Country, :city => :City) |>
        DataFrame
end

end # module