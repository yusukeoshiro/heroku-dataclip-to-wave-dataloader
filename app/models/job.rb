class Job < ActiveRecord::Base

	#scope 

	scope :due, -> { where("next_job < ?", DateTime.now) }

	before_save :update_next_job

	validates :name, :presence => true
	validates :username, :presence => true
	validates :password, :presence => true
	validates :dataset_name, :presence => true
	validates :meta_json, :presence => true
	validates :csv_url, :presence => true
	validates :hour_of_day, :presence => true

	def run_job

		s = SforceWrapper.new(self.username, self.password)

		payload = {
			"Format" => "Csv",
			"EdgemartAlias" => self.dataset_name,
			"MetadataJson" => self.meta_json,
			"Operation" => "Overwrite",
			"Action" => "None"
		}


		result = s.insert_record( "InsightsExternalData", payload )

		if result[:success]
			DataLoadWorker.perform_async(self.dataset_name, self.csv_url, self.username, self.password, self.meta_json,self.mobile, result[:record_id])			
		end

		self.next_job = get_next_job(self)
		self.save

	end


	private 
	def update_next_job
		if self.next_job.nil?
			self.next_job = get_next_job(self)
		end		
	end

	def get_next_job( job )
		rightnow = DateTime.now
		if self.hour_of_day <= rightnow.hour
			# already passed, next job is next day
			return DateTime.new(rightnow.year, rightnow.month, rightnow.day, job.hour_of_day, 0, 0) + 1
		else
			# not passed yet, next job is within today
			return DateTime.new(rightnow.year, rightnow.month, rightnow.day, job.hour_of_day, 0, 0)
		end
	end

end
