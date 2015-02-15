$(document).ready(function() {
    
	$('input[name="guidance_quiz_enable"]').change(function(e) {
		update_guidance_quiz_enable_info(e,this);
	});

});


function update_guidance_quiz_enable_info(e, handler){
	e.preventDefault();
	var url = $(handler).next().val();       	
	var data = { enable :  $(handler).prop('checked')};

	$.ajax({
		url : url,
		type : 'POST',
		dataType : 'json',
		data : data,
		success: function(json) {
        console.log(json.result);
    },
    error: function(XMLHttpRequest, textStatus, errorThrown) { 
      	alert("Status: " + textStatus + " Error: " + errorThrown); 
  	}
	}); 	
}
