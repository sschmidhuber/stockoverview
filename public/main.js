$( document ).ready(function() {
  console.log('ready');
  $.get('/datatable', function(data){
    $('#spinner').css('visibility','hidden');
    $('#stockdata').html(data);
    $('#dataframe').DataTable();
  });

  $('.nav-link').on('click', function(){
    console.log("navigation")
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
