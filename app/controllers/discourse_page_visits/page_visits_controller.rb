# frozen_string_literal: true

module ::DiscoursePageVisits
  class PageVisitsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    def create
      params_with_request =
        page_visit_params.merge(ip_address: request.remote_ip, user_agent: request.user_agent)
      new_page_visit = PageVisit.new(params_with_request)

      if new_page_visit.save
        render json: success_json
      else
        render_json_error(new_page_visit)
      end
    end

    private

    def page_visit_params
      params.permit(:visit_time, :full_url, :user_id, :topic_id, :ip_address, post_ids: [])
    end
  end
end
