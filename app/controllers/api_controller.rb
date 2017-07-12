class ApiController < ApplicationController
	skip_before_filter :verify_authenticity_token

	def run_job
		job_id = params[:job_id]
		job = Job.find_by_id job_id
		if !job.nil?
			p "running job #{job.name}..."
			job.run_job
		end
		render :json=> params
	end

end
