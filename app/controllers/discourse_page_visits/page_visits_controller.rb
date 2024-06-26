# frozen_string_literal: true

module ::DiscoursePageVisits
  class PageVisitsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    def create
      params = page_visit_params

      if params[:user_id]
        user = User.find_by(id: params[:user_id])
        params[:ip_address] = user.ip_address
      end

      new_page_visit = PageVisit.new(params)

      if new_page_visit.save
        render json: success_json
      else
        render_json_error(new_page_visit)
      end
    end

    private

    def page_visit_params
      params.require(:page_visit).permit(
        :user_id,
        :created_at,
        :full_url,
        :ip_address,
        :user_agent,
        :topic_id,
        :visit_time,
        post_ids: [],
      )
    end
  end
end
