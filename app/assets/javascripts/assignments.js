$(document).ready(function() {
    function load_json_data() {
        var summary = JSON.parse($('.json-data').val());

        if (summary.selected_tags) {
            var tags = summary.selected_tags;
            for (var i in tags) {
                $("input[value='" + tags[i] + "']").attr('checked', true);
            }
        }

        if (summary.actions) {
            var actions_map = summary.actions;
            var new_icon = '<img class="asm-new-icon" src="http://c.dryicons.com/images/icon_sets/colorful_stickers_part_3_icons_set/png/48x48/promotion_new.png"/>';
            var not_published_icon = '<i class="icon-ban-circle" rel="tooltip" title="Not Published"></i>';
            for (var mid in actions_map) {
                var $div = $("#"+mid);
                if ($div.length > 0 && actions_map[mid].action) {
                    var klass = "";
                    switch (actions_map[mid].action) {
                        case 'Review':
                            klass = 'btn-info';
                            break;
                        case 'Attempt':
                            klass = 'btn-success';
                            break;
                        case 'realtime_session':
                            klass = 'btn-success';
                            break;
                    }
                    if(actions_map[mid].action == 'realtime_session'){
                        $div.html("");
                        $div.parent().css("width","15%");
                        if(actions_map[mid].warning == null) {
                            if (actions_map[mid]['training'].action == 'Notstart' || actions_map[mid]['training'].action == 'Null') {
                                $div.html('<a disabled="true" class="btn-rt btn ' + klass + '" >' + actions_map[mid]['training'].flash + '</a>')
                            } else {
                                $div.html('<a href="' + actions_map[mid]['training'].url + '" class="btn-rt btn ' + ((actions_map[mid]['training'].action == 'Review') ? 'btn-info' : klass) + '" >' + actions_map[mid]['training'].flash + '</a>')
                            }
                            if (actions_map[mid]['mission'].action == 'Notstart' || actions_map[mid]['mission'].action == 'Null') {
                                $div.append('<a disabled="true" class="lower-btn-rt btn ' + klass + '" >' + actions_map[mid]['mission'].flash + '</a>')
                            } else {
                                $div.append('<a href="' + actions_map[mid]['mission'].url + '" class="lower-btn-rt btn ' + ((actions_map[mid]['mission'].action == 'Review') ? 'btn-info' : klass) + '" >' + actions_map[mid]['mission'].flash + '</a>')
                            }
                        }else if(actions_map[mid].warning == "Absent") {
                            if(typeof(actions_map[mid]['training']) != "undefined" && actions_map[mid]['training'].action == "Review") {
                                $div.html('<a href="' + actions_map[mid]['training'].url + '" class="btn-rt btn ' + ((actions_map[mid]['training'].action == 'Review') ? 'btn-info' : klass) + '" >' + actions_map[mid]['training'].flash + '</a>')
                            }
                        }
                    }else {
                        $div.html('<a href="' + actions_map[mid].url + '" class="btn ' + klass + '" >' + actions_map[mid].action + '</a>')
                    }
                }
                
                var $divSecondary = $("#"+mid+"-secondary");
                if ($divSecondary.length > 0 && actions_map[mid].actionSecondary) {
                    var klass = "";
                    switch (actions_map[mid].actionSecondary) {
                        case 'Reattempt':
                            klass = 'btn-success';
                            break;
                    }
                    $divSecondary.html('<a href="' + actions_map[mid].urlSecondary + '" class="btn ' + klass + '" >' + actions_map[mid].actionSecondary + '</a>')
                }

                var $divTertiary = $("#"+mid+"-tertiary");
                if ($divTertiary.length > 0 && actions_map[mid].actionTertiary) {
                    $divTertiary.html('<a href="' + actions_map[mid].urlTertiary + '" class="btn" >' + actions_map[mid].actionTertiary + '</a>')
                }

                var $title = $("#title-"+mid);
                if ($title.length > 0) {
                    var to_add = "";
                    if (actions_map[mid].new) to_add = new_icon;
                    if (!actions_map[mid].published) to_add += not_published_icon;
                    $title.html(to_add + $title.html());
                }


                var $title_link = $("#link-"+mid);
                if ($title_link.length > 0) {
                    if (actions_map[mid].action) {
                        $title_link.attr('href', actions_map[mid].title_link);
                    } else {
                        $title_link.parent().html($title_link.html());
                    }
                }
                var $row = $("#row-"+mid);
                if ($row.length > 0) {
                    !actions_map[mid].opened ? $row.addClass('future') : 1;
                }
            }
            $('*[rel~=tooltip]').tooltip();
        }
        console.log(summary);
    }

    if ($('.json-data').length > 0) {
        try {
            load_json_data();
        } catch (e){
            console.log(e);
        }
    }
});
