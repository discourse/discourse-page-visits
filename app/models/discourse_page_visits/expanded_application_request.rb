# frozen_string_literal: true

module ::DiscoursePageVisits
  class ExpandedApplicationRequest < ActiveRecord::Base
    self.table_name = "expanded_application_requests"

    belongs_to :user, optional: true
    belongs_to :topic, optional: true
  end
end
