$(function() {
  function update_statuses() {
    $.getJSON("/statuses.json", function(res) {
      var ul = $('<ul/>').appendTo($('#statuses').empty());
      $.each(res, function(n, status) {
        $('<li/>')
          .append($('<span/>').addClass('user').text(status.user))
          .append($('<span/>').addClass('status').text('「' + status.text + '」'))
          .append($('<br/>'))
          .append($('<span/>').addClass('created_at').text(status.created_at))
          .appendTo(ul);
      });
    });
  }

  $('#status').keypress(function(e) {
    var $this = $(this);
    if (e.keyCode !== 13 || !$this.val()) return true;
    $.post('/statuses.json', {'text': $this.val()}, function() {
      update_statuses();
      $this.val('');
    }, "json");
  });

  update_statuses();
});
