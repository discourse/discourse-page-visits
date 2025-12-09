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

after_initialize do
  request_logger =
    lambda do |env, data|
      return unless SiteSetting.discourse_page_visits_enabled

      # Mirror the exact conditions from Middleware::RequestTracker.log_request
      # that increment application_request counters (excluding http_total/status codes)
      should_log = false

      if data[:is_api]
        should_log = true
      elsif data[:is_user_api]
        should_log = true
      elsif data[:track_view]
        if data[:is_crawler]
          should_log = true
        elsif data[:has_auth_cookie]
          should_log = true
        elsif !SiteSetting.login_required
          should_log = true
        end
      end

      # Deferred track view (browser page views via message-bus)
      if data[:deferred_track_view] && !data[:is_crawler]
        if data[:has_auth_cookie]
          should_log = true
        elsif !SiteSetting.login_required
          should_log = true
        end
      end

      return unless should_log

      url = env["REQUEST_URI"]
      return if url.blank?

      DiscoursePageVisits::ExpandedApplicationRequest.create!(
        user_id: data[:current_user_id],
        url: url,
        topic_id: data[:topic_id],
        ip_address: data[:request_remote_ip],
        status: data[:status],
        is_crawler: data[:is_crawler] || false,
        is_api: data[:is_api] || false,
        is_user_api: data[:is_user_api] || false,
        is_background: data[:is_background] || false,
      )
    end

  Middleware::RequestTracker.register_detailed_request_logger(request_logger)
end
