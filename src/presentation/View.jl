module View

using Dash

#=
* introduce a DEV mode to start or don't start the scheduler
=#

app = dash(update_title = "Stock Overview")

app.layout = html_div() do
    html_header([
        html_h1("Stock Overview"),
        html_p("About (not implemented, yet)")
    ]),
    html_div([
        html_div([
            html_label("Search"),
            dcc_input(value="", type="text"),
            html_label("Columns"),
            dcc_dropdown(options=[Dict("label"=>"ISIN", "value"=>"isin"), Dict("label"=>"Name", "value"=>"name")], multi=true),
            html_label("Countries"),
            dcc_dropdown(options=[Dict("label"=>"Germany", "value"=>"de"), Dict("label"=>"United Kingdom", "value"=>"uk")], multi=true)
        ]),
        html_label("Price-earnings-ratio"),
        dcc_rangeslider(min=0, max=100),
        dash_datatable(id="table-stockoverview")
    ])
end

#=callback!(app, Output("my-div", "children"), Input("my-id", "value")) do input_value
    "You've entered: \"$(input_value)\""
end=#

run_server(app, "127.0.0.1", 8000; debug=true)

end # module