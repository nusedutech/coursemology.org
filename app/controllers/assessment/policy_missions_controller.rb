class Assessment::PolicyMissionsController < Assessment::AssessmentsController
	load_and_authorize_resource :policy_mission, class: "Assessment::PolicyMission", through: :course
	
	def new
			respond_to do |format|
		    format.html
		  end
		end
	end
