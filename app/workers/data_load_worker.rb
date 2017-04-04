class DataLoadWorker
	include Sidekiq::Worker
	#sidekiq_options queue: :event

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
				begin
					blowerio = RestClient::Resource.new(ENV['BLOWERIO_URL'])
					blowerio['/messages'].post :to => phone, :message => "analytics load completed for dataset '#{dataset_name}'"	
				rescue Exception => e
					p "sms failed for some reason"
					p e.message
				end				
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
