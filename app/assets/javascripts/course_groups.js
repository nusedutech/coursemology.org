$(document).ready(function(){
    var std_in_grp = Array.prototype.map.call($('#dg-std-table').find('a'),function(x) {
        return x.id});
    var btn_remove_std = $('#mng-del-std-btn');
    var btn_add_std = $('#mng-add-std-btn');
    var selected_std;
    var assigned_std;
    if($('#assigned-std').size() > 0) {
        assigned_std  = $('#assigned-std').val().replace('[','').replace(']','').split(', ');
    }

    shouldEnableRemove();
    btn_add_std.click(function(evt) {
//        evt.preventDefault();
        if(assigned_std.indexOf(selected_std) >= 0) {
            confirm("That student has already been assigned to a tutor! Are you sure you want to add him/her? \n\nTHIS WON'T REMOVE HIM/HER FROM THE CURRENT TUTOR.");
        }
    });
//    btn_remove_std.click(function(evt){
//        btn_remove_std.attr("disabled",true);
//    });
    $(document).on('change','#attempting-add-student',function(e){
        shouldEnableRemove();
    });

    function shouldEnableRemove() {
        selected_std = $('#attempting-add-student').val();
        if (std_in_grp.indexOf(selected_std) < 0) {
            if (!btn_remove_std.hasClass("disabled")) {
//                btn_remove_std.addClass("disabled");
                btn_remove_std.attr("disabled",true);
            }
            btn_add_std.attr("disabled",false);
        } else {
            btn_remove_std.attr("disabled",false);
//            btn_remove_std.removeClass("disabled");
            if (!btn_add_std.hasClass("disabled")) {
                btn_add_std.attr("disabled",true);
            }
        }
    }

    $('.update-group').on('click',function(e) {
        e.preventDefault();
        var url = $(this).attr('href');
        var group_row = $(this).parents('tr');
        var old_name = group_row.find('.old-name').val().trim();
        var change_name = group_row.find('.change-name').val().trim();
        var tutor = group_row.find('.tutor');
        var notice = $('.alert');
        if(change_name.length == 0) {
            notice.addClass("alert-error");
            notice.text("User name can't be empty!");
            notice.slideDown();
            notice._removeClass('hidden');
            notice.slideDown(function(){
                setTimeout(function(){
                    notice.slideUp()
                },4400);
            });
            group_row.find('.change-name').val(old_name);
            return;
        }
        $.ajax({
            url: url,
            type: 'POST',
            dataType: 'json',
            data: {
                old_name: old_name,
                change_name: change_name,
                tutor: tutor.val() },
            success: function(e) {
                notice.addClass("alert-success");
                notice.removeClass("alert-error");
                notice.text("Update group successful!");
                notice.slideDown();
                notice._removeClass('hidden');
                notice.slideDown(function(){
                    setTimeout(function(){
                        notice.slideUp()
                    },1500);
                });
            }
        });
        return false;
    });
});