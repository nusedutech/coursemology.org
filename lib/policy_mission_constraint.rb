class PolicyMissionConstraint
  def matches?(request)
    a = Assessment.find_by_id(request.path_parameters[:assessment_id])
    a && a.is_policy_mission?
  end
end
