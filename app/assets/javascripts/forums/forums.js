$(document).ready(function() {
  "use strict";

  /**
   * Prepend the given post title with a RE: if it does not already have one.
   * @param title The title to make into a reply.
   * @returns string
   */
  function replize_title(title) {
    if (/re:/i.test(title)) {
      return title;
    } else {
      return 'RE: ' + title;
    }
  }

  $('.forum .btn.reply').click(function(e) {

    // Set the post we are replying to.
    var post_id = parseInt($(this).data('postId'));
    var post_title = replize_title($(this).data('postTitle'));
    //var $quick_reply = $('.forum .quick-reply');
    var $quick_reply = $(this).closest('.forum').find('.quick-reply');
    $('#forum_post_title', $quick_reply).val(post_title);
    $('#forum_post_parent_id', $quick_reply).val(post_id);

    // Reattach the form beneath the post we are replying to.
    var $post = $(this).closest('.forum').find('div#post-' + post_id);
    $quick_reply.hide();
    $quick_reply.detach();
    $quick_reply.appendTo($('div.contents', $post));
    $quick_reply.slideDown();

    $('html, body').animate({
      scrollTop: $quick_reply.offset().top
    }, 500);

    e.preventDefault();
  });
    var icon_toggle = $('.forum .subscribe-icon');
    icon_toggle.hover(function(){
        $(this).removeClass('icon-ok').addClass('icon-remove');
    });

    icon_toggle.mouseleave(function(){
        $(this).removeClass('icon-remove').addClass('icon-ok');
    });

    $('.forum .subscription').click(function(e){
        e.preventDefault();
        var url = $(this).attr('url');
        var alter = $(this).parent().children($(this).hasClass('subscribe') ? '.unsubscribe' : '.subscribe');
        var self = $(this);

        $.get(url, function(resp){
            alter.removeClass('hidden');
            self.addClass('hidden');
        }, "json");
    });
});
function set_show_hide_discussion() {
    $('div#discussion-wrapper a.a_discussion').click(function () {
        $('div#discussion-wrapper .forum').toggle();
        if ($('div#discussion-wrapper a.a_discussion').text() == "Show Discussion") {
            $('div#discussion-wrapper a.a_discussion').text("Hide Discussion");
        } else {
            $('div#discussion-wrapper a.a_discussion').text("Show Discussion");
        }
    });
}