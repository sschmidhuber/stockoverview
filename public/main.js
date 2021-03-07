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
    alignColumns(dataframe, [2,3,4,5,6,7,8,11,12], "text-align: right");

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

        let industries = $('#industry-filter').val()
        if (industries.length > 0) {
          filter.industry = industries
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

        let minResultOfOperations = $( "#slider-result-of-operations" ).slider( "values", 0 )
        let maxResultOfOperations = $( "#slider-result-of-operations" ).slider( "values", 1 )
        if (minResultOfOperations > res.values.resultOfOperations[0] || maxResultOfOperations < res.values.resultOfOperations[1]) {
          filter.resultOfOperations = [minResultOfOperations, maxResultOfOperations]
        }

        let minIncomeAfterTax = $( "#slider-income-after-tax" ).slider( "values", 0 )
        let maxIncomeAfterTax = $( "#slider-income-after-tax" ).slider( "values", 1 )
        if (minIncomeAfterTax > res.values.incomeAfterTax[0] || maxIncomeAfterTax < res.values.incomeAfterTax[1]) {
          filter.incomeAfterTax = [minIncomeAfterTax, maxIncomeAfterTax]
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
        
        if (Object.keys(filter).length != 0) {          
          $.post("/filters", JSON.stringify(filter), function (res) {
            localStorage.setItem("filterId", res.filterId);
            localStorage.setItem("filterOptions", JSON.stringify(filter));
            updatedataframe(res.filterId);
          });
        }
        updatedataframe();
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


    // result of operations
    $("#slider-result-of-operations").slider({
      range: true,
      min: Math.floor(res.values.resultOfOperations[0] / 1000000000) * 1000000000,
      max: Math.ceil(res.values.resultOfOperations[1] / 1000000000) * 1000000000,
      step: 1000000000,
      values: [Math.floor(res.values.resultOfOperations[0] / 1000000000) * 1000000000, Math.ceil(res.values.resultOfOperations[1] / 1000000000) * 1000000000],
      slide: function (event, ui) {
        $("#result-of-operations-from").text((ui.values[0]).toLocaleString("en"));
        $("#result-of-operations-to").text((ui.values[1]).toLocaleString("en"));
        if (ui.values[0] < 0 && $('#positive-result-of-operations').prop('checked')) {
          $('#positive-result-of-operations').prop('checked', false)
        }
        createFilter();
      }
    });
    $("#result-of-operations-from").text($("#slider-result-of-operations").slider("values", 0).toLocaleString("en"));
    $("#result-of-operations-to").text($("#slider-result-of-operations").slider("values", 1).toLocaleString("en"));

    $('#positive-result-of-operations').on('click', function() {
      checked = $(this).prop('checked')
      if (checked) {
        
        if ($( "#slider-result-of-operations" ).slider("values", 0) < 0 ) {
          $( "#result-of-operations-from" ).text( "0" )
          $( "#slider-result-of-operations" ).slider("values", 0, 0)
        }
        if ($( "#slider-result-of-operations" ).slider("values", 1) < 0 ) {
          $( "#result-of-operations-to" ).text( "0" )
          $( "#slider-result-of-operations" ).slider("values", 1, 0)
        }
      }      
      createFilter();
    });

    // income after tax
    $("#slider-income-after-tax").slider({
      range: true,
      min: Math.floor(res.values.incomeAfterTax[0] / 1000000000) * 1000000000,
      max: Math.ceil(res.values.incomeAfterTax[1] / 1000000000) * 1000000000,
      step: 1000000000,
      values: [Math.floor(res.values.incomeAfterTax[0] / 1000000000) * 1000000000, Math.ceil(res.values.incomeAfterTax[1] / 1000000000) * 1000000000],
      slide: function (event, ui) {
        $("#income-after-tax-from").text((ui.values[0]).toLocaleString("en"));
        $("#income-after-tax-to").text((ui.values[1]).toLocaleString("en"));
        if (ui.values[0] < 0 && $('#positive-income-after-tax').prop('checked')) {
          $('#positive-income-after-tax').prop('checked', false)
        }
        createFilter();
      }
    });
    $("#income-after-tax-from").text($("#slider-income-after-tax").slider("values", 0).toLocaleString("en"));
    $("#income-after-tax-to").text($("#slider-income-after-tax").slider("values", 1).toLocaleString("en"));

    $('#positive-income-after-tax').on('click', function() {
      checked = $(this).prop('checked')
      if (checked) {
        
        if ($( "#slider-income-after-tax" ).slider("values", 0) < 0 ) {
          $( "#income-after-tax-from" ).text( "0" )
          $( "#slider-income-after-tax" ).slider("values", 0, 0)
        }
        if ($( "#slider-income-after-tax" ).slider("values", 1) < 0 ) {
          $( "#income-after-tax-to" ).text( "0" )
          $( "#slider-income-after-tax" ).slider("values", 1, 0)
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

    // industry filter
    res.values.industry.forEach((industry, i) => {
      $('#industry-filter').append("<option>" + industry + "</option>")
    });
    $('#industry-filter').selectpicker({ size: "10" });
    $('#industry-filter').selectpicker('refresh');
    $('#industry-filter').on('change', createFilter);

    // column selection
    unselectCols = JSON.parse(localStorage.getItem("unselectCols"));
    if (unselectCols == null) {
      unselectCols = [1,5,12] // set default if nothing is found in local storage
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

    if (keys.includes("resultOfOperations")) {
      if (filter.resultOfOperations[0] >= 0) {
        $("#positive-result-of-operations").prop("checked", true);
      } else {
        $("#positive-result-of-operations").prop("checked", false);
      }
      $("#slider-result-of-operations").slider("values", filter.resultOfOperations);
      $("#result-of-operations-from").text(filter.resultOfOperations[0].toLocaleString("en"));
      $("#result-of-operations-to").text(filter.resultOfOperations[1].toLocaleString("en"));
    }

    if (keys.includes("incomeAfterTax")) {
      if (filter.incomeAfterTax[0] >= 0) {
        $("#positive-income-after-tax").prop("checked", true);
      } else {
        $("#positive-income-after-tax").prop("checked", false);
      }
      $("#slider-income-after-tax").slider("values", filter.incomeAfterTax);
      $("#income-after-tax-from").text(filter.incomeAfterTax[0].toLocaleString("en"));
      $("#income-after-tax-to").text(filter.incomeAfterTax[1].toLocaleString("en"));
    }
  }

  // update data
  function updatedataframe(filter = null) {
    if (filter === null) {
      $.get('/securities', updateRows);
    } else {
      $.get('/securities', { "filter": filter }, updateRows);
    }

    function updateRows(res) {
      dataframe = $('#dataframe').DataTable();
      dataframe.clear();
      dataframe.rows.add(res.rows)
      alignColumns(dataframe, [2,3,4,5,6,7,8,11,12], "text-align: right");
      dataframe.draw()

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

  // align table columns
  function alignColumns(dataframe, columns, alignment) {
    columns.forEach((col, i) => {
      $(dataframe.column(col).nodes()).attr("style", alignment);
    });
  }

  $("#reload").on("click", function (event) {
    event.preventDefault();    
    updatedataframe(localStorage.getItem("filterId"))
  });

});
