desc "This task is called by the Heroku scheduler add-on"
task :test_task => :environment do
	p "test task was fired!"
end

