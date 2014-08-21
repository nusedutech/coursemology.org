class Assessment::McqQuestionsController < Assessment::QuestionsController
  # https://github.com/ryanb/cancan/wiki/Nested-Resources

  def update_answers(mcq)
    updated = true
    param_options = params["options"]
    if param_options
      param_options.each do |i, option|
        option['correct'] = option.has_key?('correct')
        if option.has_key?('id')
          opt = Assessment::McqOption.find(option['id'])
          opt.question = mcq
          # TODO: check if this answer does belong to the current question
          if !option['text'] || option['text'] == ''
            opt.destroy
          else
            updated = updated && opt.update_attributes(option)
          end
        elsif option['text'] && option['text'] != ''
          opt = mcq.options.build(option)
          updated = updated && opt.save
        end
      end
    end
    updated
  end

  def create
    # update max grade of the asm it belongs to
    saved = super
    respond_to do |format|
      
      
      if(params["new_tags_concept"] != params["original_tags_concept"])
           update_tag(JSON.parse(params["original_tags_concept"]),JSON.parse(params["new_tags_concept"]), nil)
         end
         @course.tag_groups.each do |t|         
           if(params["new_tags_#{t.name}"] != params["original_tags_#{t.name}"])
             update_tag(JSON.parse(params["original_tags_#{t.name}"]),JSON.parse(params["new_tags_#{t.name}"]), t)
           end
         end
        
       #add difficulty tag for no difficulty question
        dif = @course.tag_groups.where(:name => 'Difficulty')
        if (dif.count > 0 && @question.tags.where(:tag_group_id => dif.first.id).count == 0 && @course.tags.where(:tag_group_id => dif.first.id, :name => 'Unspecified').count > 0)
          taggable = @question.taggable_tags.new                          
          taggable.tag= @course.tags.where(:tag_group_id => dif.first.id, :name => 'Unspecified').first
          taggable.save
        end
      
      
      
      if saved
        update_answers(@question)
        if @assessment.as_assessment.is_a?(Assessment::Training)
          format.html { redirect_to course_assessment_training_url(@course, @assessment.as_assessment),
                        notice: 'New question added.' }
        end
      else
        format.html { render action: "new" }
      end
    end
  end

  def update
    super
    
    
    if(JSON.parse(params["new_tags_concept"]) != JSON.parse(params["original_tags_concept"]))
         update_tag(JSON.parse(params["original_tags_concept"]),JSON.parse(params["new_tags_concept"]), nil)
       end
       @course.tag_groups.each do |t|         
         if(JSON.parse(params["new_tags_#{t.name}"]) != JSON.parse(params["original_tags_#{t.name}"]))           
           update_tag(JSON.parse(params["original_tags_#{t.name}"]),JSON.parse(params["new_tags_#{t.name}"]), t)
         end
       end
      
      #add difficulty tag for no difficulty question
        dif = @course.tag_groups.where(:name => 'Difficulty')
        if (dif.count > 0 && @question.tags.where(:tag_group_id => dif.first.id).count == 0 && @course.tags.where(:tag_group_id => dif.first.id, :name => 'Unspecified').count > 0)
          taggable = @question.taggable_tags.new                          
          taggable.tag= @course.tags.where(:tag_group_id => dif.first.id, :name => 'Unspecified').first
          taggable.save
        end
      
      
    updated = update_answers(@question) && @question.update_attributes(params["assessment_mcq_question"])
    respond_to do |format|
      if updated && @question.save
        if @assessment.as_assessment.is_a?(Assessment::Training)
          format.html { redirect_to course_assessment_training_url(@course, @assessment.as_assessment),
                                    notice: 'Question updated.' }
        end

      else
        format.html { render action: "edit" }
      end
    end
  end
  
  
    def update_tag(original_tags, new_tags, group)
    new_tags.each do |obj|
      if(!original_tags.include? obj)
        if(group.nil?)
          tag_element = @course.topicconcepts.where(:name => obj).first
        else
          tag_element = group.tags.where(:name => obj).first
        end
        if(!tag_element.nil?)        
          taggable = @question.taggable_tags.new                          
          taggable.tag = tag_element   
          taggable.save                       
        end
      end
    end
              
    original_tags.each do |obj|
      if(!new_tags.include? obj)
        if(group.nil?)
          tag_element = @course.topicconcepts.where(:name => obj).first
        else
          tag_element = group.tags.where(:name => obj).first
        end              
        if(!tag_element.nil?)
          if tag_element.is_a?(Topicconcept)
            taggable = @question.taggable_tags.where(:tag_type => 'Topicconcept', :tag_id => tag_element.id).first
          else
            taggable = @question.taggable_tags.where(:tag_type => 'Tag', :tag_id => tag_element.id).first
          end
          if(!taggable.nil?)
            taggable.destroy
          end
        end
      end
    end
  end

end
