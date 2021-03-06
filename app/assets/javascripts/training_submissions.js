$(document).ready(function(){

    //initiate event for discussion
    set_show_hide_discussion();

    $('#submit-btn, #test-next-btn').click(function(evt){
        $(this).addClass('disabled');
        var form = $("#training-step-form");
        var update_url = form.children("input[name=update_url]").val();
        var qid = form.children("input[name=qid]").val();
        var checkboxes = form.find("input.choices");
        var choices = [];
        var aids = [];
        var step = form.children("input[name=step]").val();
        var btn_id = $(this).attr('id');
        var sq_id = $('#session_question_id').val();
        var submission_id = $('#submission_id').val();

        $.each(checkboxes, function(i, cb) {
            choices.push($(cb).val());
            if ($(cb).is(":checked")) {
                aids.push($(cb).val());
            }
        });

        if (aids.length > 0) {
            var data = {
                'step':step,
                'qid': qid,
                'aid': aids,
                'choices': choices,
                'sq_id' : sq_id,
                'sid' :submission_id
            };
            // send ajax request to get result
            // update result form
            // change submit to continue if the answer is correct
            $.get(update_url, data, function(resp) {
                //#new code for normal training
                $('#submit-btn, #test-next-btn').removeClass('disabled');

                $('#explanation .result').html(resp.result);
                $('#explanation .reason').html(resp.explanation);
                $('#explanation').removeClass('hidden');
                $('#explanation').removeClass('mcq-ans-incorrect');
                $('#explanation').removeClass('mcq-ans-correct');

                var el = document.getElementById("explanation");
                MathJax.Hub.Queue(["Typeset", MathJax.Hub, el]);

                if (resp.is_test || resp.is_correct) {
                    $('#continue-btn').removeClass('disabled');
                    $('#continue-btn').addClass('btn-primary');
                    $('#submit-btn').removeClass('btn-primary');
                    //$('#submit-btn').addClass('disabled');
                    //$('#submit-btn').attr("disabled", true);
                    if (resp.is_test || resp.realtime){
                        $('#explanation').removeClass('alert-info');
                        $('#explanation').addClass('alert-info',500);
                    }else {
                        $('#explanation').addClass('mcq-ans-correct');
                    }

                    //run reunlock-next-unlock ajax( this function is in training_submissions\_edit_from.html.erb
                    /*
                    var reunlock_session_interval = null;
                    if($('#reattempt_next_ajax_url').length){
                        var reattempt_next_url = $('#reattempt_next_ajax_url').val();
                        reunlock_session_interval = setInterval(function(){
                            $.ajax({
                                url : reattempt_next_url,
                                type : 'POST',
                                dataType : 'json',
                                async : false,
                                data : {session_question_id: sq_id, count: resp.count},
                                success : function(result) {
                                    if(result.result == true){
                                        $('#explanation .result').html(resp.result);
                                        $('#explanation .reason').html("Question is reunlocked, re-answer if you want");
                                        $('#explanation').removeClass('mcq-ans-incorrect');
                                        $('#explanation').addClass('alert-info');
                                        $('#submit-btn').removeClass('disabled');
                                        $('#submit-btn').addClass('btn-primary');
                                        $('#submit-btn').attr("disabled", false);
                                        clearInterval(reunlock_session_interval);
                                        //location.reload();
                                    }
                                }
                            });
                        }, 1000);
                    }*/

                } else {
                    //$('#continue-btn').removeClass('disabled');
                    $('#explanation').addClass('mcq-ans-incorrect');
                }
                //To next question right after answering pre one
                if(btn_id=='test-next-btn') {
                    window.location.href = $('#test-next-btn').attr('href');
                }
            }, 'json');
        }
        if(btn_id=='submit-btn') {
            return false; // prevent default
        }
    });

    $('#continue-btn').click(function(evt) {
        if ($(this).hasClass('disabled')) {
            evt.preventDefault();
        }
    });

    $("#pathrun").bind("click",submitCode);
    $(document).keydown(function(evt){
        if(evt.altKey && evt.which == 82){
            submitCode();
        }
    });

    var running = false;
    function submitCode(){
        if(running) return;
        running = true;
        $("#pathrun").attr("disabled",true);
        var form = $("#training-step-form");
        var update_url = form.children("input[name=update_url]").val();
        var qid = form.children("input[name=qid]").val();
        var step = form.children("input[name=step]").val();

        var failcolor = {backgroundColor: "#e1c1b1"}
        var animateOpt = {duration: 1000, queue: false};
        var passcolor = {backgroundColor: "#008000"};
        $.get(update_url,
            {
                code: $("#ans").val(),
                step: step,
                qid: qid
            },
            function(resp){
                var $er = $("#eval_result");
                $(document.body).scrollTop(($er.offset().top + $er.height()) - $("#ruler").show().height() + 100);
                $("#ruler").hide();
                if(resp.errors.length > 0){
//                $er.text(resp.errors).animate({backgroundColor: "#3C2502",color:"#FF0000"}, animateOpt);
//                console.log("error")
                    $er.html(escapeHtml(resp.errors)).animate({backgroundColor: "#e1c1b1"}, animateOpt);
                }else{
                    var publicTestFlag = true;
                    $("#publicTestTable tbody tr").each(function(index, e){
//                    console.log("change table")
                        if(resp.public[index]){
                            var temp = $("td:last",e);
                            if(temp.hasClass("pathTestFail")){
                                temp.switchClass("pathTestFail","pathTestPass").animate(passcolor,animateOpt);
                            }else if(!temp.hasClass("pathTestPass")){
                                temp.addClass("pathTestPass").animate(passcolor,animateOpt);;
                            }
                        }else{
                            publicTestFlag = false;
                            var temp = $("td:last",e);
                            if(temp.hasClass("pathTestPass")){

                                temp.switchClass("pathTestPass", "pathTestFail").animate(failcolor, animateOpt);
                            }else if(!temp.hasClass("pathTestFail")){
                                temp.addClass("pathTestFail", 1000).animate(failcolor,animateOpt);
                            }
                        }
                    });
                    var privateTestFlag = resp.private.length == 0 ? true : resp.private.reduce(function(a,b){return a && b});
                    if(publicTestFlag){
                        if(resp.private == null || !privateTestFlag){
                            $er.html("Your answer failed to pass one or more of the private test cases."  + (resp.hint ? " <br>Hint: " + resp.hint : "")).animate(failcolor, animateOpt);
                        }else{
                            $er.html("You have successfully completed this step!").animate(passcolor, animateOpt);
                            $('#continue-btn').removeClass('disabled');
                            $("#pathrun").attr("disabled",true);
                            return; // we do not undisable the run
                        }
                    }else{
                        $er.html("Your answer failed to pass one or more of the public test cases.").animate(failcolor,animateOpt);
                    }
                }

                running = false;
                $("#pathrun").attr("disabled",false);
            }, 'json')
    }
});


