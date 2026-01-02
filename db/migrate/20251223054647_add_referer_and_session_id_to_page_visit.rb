# frozen_string_literal: true

class AddRefererAndSessionIdToPageVisit < ActiveRecord::Migration[8.0]
  def change
    add_column :page_visits, :referer, :string, limit: 2000
    add_column :page_visits, :session_id, :string, limit: 32, null: false
  end
end
