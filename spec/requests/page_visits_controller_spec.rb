# frozen_string_literal: true

RSpec.describe DiscoursePageVisits::PageVisitsController do
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:topic)
  fab!(:topic_post) { Fabricate(:post, topic: topic) }

  let(:page_visit_params) do
    {
      full_url: "http://test.localhost/t/#{topic.slug}/#{topic.id}",
      topic_id: topic.id,
      post_ids: [topic_post.id],
      visit_time: 1000,
      user_id: other_user.id,
    }
  end

  before { SiteSetting.discourse_page_visits_enabled = true }

  describe "#create" do
    it "stores the authenticated user as the visit user" do
      sign_in(user)

      expect {
        post "/page-visits.json",
             params: page_visit_params,
             headers: {
               "HTTP_USER_AGENT" => "RSpec",
             }
      }.to change { DiscoursePageVisits::PageVisit.count }.by(1)

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq("success" => "OK")
      expect(DiscoursePageVisits::PageVisit.last).to have_attributes(
        user_id: user.id,
        full_url: page_visit_params[:full_url],
        topic_id: topic.id,
        post_ids: [topic_post.id],
        visit_time: 1000,
      )
    end

    it "stores no visit user for anonymous requests" do
      expect {
        post "/page-visits.json",
             params: page_visit_params,
             headers: {
               "HTTP_USER_AGENT" => "RSpec",
             }
      }.to change { DiscoursePageVisits::PageVisit.count }.by(1)

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq("success" => "OK")
      expect(DiscoursePageVisits::PageVisit.last.user_id).to eq(nil)
    end
  end
end
