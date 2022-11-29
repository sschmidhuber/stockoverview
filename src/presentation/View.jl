module View

using ..Service
using Stipple
using StippleUI


@reactive mutable struct SecurityView <: ReactiveModel
    data::R{DataTable} = DataTable(preparesecurities())
    data_pagination::DataTablePagination = DataTablePagination(rows_per_page=10)
  end
  
  function ui(model)
    page( model, title="Stock Overview NEXT", class="container", [
      row(
        heading("Stock Overview")
      )
      row(
        cell(
          table(title="Securities", :data, pagination=:data_pagination)
        )
      )
      ]
    )
  end
  
  route("/") do
    model = SecurityView |> init
    html(ui(model), context = @__MODULE__)
  end

  #up()

end # module