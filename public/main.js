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

    // create filter columns
    res.cols.forEach((title,i) => {
      $('#filter-options').append('<div class="form-check ml-2 mr-2"><input id="toggle-col-' + i + '" type="checkbox" class="form-check-input toggle-vis" data-column="' + i + '" checked><label for="toggle-col-' + i + '" class="form-check-label">' + title + '</label></div>')
    });

    // filter logic
    $('.toggle-vis').on( 'click', function (e) {
      // Get the column API object
      let column = dataframe.column( $(this).attr('data-column') );
      // Toggle the visibility
      column.visible( ! column.visible() );
    } );

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
  });

  // display time since last data update
  $.get('/securities/metadata', function(res){
    interval = res.interval
    lastupdate = Date.parse(res.lastupdate)

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
