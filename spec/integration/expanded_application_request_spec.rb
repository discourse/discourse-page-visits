# frozen_string_literal: true

RSpec.describe "Expanded Application Request Tracking" do
  fab!(:user)

  let(:api_key) { Fabricate(:api_key, user: user) }

  let(:user_api_key) do
    Fabricate(
      :user_api_key,
      user: user,
      scopes: [Fabricate.build(:user_api_key_scope, name: "read")],
    )
  end

  before do
    SiteSetting.discourse_page_visits_enabled = true
    CachedCounting.reset
    CachedCounting.enable
    ApplicationRequest.enable
  end

  after do
    ApplicationRequest.disable
    CachedCounting.reset
    CachedCounting.disable
  end

  describe "API requests" do
    it "logs API key requests with user_id" do
      expect { get "/u/#{user.username}.json", headers: { HTTP_API_KEY: api_key.key } }.to change {
        DiscoursePageVisits::ExpandedApplicationRequest.count
      }.by(1)

      expect(response.status).to eq(200)

      record = DiscoursePageVisits::ExpandedApplicationRequest.last
      expect(record.is_api).to eq(true)
      expect(record.is_user_api).to eq(false)
      expect(record.user_id).to eq(user.id)
      expect(record.url).to include("/u/#{user.username}.json")
      expect(record.status).to eq(200)
      expect(record.ip_address).to be_present
    end

    it "logs User API key requests with user_id" do
      expect {
        get "/session/current.json", headers: { HTTP_USER_API_KEY: user_api_key.key }
      }.to change { DiscoursePageVisits::ExpandedApplicationRequest.count }.by(1)

      expect(response.status).to eq(200)

      record = DiscoursePageVisits::ExpandedApplicationRequest.last
      expect(record.is_api).to eq(false)
      expect(record.is_user_api).to eq(true)
      expect(record.user_id).to eq(user.id)
    end

    it "matches ApplicationRequest.api count" do
      initial_expanded_count = DiscoursePageVisits::ExpandedApplicationRequest.count

      get "/u/#{user.username}.json", headers: { HTTP_API_KEY: api_key.key }
      CachedCounting.flush

      expanded_count =
        DiscoursePageVisits::ExpandedApplicationRequest.count - initial_expanded_count
      api_count = ApplicationRequest.api.first&.count || 0

      expect(expanded_count).to eq(api_count)
    end
  end

  describe "plugin disabled" do
    it "does not log any requests when plugin is disabled" do
      SiteSetting.discourse_page_visits_enabled = false

      expect {
        get "/u/#{user.username}.json", headers: { HTTP_API_KEY: api_key.key }
      }.not_to change { DiscoursePageVisits::ExpandedApplicationRequest.count }
    end
  end

  describe "non-trackable requests" do
    it "does not log JSON AJAX requests without API key or track_view header" do
      sign_in(user)

      expect {
        get "/latest.json", headers: { "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest" }
      }.not_to change { DiscoursePageVisits::ExpandedApplicationRequest.count }
    end
  end
end
