# frozen_string_literal: true

# name: discourse-page-visits
# about: Track and store additional page visit data
# meta_topic_id: TODO
# version: 0.0.1
# authors: Discourse
# url: https://github.com/discourse/discourse-page-visits
# required_version: 2.7.0

enabled_site_setting :discourse_page_visits_enabled

module ::DiscoursePageVisits
  PLUGIN_NAME = "discourse-page-visits"
end

require_relative "lib/discourse_page_visits/engine"
