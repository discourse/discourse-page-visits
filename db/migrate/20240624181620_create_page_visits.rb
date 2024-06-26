# frozen_string_literal: true

class CreatePageVisits < ActiveRecord::Migration[7.1]
  def change
    create_table :page_visits do |t|
      t.integer :user_id, null: true # null for anon users
      t.string :full_url, null: false
      t.string :ip_address, null: false
      t.string :user_agent, null: false
      t.integer :topic_id, null: true # null for non-topic routes
      t.integer :post_ids, array: true, null: true # null for non-topic routes
      t.integer :visit_time, null: false

      t.timestamps
    end
  end
end