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
#  full_url   :string           not null
#  ip_address :string           not null
#  post_ids   :integer          is an Array
#  referer    :string(2000)
#  user_agent :string           not null
#  visit_time :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  session_id :string(32)       not null
#  topic_id   :integer
#  user_id    :integer
#
