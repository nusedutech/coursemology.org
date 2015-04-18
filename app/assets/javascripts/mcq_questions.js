// add new mcq answer in the form
//
// button on click
//    extract information
//    append before the new form
$(document).ready(function() {
  $('#mcq-options .add-mcq-option').on('click', function(e) {
    e.preventDefault();
    var num_ans = $(this).parents('tbody').children().length;
    format = ['<tr>',
              '<td><input name="options[' + num_ans + '][correct]" type="checkbox" /></td>',
              '  <td>',
              '    <textarea id="options_'+num_ans+'_text" name="options[' + num_ans + '][text]" placeholder="Answer..." /></textarea>',
              '  </td><td>',
              '    <textarea id="options_'+num_ans+'_explanation" name="options[' + num_ans + '][explanation]" placeholder="Explanation..." /></textarea>',
              '  </td>',
              '</tr>'].join('');
    $(this).parents('tr').before(format);
    $('textarea#options_'+num_ans+'_text').ckeditor();
    $('textarea#options_'+num_ans+'_explanation').ckeditor();
  });
});
