class GuidanceQuizConstraint
  def matches?(request)
    a = Assessment.find_by_id(request.path_parameters[:assessment_id])
    a && a.is_guidance_quiz?
  end
end