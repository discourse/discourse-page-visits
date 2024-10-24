# frozen_string_literal: true

module ::DiscoursePageVisits
  class PageVisit < ActiveRecord::Base
    self.table_name = "page_visits"
  end
end

# == Schema Information
#
# Table name: page_visits
#
#  id         :bigint           not null, primary key
#  user_id    :integer
#  full_url   :string           not null
#  ip_address :string           not null
#  user_agent :string           not null
#  topic_id   :integer
#  post_ids   :integer          is an Array
#  visit_time :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
