# frozen_string_literal: true

RSpec.describe "Page Visit Tracking" do
  fab!(:user)
  fab!(:topic)
  let(:real_browser_agent) { "i-am-a-real-browser" }
  let(:crawler_agent) { "i-am-a-crawler" }

  before do
    ApplicationRequest.enable
    CachedCounting.reset
    CachedCounting.enable

    SiteSetting.discourse_page_visits_enabled = true
    SiteSetting.non_crawler_user_agents = real_browser_agent
    SiteSetting.crawler_user_agents = crawler_agent
  end

  after do
    CachedCounting.reset
    ApplicationRequest.disable
    CachedCounting.disable
  end

  describe "when application receives a request and responds with 200" do
    context "with authenticated user" do
      before { sign_in(user) }

      it "creates a PageVisit record when visiting a topic page" do
        expect do
          get topic.relative_url,
              headers: {
                "HTTP_DISCOURSE_TRACK_VIEW" => "1",
                "HTTP_DISCOURSE_TRACK_VIEW_URL" => "http://test.localhost#{topic.relative_url}",
                "HTTP_DISCOURSE_TRACK_VIEW_TOPIC_ID" => topic.id.to_s,
                "HTTP_DISCOURSE_TRACK_VIEW_SESSION_ID" => "test-session-123",
                "HTTP_DISCOURSE_TRACK_VIEW_REFERRER" => "http://test.localhost/",
                "REMOTE_ADDR" => "11.34.111.45",
                "HTTP_USER_AGENT" => real_browser_agent,
              }
        end.to change { DiscoursePageVisits::PageVisit.count }.by(1)

        expect(response.status).to eq(200)

        visit_record = DiscoursePageVisits::PageVisit.last
        expect(visit_record).to have_attributes(
          user_id: user.id,
          full_url: "http://test.localhost#{topic.relative_url}",
          ip_address: "11.34.111.45",
          session_id: "test-session-123",
          referer: "http://test.localhost/",
        )
        expect(visit_record.user_agent).to be_present
      end

      it "creates a PageVisit record when visiting a non-topic page" do
        expect do
          get "/latest",
              headers: {
                "HTTP_DISCOURSE_TRACK_VIEW" => "1",
                "HTTP_DISCOURSE_TRACK_VIEW_URL" => "http://test.localhost/latest",
                "HTTP_DISCOURSE_TRACK_VIEW_SESSION_ID" => "test-session-456",
                "HTTP_USER_AGENT" => real_browser_agent,
              }
        end.to change { DiscoursePageVisits::PageVisit.count }.by(1)

        expect(response.status).to eq(200)

        visit_record = DiscoursePageVisits::PageVisit.last
        expect(visit_record).to have_attributes(
          user_id: user.id,
          full_url: "http://test.localhost/latest",
          session_id: "test-session-456",
        )
      end

      it "captures IP address from the request" do
        get topic.relative_url,
            headers: {
              "HTTP_DISCOURSE_TRACK_VIEW" => "1",
              "HTTP_DISCOURSE_TRACK_VIEW_URL" => "http://test.localhost#{topic.relative_url}",
              "HTTP_DISCOURSE_TRACK_VIEW_SESSION_ID" => "test-session-789",
              "REMOTE_ADDR" => "192.168.1.100",
              "HTTP_USER_AGENT" => real_browser_agent,
            }

        expect(response.status).to eq(200)

        visit_record = DiscoursePageVisits::PageVisit.last
        expect(visit_record.ip_address).to eq("192.168.1.100")
      end

      it "captures user agent from the request" do
        get topic.relative_url,
            headers: {
              "HTTP_DISCOURSE_TRACK_VIEW" => "1",
              "HTTP_DISCOURSE_TRACK_VIEW_URL" => "http://test.localhost#{topic.relative_url}",
              "HTTP_DISCOURSE_TRACK_VIEW_SESSION_ID" => "test-session-abc",
              "HTTP_USER_AGENT" => real_browser_agent,
            }

        expect(response.status).to eq(200)

        visit_record = DiscoursePageVisits::PageVisit.last
        expect(visit_record.user_agent).to eq(real_browser_agent)
      end

      it "truncates referer to 2000 characters" do
        long_referer = "http://test.localhost/" + ("a" * 2100)
        get topic.relative_url,
            headers: {
              "HTTP_DISCOURSE_TRACK_VIEW" => "1",
              "HTTP_DISCOURSE_TRACK_VIEW_URL" => "http://test.localhost#{topic.relative_url}",
              "HTTP_DISCOURSE_TRACK_VIEW_SESSION_ID" => "test-session-def",
              "HTTP_DISCOURSE_TRACK_VIEW_REFERRER" => long_referer,
              "HTTP_USER_AGENT" => real_browser_agent,
            }

        expect(response.status).to eq(200)

        visit_record = DiscoursePageVisits::PageVisit.last
        expect(visit_record.referer.length).to eq(2000)
        expect(visit_record.referer).to eq(long_referer.first(2000))
      end

      it "creates a PageVisit record when login is required" do
        SiteSetting.login_required = true

        expect do
          get "/",
              headers: {
                "HTTP_DISCOURSE_TRACK_VIEW" => "1",
                "HTTP_DISCOURSE_TRACK_VIEW_URL" => "http://test.localhost/",
                "HTTP_DISCOURSE_TRACK_VIEW_SESSION_ID" => "auth-session-789",
                "HTTP_USER_AGENT" => real_browser_agent,
              }
        end.to change { DiscoursePageVisits::PageVisit.count }.by(1)

        expect(response.status).to eq(200)

        visit_record = DiscoursePageVisits::PageVisit.last
        expect(visit_record).to have_attributes(
          user_id: user.id,
          full_url: "http://test.localhost/",
          session_id: "auth-session-789",
        )
      end
    end

    context "with anonymous user" do
      it "creates a PageVisit record with nil user_id" do
        expect do
          get topic.relative_url,
              headers: {
                "HTTP_DISCOURSE_TRACK_VIEW" => "1",
                "HTTP_DISCOURSE_TRACK_VIEW_URL" => "http://test.localhost#{topic.relative_url}",
                "HTTP_DISCOURSE_TRACK_VIEW_TOPIC_ID" => topic.id.to_s,
                "HTTP_DISCOURSE_TRACK_VIEW_SESSION_ID" => "anon-session-123",
                "HTTP_USER_AGENT" => real_browser_agent,
              }
        end.to change { DiscoursePageVisits::PageVisit.count }.by(1)

        expect(response.status).to eq(200)

        visit_record = DiscoursePageVisits::PageVisit.last
        expect(visit_record).to have_attributes(
          user_id: nil,
          full_url: "http://test.localhost#{topic.relative_url}",
          session_id: "anon-session-123",
        )
      end

      it "does not create a PageVisit record when login is required" do
        SiteSetting.login_required = true

        expect do
          get "/",
              headers: {
                "HTTP_DISCOURSE_TRACK_VIEW" => "1",
                "HTTP_DISCOURSE_TRACK_VIEW_URL" => "http://test.localhost/",
                "HTTP_DISCOURSE_TRACK_VIEW_SESSION_ID" => "anon-session-456",
                "HTTP_USER_AGENT" => real_browser_agent,
              }
          expect(response.status).to eq(200)
        end.not_to change { DiscoursePageVisits::PageVisit.count }
      end
    end

    context "when plugin is disabled" do
      before do
        SiteSetting.discourse_page_visits_enabled = false
        sign_in(user)
      end

      it "does not create a PageVisit record" do
        expect do
          get topic.relative_url,
              headers: {
                "HTTP_DISCOURSE_TRACK_VIEW" => "1",
                "HTTP_DISCOURSE_TRACK_VIEW_URL" => "http://test.localhost#{topic.relative_url}",
                "HTTP_DISCOURSE_TRACK_VIEW_SESSION_ID" => "test-session-999",
                "HTTP_USER_AGENT" => real_browser_agent,
              }
          expect(response.status).to eq(200)
        end.not_to change { DiscoursePageVisits::PageVisit.count }
      end
    end

    context "when response is not 200" do
      before { sign_in(user) }

      it "does not create a PageVisit record for 404 responses" do
        expect do
          get "/t/nonexistent-topic/99999",
              headers: {
                "HTTP_DISCOURSE_TRACK_VIEW" => "1",
                "HTTP_DISCOURSE_TRACK_VIEW_URL" =>
                  "http://test.localhost/t/nonexistent-topic/99999",
                "HTTP_DISCOURSE_TRACK_VIEW_SESSION_ID" => "test-session-404",
                "HTTP_USER_AGENT" => real_browser_agent,
              }
        end.not_to change { DiscoursePageVisits::PageVisit.count }

        expect(response.status).to eq(404)
      end
    end

    context "without track view header" do
      before { sign_in(user) }

      it "does not create a PageVisit record when HTTP_DISCOURSE_TRACK_VIEW is missing" do
        expect do
          get topic.relative_url,
              headers: {
                "HTTP_DISCOURSE_TRACK_VIEW_URL" => "http://test.localhost#{topic.relative_url}",
                "HTTP_DISCOURSE_TRACK_VIEW_SESSION_ID" => "test-session-no-track",
                "HTTP_USER_AGENT" => real_browser_agent,
              }
          expect(response.status).to eq(200)
        end.not_to change { DiscoursePageVisits::PageVisit.count }
      end

      it "does not create a PageVisit record when HTTP_DISCOURSE_TRACK_VIEW is false" do
        expect do
          get topic.relative_url,
              headers: {
                "HTTP_DISCOURSE_TRACK_VIEW" => "false",
                "HTTP_DISCOURSE_TRACK_VIEW_URL" => "http://test.localhost#{topic.relative_url}",
                "HTTP_DISCOURSE_TRACK_VIEW_SESSION_ID" => "test-session-false",
                "HTTP_USER_AGENT" => real_browser_agent,
              }
          expect(response.status).to eq(200)
        end.not_to change { DiscoursePageVisits::PageVisit.count }
      end
    end

    context "with deferred track view" do
      before { sign_in(user) }

      it "creates a PageVisit record when HTTP_DISCOURSE_TRACK_VIEW_DEFERRED is set" do
        expect do
          get "/message-bus/#{SecureRandom.hex}/poll",
              headers: {
                "HTTP_DISCOURSE_TRACK_VIEW_DEFERRED" => "1",
                "HTTP_DISCOURSE_TRACK_VIEW_URL" => "http://test.localhost#{topic.relative_url}",
                "HTTP_DISCOURSE_TRACK_VIEW_TOPIC_ID" => topic.id.to_s,
                "HTTP_DISCOURSE_TRACK_VIEW_SESSION_ID" => "deferred-session-123",
                "HTTP_USER_AGENT" => real_browser_agent,
              }
        end.to change { DiscoursePageVisits::PageVisit.count }.by(1)

        visit_record = DiscoursePageVisits::PageVisit.last
        expect(visit_record).to have_attributes(
          user_id: user.id,
          full_url: "http://test.localhost#{topic.relative_url}",
          session_id: "deferred-session-123",
        )
      end
    end

    context "with crawler user agent" do
      it "does not create a PageVisit record" do
        expect do
          get topic.relative_url,
              headers: {
                "HTTP_DISCOURSE_TRACK_VIEW" => "1",
                "HTTP_USER_AGENT" => crawler_agent,
              }
          expect(response.status).to eq(200)
        end.not_to change { DiscoursePageVisits::PageVisit.count }
      end

      it "does not create a PageVisit record with deferred track view" do
        expect do
          get "/message-bus/#{SecureRandom.hex}/poll",
              headers: {
                "HTTP_DISCOURSE_TRACK_VIEW_DEFERRED" => "1",
                "HTTP_USER_AGENT" => crawler_agent,
              }
        end.not_to change { DiscoursePageVisits::PageVisit.count }
      end
    end
  end
end
