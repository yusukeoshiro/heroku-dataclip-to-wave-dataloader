class CreateJobs < ActiveRecord::Migration
  def change
    create_table :jobs do |t|
      t.string :name
      t.string :username
      t.string :password
      t.string :csv_url
      t.string :dataset_name
      t.string :meta_json
      t.string :mobile
      t.datetime :next_job
      t.integer :interval_sec

      t.timestamps null: false
    end
  end
end
