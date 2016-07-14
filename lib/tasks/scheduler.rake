task :run_schedule => :environment do

	Job.due.each do |j|
		require "pp"
		p "running job...."
		pp j
		j.run_job
	end

end



