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


			pp meta_json
			DataLoadWorker.perform_async(dataset_name, csv_url, username, password, meta_json)

			flash[:notice] = "Go grab a coffeee! it is going to take a while..."

			
		end


	end
end
