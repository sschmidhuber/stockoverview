$( document ).ready(function() {

  // load initial securities table
  $.get('/securities', function(res){
    columns = []
    res.cols.forEach((title, i) => {
      columns.push({ title: title })
    });

    $('#dataframe').DataTable( {
        data: res.rows,
        columns: columns
    } );
    //$('#stockdata').html(res)
    //$('#dataframe').DataTable()
    $('#spinner').addClass('invisible')
    $('#dataframe').removeClass('invisible')
    $('#metadata').removeClass('invisible')
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
      $('#lastupdate').text(time_string)
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
