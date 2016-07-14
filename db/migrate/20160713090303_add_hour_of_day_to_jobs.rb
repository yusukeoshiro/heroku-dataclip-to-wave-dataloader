class AddHourOfDayToJobs < ActiveRecord::Migration
  def change
    add_column :jobs, :hour_of_day, :integer
  end
end
