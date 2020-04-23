$( document ).ready(function() {

  // general ajax settings
  $.ajaxSetup({
    contentType: "application/json"
  })

  // load initial securities table
  $.get('/securities', { "filter": localStorage.getItem("filterId") }, function(res){

    // datatable columns
    columns = []
    res.cols.forEach((title, i) => {
      columns.push({ title: title })
    });

    // init data frame
    var dataframe = $('#dataframe').DataTable( {
        data: res.rows,
        columns: columns,
        dom: '<"toolbar d-inline">ftlp'
    } );

    // align number columns
    columns = [2,3,4,5,6,7,8,13,14,15]
    columns.forEach((col, i) => {
      $(dataframe.column(col).nodes()).attr("style", "text-align: right");
    });

    // column visibility (show / hide)
    $('.toggle-vis').on( 'click', function (e) {
      let column = dataframe.column( $(this).attr('data-column') );
      column.visible( ! column.visible() );

      col = $(this).attr('data-column');
      unselectCols = JSON.parse(localStorage.getItem("unselectCols"))
      if (unselectCols == null) {
        return
      } else if (unselectCols.includes(col)) {
        unselectCols = unselectCols.filter(function(value){ return value != col;});
      } else {
        unselectCols.push(col)
      }
      localStorage.setItem("unselectCols", JSON.stringify(unselectCols))
    });


    let filterTimeout = null;

    // build filter JSON and trigger request
    function createFilter() {
      clearTimeout(filterTimeout);
      filterTimeout = setTimeout(function() {        
        let filter = {}

        let countries = $('#country-filter').val()
        if (countries.length > 0) {
          filter.country = countries
        }

        let positivePer = $('#positive-per').prop('checked')
        if (positivePer) {
          filter.priceEarningsRatio = [0,res.values.priceEarningsRatio[1]]
        }

        let positivePbr = $('#positive-pbr').prop('checked')
        if (positivePbr) {
          filter.priceBookRatio = [0,res.values.priceBookRatio[1]]
        }

        let minRevenue = $( "#slider-revenue" ).slider( "values", 0 )
        let maxRevenue = $( "#slider-revenue" ).slider( "values", 1 )
        if (minRevenue > res.values.revenue[0] || maxRevenue < res.values.revenue[1]) {
          filter.revenue = [minRevenue, maxRevenue]
        }

        let minIncomeNet = $( "#slider-income-net" ).slider( "values", 0 )
        let maxIncomeNet = $( "#slider-income-net" ).slider( "values", 1 )
        if (minIncomeNet > res.values.incomeNet[0] || maxIncomeNet < res.values.incomeNet[1]) {
          filter.incomeNet = [minIncomeNet, maxIncomeNet]
        }
        
        let pPer = $( "#slider-per" ).slider( "value" )
        if (pPer != 100) {
          filter.pPer = Math.abs(pPer) / 100
        }
        
        let pPbr = $( "#slider-pbr" ).slider( "value" )
        if (pPbr != 100) {
          filter.pPbr = Math.abs(pPbr) / 100
        }
        
        let pDrrl = $( "#slider-drrl" ).slider( "value" )
        if (pDrrl != -100) {
          filter.pDrrl = Math.abs(pDrrl) / 100
        }
        
        let pDrr3 = $( "#slider-drr3" ).slider( "value" )
        if (pDrr3 != -100) {
          filter.pDrr3 = Math.abs(pDrr3) / 100
        }
        
        let pDrr5 = $( "#slider-drr5" ).slider( "value" )
        if (pDrr5 != -100) {
          filter.pDrr5 = Math.abs(pDrr5) / 100
        }
        
        if (Object.keys(filter).length != 0) {          
          $.post("/filters", JSON.stringify(filter), function (res) {
            localStorage.setItem("filterId", res.filterId);
            localStorage.setItem("filterOptions", JSON.stringify(filter));
            updateDataFrame(res.filterId);
          });
        }
      }, 2000)
    };

    // price-earnings ratio
    $("#slider-per").slider({
      range: "min",
      value: 100,
      min: 1,
      max: 100,
      slide: function (event, ui) {
        $("#p-per").text(ui.value + "%");
        createFilter();
      }
    });
    $("#p-per").text($("#slider-per").slider("value") + "%");
    $('#positive-per').on('click', createFilter);

    // price-book ratio
    $("#slider-pbr").slider({
      range: "min",
      value: 100,
      min: 1,
      max: 100,
      slide: function (event, ui) {
        $("#p-pbr").text(ui.value + "%");
        createFilter();
      }
    });
    $("#p-pbr").text($("#slider-pbr").slider("value") + "%");
    $('#positive-pbr').on('click', createFilter);

    // didivend-return ratio (last)
    $("#slider-drrl").slider({
      range: "max",
      value: -100,
      min: -100,
      max: -1,
      slide: function (event, ui) {
        $("#p-drrl").text(Math.abs(ui.value) + "%");
        createFilter();
      }
    });
    $("#p-drrl").text(Math.abs($("#slider-drrl").slider("value")) + "%");

    // didivend-return ratio (avg 3)
    $("#slider-drr3").slider({
      range: "max",
      value: -100,
      min: -100,
      max: -1,
      slide: function (event, ui) {
        $("#p-drr3").text(Math.abs(ui.value) + "%");
        createFilter();
      }
    });
    $("#p-drr3").text(Math.abs($("#slider-drr3").slider("value")) + "%");


    // didivend-return ratio (avg 5)
    $("#slider-drr5").slider({
      range: "max",
      value: -100,
      min: -100,
      max: -1,
      slide: function (event, ui) {
        $("#p-drr5").text(Math.abs(ui.value) + "%");
        createFilter();
      }
    });
    $("#p-drr5").text(Math.abs($("#slider-drr5").slider("value")) + "%");

    // revenue
    $("#slider-revenue").slider({
      range: true,
      min: Math.floor(res.values.revenue[0] / 1000000000) * 1000000000,
      max: Math.ceil(res.values.revenue[1] / 1000000000) * 1000000000,
      step: 1000000000,
      values: [Math.floor(res.values.revenue[0] / 1000000000) * 1000000000, Math.ceil(res.values.revenue[1] / 1000000000) * 1000000000],
      slide: function (event, ui) {
        $("#revenue-from").text((ui.values[0]).toLocaleString("en"));
        $("#revenue-to").text((ui.values[1]).toLocaleString("en"));
        if (ui.values[0] < 0 && $('#positive-revenue').prop('checked')) {
          $('#positive-revenue').prop('checked', false)
        }
        createFilter();
      }
    });
    $("#revenue-from").text($("#slider-revenue").slider("values", 0).toLocaleString("en"));
    $("#revenue-to").text($("#slider-revenue").slider("values", 1).toLocaleString("en"));

    $('#positive-revenue').on('click', function() {
      checked = $(this).prop('checked')
      if (checked) {
        if ($( "#slider-revenue" ).slider("values", 0) < 0 ) {
          $( "#revenue-from" ).text( "0" )
          $( "#slider-revenue" ).slider("values", 0, 0)
        }
        if ($( "#slider-revenue" ).slider("values", 1) < 0 ) {
          $( "#revenue-to" ).text( "0" )
          $( "#slider-revenue" ).slider("values", 1, 0)
        }
      }      
      createFilter();
    });

    // net income
    $("#slider-income-net").slider({
      range: true,
      min: Math.floor(res.values.incomeNet[0] / 1000000000) * 1000000000,
      max: Math.ceil(res.values.incomeNet[1] / 1000000000) * 1000000000,
      step: 1000000000,
      values: [Math.floor(res.values.incomeNet[0] / 1000000000 * 1000000000), Math.ceil(res.values.incomeNet[1] / 1000000000) * 1000000000],
      slide: function (event, ui) {
        $("#income-net-from").text((ui.values[0]).toLocaleString("en"));
        $("#income-net-to").text((ui.values[1]).toLocaleString("en"));
        if (ui.values[0] < 0 && $('#positive-income-net').prop('checked')) {
          $('#positive-income-net').prop('checked', false)
        }
        createFilter();
      }
    });
    $("#income-net-from").text($("#slider-income-net").slider("values", 0).toLocaleString("en"));
    $("#income-net-to").text($("#slider-income-net").slider("values", 1).toLocaleString("en"));

    $('#positive-income-net').on('click', function() {
      checked = $(this).prop('checked')
      if (checked) {
        
        if ($( "#slider-income-net" ).slider("values", 0) < 0 ) {
          $( "#income-net-from" ).text( "0" )
          $( "#slider-income-net" ).slider("values", 0, 0)
        }
        if ($( "#slider-income-net" ).slider("values", 1) < 0 ) {
          $( "#income-net-to" ).text( "0" )
          $( "#slider-income-net" ).slider("values", 1, 0)
        }
      }      
      createFilter();
    });

    // country filter
    res.values.country.forEach((country, i) => {
      $('#country-filter').append("<option>" + country + "</option>")
    });
    $('#country-filter').selectpicker({ size: "10" });
    $('#country-filter').selectpicker('refresh');
    $('#country-filter').on('change', createFilter);

    // column selection
    unselectCols = JSON.parse(localStorage.getItem("unselectCols"));
    if (unselectCols == null) {
      unselectCols = [5,6,11,12,14] // set default if nothing is found in local storage
      localStorage.setItem("unselectCols", JSON.stringify(unselectCols));
    }
    unselectCols.forEach((col,i) => {
      let column = dataframe.column(col)
      column.visible( ! column.visible() )      
      $('#toggle-col-' + col).removeAttr("checked")
    });

    // change visability
    $('#spinner').addClass('invisible')
    $(':input').addClass('form-control')
    $('#dataframe').addClass('table table-striped table-bordered')
    $('#dataframe').removeClass('invisible')
    $('#toolbar').removeClass('invisible')

    // display time since last data update
    sessionStorage.setItem("interval", res.metadata.interval)
    sessionStorage.setItem("lastupdate", Date.parse(res.metadata.lastupdate))

    displayTime()
    setInterval(displayTime, 10000);

    // align filter widgets with used filter options
    if (res.metadata.filtered) {
      setFilterWidgets();
    }
  });

  // navigation
  $('.nav-link').on('click', function(){
    $('.top-level').hide()
    old = $('.nav-link.text-white')
    old.addClass('text-muted')
    old.removeClass('text-white')
    $(this).removeClass('text-muted')
    $(this).addClass('text-white')
    target = $(this).attr('target')
    $(target).show()
  });

  function displayTime() {
    let time_string;
    let lastupdate = parseInt(sessionStorage.getItem("lastupdate"))
    let interval = parseInt(sessionStorage.getItem("interval"))
    let now = Date.now()

    time = Math.round((now - lastupdate) / 1000 / 60)    
    hours = Math.floor(time / 60)
    minutes = time % 60

    if (hours == 0) {
      time_string = minutes + " min"
    } else {
      time_string = hours + " h " + minutes + " min"
    }
    $('div.toolbar').html("last data update: <code>" + time_string + "</code>")

    if (now > lastupdate + interval * 1000 + 60 * 1000 && !Boolean(sessionStorage.getItem("reload"))) {
      $.get("/securities/metadata", function (res) {
        if (Date.parse(res.lastupdate) > lastupdate) {          
          $("#reload").removeClass("invisible")
          sessionStorage.setItem("reload", "true")
        }
      });
    }
  }

  // set filter widgets accorind to stored filter options
  function setFilterWidgets() {
    filter = JSON.parse(localStorage.getItem("filterOptions"));    
    keys = Object.keys(filter);    

    if (keys.includes("country")) {
      $("#country-filter").val(filter.country)
      $("#country-filter").selectpicker("refresh")
    }

    if (keys.includes("priceEarningsRatio")) {
      if (filter.priceEarningsRatio[0] >= 0) {
        $("#positive-per").prop("checked", true);
      } else {
        $("#positive-per").prop("checked", false);
      }
    }

    if (keys.includes("priceBookRatio")) {
      if (filter.priceBookRatio[0] >= 0) {
        $("#positive-pbr").prop("checked", true);
      } else {
        $("#positive-pbr").prop("checked", false);
      }
    }

    if (keys.includes("pPer")) {
      $("#slider-per").slider("value", filter.pPer * 100);
      $("#p-per").text(filter.pPer * 100 + "%")
    }

    if (keys.includes("pPbr")) {
      $("#slider-pbr").slider("value", filter.pPbr * 100);
      $("#p-pbr").text(filter.pPbr * 100 + "%")
    }

    if (keys.includes("pDrrl")) {
      $("#slider-drrl").slider("value", -filter.pDrrl * 100);
      $("#p-drrl").text(filter.pDrrl * 100 + "%")
    }

    if (keys.includes("pDrr3")) {
      $("#slider-drr3").slider("value", -filter.pDrr3 * 100);
      $("#p-drr3").text(filter.pDrr3 * 100 + "%")
    }

    if (keys.includes("pDrr5")) {
      $("#slider-drr5").slider("value", -filter.pDrr5 * 100);
      $("#p-drr5").text(filter.pDrr5 * 100 + "%")
    }

    if (keys.includes("revenue")) {
      if (filter.revenue[0] >= 0) {
        $("#positive-revenue").prop("checked", true);
      } else {
        $("#positive-revenue").prop("checked", false);
      }
      $("#slider-revenue").slider("values", filter.revenue);
      $("#revenue-from").text(filter.revenue[0].toLocaleString("en"));
      $("#revenue-to").text(filter.revenue[1].toLocaleString("en"));
    }

    if (keys.includes("incomeNet")) {
      if (filter.incomeNet[0] >= 0) {
        $("#positive-income-net").prop("checked", true);
      } else {
        $("#positive-income-net").prop("checked", false);
      }
      $("#slider-income-net").slider("values", filter.incomeNet);
      $("#income-net-from").text(filter.incomeNet[0].toLocaleString("en"));
      $("#income-net-to").text(filter.incomeNet[1].toLocaleString("en"));
    }
  }

  // update data
  function updateDataFrame(filter = null) {
    if (filter === null) {
      $.get('/securities', updateRows);
    } else {
      $.get('/securities', { "filter": filter }, updateRows);
    }

    function updateRows(res) {
      dataFrame = $('#dataframe').DataTable();
      dataFrame.clear();
      dataFrame.rows.add(res.rows).draw()

      if (Boolean(sessionStorage.getItem("reload")) && sessionStorage.getItem("lastupdate") < Date.parse(res.metadata.lastupdate)) {
        sessionStorage.removeItem("reload")
        $("#reload").addClass("invisible")
        sessionStorage.setItem("lastupdate", Date.parse(res.metadata.lastupdate))
        displayTime()
      } else {
        sessionStorage.setItem("lastupdate", Date.parse(res.metadata.lastupdate))
      }            
    }
  }

  $("#reload").on("click", function (event) {
    event.preventDefault();
    console.log("reload");
    
    updateDataFrame(localStorage.getItem("filterId"))
  });

});
