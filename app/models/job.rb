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


		p "inserting header...."
		pp result

		p "...done"

		if result[:success]
			perform(self.dataset_name, self.csv_url, self.username, self.password, self.meta_json,self.mobile, result[:record_id])
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

	def perform( dataset_name, csv_url, username, password, meta_json, phone, parent_record_id )
		
		require 'open-uri'
		require 'pp'


		payload = {
			"Format" => "Csv",
			"EdgemartAlias" => dataset_name,
			"MetadataJson" => meta_json,
			"Operation" => "Overwrite",
			"Action" => "None"
		}


		original_file_name = "tmp_csv_file-" + SecureRandom.hex(5)
		file_names = [ original_file_name+"-1" ] # contains the list smaller chunks of files
		


		#download the csv file to working directory
		open(original_file_name, 'wb'){|saved_file|
			open(csv_url, 'rb'){|read_file|
				saved_file.write(read_file.read)
			}
		}
		
		#open source file and destination file
		file = File.open(original_file_name, "r")
		index_of_files = 0
		tmp = File.open(file_names[index_of_files], "a")

		file.each do |line|
			# go through each line of the csv file
			# and create create files all less than 5 MB
			tmp.puts line

			if tmp.size > FILE_MAX_SIZE
				p "index is: #{index_of_files}"
				tmp.close
				index_of_files = index_of_files + 1
				file_names << original_file_name + "-" + (index_of_files + 1).to_s
				tmp = File.open(file_names[index_of_files], "a")
			end
		end
		file.close
		File.delete( original_file_name )


		payload = {
			"Format" => "Csv",
			"EdgemartAlias" => dataset_name,
			"MetadataJson" => meta_json,
			"Operation" => "Overwrite",
			"Action" => "None"
		}

		s = SforceWrapper.new(username, password)
		
		if parent_record_id
			file_names.each_with_index do |file_name, index|
				p "uploading part: #{file_name}"
				payload = {
					"DataFile" => Base64.encode64(File.read(file_name)),
					"InsightsExternalDataId" => parent_record_id,
					"PartNumber" => index+1
				}
				s.insert_record( "InsightsExternalDataPart", payload )
				File.delete(file_name)
			end


			payload = {
			"Action" => "Process"
			}
			s.update_record( "InsightsExternalData", parent_record_id, payload )
			
			if phone.present?
				blowerio = RestClient::Resource.new(ENV['BLOWERIO_URL'])
				blowerio['/messages'].post :to => phone, :message => "analytics load completed for dataset '#{dataset_name}'"
			end
			

		else
			p "data loading header could not be created!"
			if phone.present?
				blowerio = RestClient::Resource.new(ENV['BLOWERIO_URL'])
				blowerio['/messages'].post :to => phone, :message => "analytics load failed for dataset '#{dataset_name}'"
			end

		end



	end


end
