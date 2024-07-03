# frozen_string_literal: true

module ::DiscoursePageVisits
  class PageVisit < ActiveRecord::Base
    self.table_name = "page_visits"
  end
end
