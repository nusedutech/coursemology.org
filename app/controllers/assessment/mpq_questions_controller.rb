class Assessment::MpqQuestionsController < Assessment::QuestionsController

  def show
    @questions = @question.sub_questions

  end

  def create
    saved = super
    respond_to do |format|
      #if saved
      if @question
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

        if !@assessment.nil?
          format.html { redirect_to url_for([@course, @assessment.as_assessment]),
                                    notice: 'Question has been added.'}
        else
          format.html { redirect_to main_app.course_assessment_mpq_question_url(@course,@question),
                                    notice: 'Question has been added.'}
        end
        format.json { render json: @question, status: :created, location: @question }
      else
        format.html { render action: 'new' }
        format.json { render json: @question.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    super

    if (!params["new_tags_concept"].nil? && !params["original_tags_concept"].nil?)
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
    end

    updated = @question.update_attributes(params["assessment_mpq_question"])
    respond_to do |format|
      if updated && @question.save
        if !@assessment.nil?
          if @assessment.as_assessment.is_a?(Assessment::Training)
            format.html { redirect_to course_assessment_training_url(@course, @assessment.as_assessment),
                                      notice: 'Question updated.' }
          end
        elsif !@parent_mpq_question.nil?
          format.html { redirect_to main_app.course_assessment_mpq_question_url(@course,@parent_mpq_question),
                                    notice: 'Question updated.'}
        else
          format.html { redirect_to main_app.course_assessment_questions_url(@course),
                                    notice: 'Question updated.'}
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
