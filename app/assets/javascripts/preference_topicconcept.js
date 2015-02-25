$(document).ready(function() {
    
	$('input[name^=guidance_quiz_setting]').change(function(e) {
		update_guidance_quiz_setting_info(e,this);
	});

});


function update_guidance_quiz_setting_info(e, handler){
	e.preventDefault();
	var url = $(handler).nextAll('input').first().val();       	
	var data = { data :  $(handler).prop('checked')};
	$.ajax({
		url : url,
		type : 'POST',
		dataType : 'json',
		data : data,
		success: function(json) {
    },
    error: function(XMLHttpRequest, textStatus, errorThrown) { 
      	alert("Status: " + textStatus + " Error: " + errorThrown); 
  	}
	}); 	
}
