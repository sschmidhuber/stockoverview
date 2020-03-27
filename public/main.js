$( document ).ready(function() {

  // load initial securities table
  $.get('/securities', function(res){

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
    } );

    // price-earnings ratio
    $( function() {
      $( "#slider-per" ).slider({
        range: "min",
        value: 100,
        min: 1,
        max: 100,
        slide: function( event, ui ) {
          $( "#p-per" ).text( ui.value + "%" );
        }
      });
      $( "#p-per" ).text( $( "#slider-per" ).slider( "value" ) + "%" );
    } );

    // price-book ratio
    $( function() {
      $( "#slider-pbr" ).slider({
        range: "min",
        value: 100,
        min: 1,
        max: 100,
        slide: function( event, ui ) {
          $( "#p-pbr" ).text( ui.value + "%" );
        }
      });
      $( "#p-pbr" ).text( $( "#slider-pbr" ).slider( "value" ) + "%" );
    } );

    // didivend-return ratio (last)
    $( function() {
      $( "#slider-drrl" ).slider({
        range: "max",
        value: -100,
        min: -100,
        max: 1,
        slide: function( event, ui ) {
          $( "#p-drrl" ).text( Math.abs(ui.value) + "%" );
        }
      });
      $( "#p-drrl" ).text( Math.abs($( "#slider-drrl" ).slider( "value" )) + "%" );
    } );

    // didivend-return ratio (avg 3)
    $( function() {
      $( "#slider-drr3" ).slider({
        range: "max",
        value: -100,
        min: -100,
        max: 1,
        slide: function( event, ui ) {
          $( "#p-drr3" ).text( Math.abs(ui.value) + "%" );
        }
      });
      $( "#p-drr3" ).text( Math.abs($( "#slider-drr3" ).slider( "value" )) + "%" );
    } );

    // didivend-return ratio (avg 5)
    $( function() {
      $( "#slider-drr5" ).slider({
        range: "max",
        value: -100,
        min: -100,
        max: 1,
        slide: function( event, ui ) {
          $( "#p-drr5" ).text( Math.abs(ui.value) + "%" );
        }
      });
      $( "#p-drr5" ).text( Math.abs($( "#slider-drr5" ).slider( "value" )) + "%" );
    } );

    // revenue
    $( function() {
      $( "#slider-revenue" ).slider({
        range: true,
        min: Math.floor(res.values.revenue[0] / 1000000000) * 1000000000,
        max: Math.ceil(res.values.revenue[1] / 1000000000) * 1000000000,
        step: 1000000000,
        values: [Math.floor(res.values.revenue[0] / 1000000000) * 1000000000, Math.ceil(res.values.revenue[1] / 1000000000) * 1000000000],
        slide: function( event, ui ) {
          $( "#revenue-from" ).text( (ui.values[0]).toLocaleString("en") );
          $( "#revenue-to" ).text( (ui.values[1]).toLocaleString("en") );
        }
      });
      $( "#revenue-from" ).text( $( "#slider-revenue" ).slider( "values", 0 ).toLocaleString("en") );
      $( "#revenue-to" ).text( $( "#slider-revenue" ).slider( "values", 1 ).toLocaleString("en") );
    } );

    // net income
    $( function() {
      $( "#slider-net-income" ).slider({
        range: true,
        min: Math.floor(res.values.incomeNet[0] / 1000000000) * 1000000000,
        max: Math.ceil(res.values.incomeNet[1] / 1000000000) * 1000000000,
        step: 1000000000,
        values: [Math.floor(res.values.incomeNet[0] / 1000000000 * 1000000000), Math.ceil(res.values.incomeNet[1] / 1000000000) * 1000000000],
        slide: function( event, ui ) {
          $( "#net-income-from" ).text( (ui.values[0]).toLocaleString("en") );
          $( "#net-income-to" ).text( (ui.values[1]).toLocaleString("en") );
        }
      });
      $( "#net-income-from" ).text( $( "#slider-net-income" ).slider( "values", 0 ).toLocaleString("en") );
      $( "#net-income-to" ).text( $( "#slider-net-income" ).slider( "values", 1 ).toLocaleString("en") );
    } );

    // country filter
    res.values.country.forEach((country, i) => {
      $('#country-filter').append("<option>" + country + "</option>")
    });
    $('#country-filter').selectpicker({ size: "10" });
    $('#country-filter').selectpicker('refresh');

    // set default column selection
    unselectCols = [5,6,11,12,14]
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
    $('#filter').removeClass('invisible')

    // display time since last data update
    interval = res.metadata.interval
    lastupdate = Date.parse(res.metadata.lastupdate)

    function displayTime() {
      let time_string;
      time = Math.round((Date.now() - lastupdate) / 1000 / 60)
      hours = Math.floor(time / 60)
      minutes = time % 60
      if (hours == 0) {
        time_string = minutes + " min"
      } else {
        time_string = hours + " h " + minutes + " min"
      }
      $('div.toolbar').html("last data update: <code>" + time_string + "</code>")
    }

    displayTime()
    setInterval(displayTime, 10000);
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
  })
});
