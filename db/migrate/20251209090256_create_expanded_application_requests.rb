# frozen_string_literal: true

class CreateExpandedApplicationRequests < ActiveRecord::Migration[7.2]
  def change
    create_table :expanded_application_requests do |t|
      t.integer :user_id, null: true
      t.string :url, null: false
      t.integer :topic_id, null: true
      t.inet :ip_address, null: true
      t.integer :status, null: false
      t.boolean :is_crawler, default: false, null: false
      t.boolean :is_api, default: false, null: false
      t.boolean :is_user_api, default: false, null: false
      t.boolean :is_background, default: false, null: false

      t.datetime :created_at, null: false
    end

    add_index :expanded_application_requests, :user_id
    add_index :expanded_application_requests, :topic_id
    add_index :expanded_application_requests, :created_at
  end
end
