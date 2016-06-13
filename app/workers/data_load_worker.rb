class DataLoadWorker
	include Sidekiq::Worker
	#sidekiq_options queue: :event

	def perform( dataset_name, csv_url, username, password, meta_json )
		
		require 'open-uri'
		require 'pp'
		
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
		parent_record_id = s.insert_record( "InsightsExternalData", payload )

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
		else
			p "data loading header could not be created!"
		end



	end
end
