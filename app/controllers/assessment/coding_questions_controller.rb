class Assessment::CodingQuestionsController < Assessment::QuestionsController
  before_filter :set_avaialbe_test_types, only: [:new, :edit]

  def new
    @question.auto_graded = !@assessment.is_mission?
    @question.language = ProgrammingLanguage.first
    super
  end

  def create
    @question.auto_graded = !@assessment.is_mission?
    saved = super
    # update max grade of the asm it belongs to
    respond_to do |format|
      if saved
        
        
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
      
        
        flash[:notice] = 'New question added.'
        format.html { redirect_to url_for([@course, @assessment.as_assessment]) }
        format.json { render json: @question, status: :created, location: @question }
      else
        format.html { render action: 'new' }
        format.json { render json: @question.errors, status: :unprocessable_entity }
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
      
      
    @question.update_attributes(params[:assessment_coding_question])

    respond_to do |format|
      if @question.save
        flash[:notice] = 'Question has been updated.'
        format.html { redirect_to url_for([@course, @assessment.as_assessment]) }
      else
        format.html { render action: 'edit' }
        format.json { render json: @question.errors, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_avaialbe_test_types
    @test_types = {public: 'Public', private: 'Private'}
    if @assessment.is_mission?
      @test_types[:eval] = 'Evaluation'
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
