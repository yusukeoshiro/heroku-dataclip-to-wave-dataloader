task :run_schedule => :environment do

	Job.due.each do |j|
		j.run_job
	end

end



