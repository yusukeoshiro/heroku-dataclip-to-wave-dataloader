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

			
			DataLoadWorker.perform_async(dataset_name, csv_url, username, password, meta_json,phone)

			flash[:notice] = "Go grab a coffee! it is going to take a while..."

			
		end


	end
end
