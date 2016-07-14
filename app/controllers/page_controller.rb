class PageController < ApplicationController
	def index
		if params["username"]
			require "pp"
			#check if everything is there
			username = params["username"]
			password = params["password"]
			meta_json = Base64.encode64(params["meta_json"].tempfile.read)
			csv_url = params["csv_url"]
			dataset_name = params["dataset_name"]
			phone = params["phone"]

			

			payload = {
				"Format" => "Csv",
				"EdgemartAlias" => dataset_name,
				"MetadataJson" => meta_json,
				"Operation" => "Overwrite",
				"Action" => "None"
			}


			s = SforceWrapper.new(username, password)
			result = s.insert_record( "InsightsExternalData", payload )

			if result[:success]
				DataLoadWorker.perform_async(dataset_name, csv_url, username, password, meta_json,phone, result[:record_id])
				flash[:notice] = "Go grab a coffee! it is going to take a while..."

			else
				flash[:error] = result[:message]
			end
			
		end


	end
end
