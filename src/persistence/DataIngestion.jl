module DataIngestion

using Dates
using Downloads
using HTTP
using JSON

export execute_datapipeline


"""
    execute_datapipeline()

Run the data pipeline from raw to prepared layer.
"""
function execute_datapipeline()
    download_raw_data()
end


"""
    download_raw_data()

Download and store raw company and ISIN data from data providers to raw layer.

Already existing files will be overwritten.
"""
function download_raw_data()
    @info "download raw data"
    ingest_date = today()
    working_date = Dates.format(today() - Day(1), DateFormat("yyyymmdd"))
    lei_url = "https://leidata.gleif.org/api/v1/concatenated-files/lei2/$working_date/zip"

    # retrieve ISIN-LEI mapping URL
    isin_mapping_url = nothing
    try
        res = HTTP.request("GET", "https://isinmapping.gleif.org/api/v2/isin-lei")
        source = JSON.parse(res.body |> String, null=missing)
        isin_mapping_url = source["data"][1]["attributes"]["downloadLink"]
    catch e
        showerror(stderr, e)
        println("failed to retrieve \"isin_mapping_url\"")
        exit(1)
    end

    # download raw files
    LEI_zip = nothing
    try
        LEI_zip = Downloads.download(lei_url)
    catch e
        showerror(stderr, e)
        println("failed to download LEI file")
        exit(1)
    end

    ISIN_mapping_zip = nothing
    try
        ISIN_mapping_zip = Downloads.download(isin_mapping_url)
    catch e
        showerror(stderr, e)
        println("failed to download ISIN mapping file")
        exit(1)
    end

    # copy temporary files to raw layer
    mkpath("../data/raw/$ingest_date")
    mv(LEI_zip, "../data/raw/$ingest_date/company_data.zip"; force=true)
    mv(ISIN_mapping_zip, "../data/raw/$ingest_date/ISIN_mapping.zip"; force=true)
end

end # module