module DataIngestion

using HTTP
using LightXML
using DataFrames
using Dates
using ..Model
    
function fetchexchangerates()
    rates = Dict{String,Float64}()
    res = HTTP.request("GET","https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml")
    xml = res.body |> String |> LightXML.parse_string
    cube = find_element(root(xml), "Cube") |> child_elements |> first
    date = parse(Date, attribute(cube, "time"; required=true))
    foreach(child_elements(cube)) do currency
        push!(rates, attribute(currency, "currency"; required=true) => parse(Float64, attribute(currency, "rate"; required=true)))
    end

    return EuroExchangeRates(date, rates)
end

end # module