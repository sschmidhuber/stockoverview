module Service

using ..DBAccess
using ..DataRetrieval
using ..Model
using DataFrames
using DataFramesMeta

export preparesecurities


"""
    preparesecurities()

Returns a DataFrame of security data, prapered to display in frontend.
"""
function preparesecurities()::DataFrame
    securities = getsecurities()
    companies = getcompanies()

    @chain securities begin
        innerjoin(companies, on = :lei, matchmissing=:notequal, makeunique=true)
        @select(:isin, :name, :country, :city)
        rename(:isin => :ISIN, :name => :Name, :country => :Country, :city => :City)
    end
end

end # module