function guidance_quiz_post_with_concept_id( url, concept_id ) {
    var gq_new_form = document.createElement('form');
    gq_new_form.setAttribute('method', 'post');
    gq_new_form.setAttribute('action', url);
    gq_new_form.style.display = 'hidden';

    var input = document.createElement('input');
    input.type = 'hidden';
    input.name = 'concept_id';
    input.value = concept_id;

    gq_new_form.appendChild(input);
    document.body.appendChild(gq_new_form)
    gq_new_form.submit();

}


