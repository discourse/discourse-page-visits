# frozen_string_literal: true

class RemoveNotNullFromVisitTimeInPageVisit < ActiveRecord::Migration[8.0]
  def change
    change_column_null :page_visits, :visit_time, true
  end
end
