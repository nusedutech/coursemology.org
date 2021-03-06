module AutoGrader

  def AutoGrader.mcq_grader(submission, ans, mcq, pref_grader)
    # grading answer in training by score 2-1-0
    # 2 for answer correctly the first time
    # 1 for answer correctly in subsequence attempts
    # 0 for only answering correctly in the last choice
    # currently, there is one answer grading for each question
    # when there are multiple answer for one question, only the one
    # that is counted is graded (and attached with the grading)

    # Strategy: mark again every time I receive a new answer
    # - Get all student answers for the question
    # - Get all possible answers for the question
    # - Find the first answer that is correct
    #   + First try => 2pts
    #   + If all wrong answers are ticked off => 0pt
    #   + Otherwise 1pt

    grading = submission.get_final_grading
    grading.save unless grading.persisted?
    ag = grading.answer_gradings.for_question(mcq.question).first ||
          grading.answer_gradings.create({answer_id: ans.id})

    unless ag.grade
      std_answers = submission.answers.where(question_id: ans.question_id)
      if submission.assessment.as_assessment.is_a?(Assessment::Training) and
          (submission.assessment.as_assessment.test or submission.assessment.realtime_session_groups.count > 0)
        answer = std_answers.first
        if answer.nil?
          ag.grade = 0
        elsif !answer.correct
          if submission.assessment.option_grading && mcq.select_all
            an_ops = answer.answer_options.map(&:option_id)
            corrects = mcq.options.map{ |x| ((x.correct && (an_ops.include? x.id)) || (!x.correct && !(an_ops.include? x.id))) ? 1 : 0 }.reduce(:+)
            ag.grade = corrects * (mcq.max_grade.nil? ? 0 : mcq.max_grade) / mcq.options.count
          else
            ag.grade = 0
          end
        else
          ag.grade = mcq.max_grade.nil? ? 0 : mcq.max_grade
        end
      else
        if pref_grader != 'two-one-zero' || std_answers.count == 0
          ag.grade = mcq.max_grade.nil? ? 0 : mcq.max_grade
        elsif mcq.specific.select_all?
          ag.grade = (mcq.max_grade.nil? ? 0 : mcq.max_grade) / 2.0
        else
          num_wrong_choices = mcq.options.find_all_by_correct(false).count
          uniq_wrong_attempts = std_answers.unique_attempts(false).count
          ag.grade = (num_wrong_choices <= uniq_wrong_attempts) ? 0 : 1
        end
      end
      ag.save
    else
      if submission.assessment.as_assessment.is_a?(Assessment::Training) and submission.assessment.realtime_session_groups.count > 0
        ag.grade = (ans.correct and !mcq.max_grade.nil?) ? mcq.max_grade : 0
        ag.save
      end
    end

    return ag.grade
  end

  def AutoGrader.coding_question_grader(submission, question, ans)
    # note: this grader doesn't update the EXP of the student
    grading = submission.get_final_grading
    grading.save unless grading.persisted?

    ag = grading.answer_gradings.for_question(question.question).first ||
        grading.answer_gradings.create({answer_id: ans.id})

    ag.grade = question.max_grade
    ag.save
    ag.grade
  end
end
