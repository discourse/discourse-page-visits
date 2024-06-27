# frozen_string_literal: true

RSpec.describe "Page Visits", type: :system do
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:topic_2) { Fabricate(:topic) }
  fab!(:topic_2_post) { Fabricate(:post, topic: topic_2) }
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }

  let(:topic_page) { PageObjects::Pages::Topic.new }

  context "when user is authenticated" do
    before { SiteSetting.discourse_page_visits_enabled = true }

    it "creates a page visit record when user leaves the page" do
      sign_in current_user
      topic_page.visit_topic(topic)

      expect {
        # manually trigger the visibility change event
        page.execute_script(
          "Object.defineProperty(document, 'visibilityState', { value: 'hidden' })",
        )
        page.execute_script("document.dispatchEvent(new Event('visibilitychange'))")
        sleep 1 # wait for the page visit to be captured asynchronously
      }.to change(DiscoursePageVisits::PageVisit, :count).by(1)

      expect(DiscoursePageVisits::PageVisit.last).to have_attributes(
        user_id: current_user.id,
        full_url: topic.url,
        topic_id: topic.id,
      )
    end

    it "creates a page visit record when the user changes the page" do
      sign_in current_user
      topic_page.visit_topic(topic)

      expect {
        topic_page.visit_topic(topic_2)
        sleep 1 # wait for the page visit to be captured asynchronously
      }.to change(DiscoursePageVisits::PageVisit, :count).by(1)

      expect(DiscoursePageVisits::PageVisit.last).to have_attributes(
        user_id: current_user.id,
        full_url: topic.url,
        topic_id: topic.id,
      )
    end
  end

  context "when user is not authenticated" do
    before { SiteSetting.discourse_page_visits_enabled = true }

    it "creates a page visit record when user leaves the page" do
      topic_page.visit_topic(topic)

      expect {
        # manually trigger the visibility change event
        page.execute_script(
          "Object.defineProperty(document, 'visibilityState', { value: 'hidden' })",
        )
        page.execute_script("document.dispatchEvent(new Event('visibilitychange'))")
        sleep 1 # wait for the page visit to be captured asynchronously
      }.to change(DiscoursePageVisits::PageVisit, :count).by(1)

      expect(DiscoursePageVisits::PageVisit.last).to have_attributes(
        user_id: nil,
        full_url: topic.url,
        topic_id: topic.id,
      )
    end

    it "creates a page visit record when the user changes the page" do
      topic_page.visit_topic(topic)

      expect {
        topic_page.visit_topic(topic_2)
        # sleep 1 # wait for the page visit to be captured asynchronously
      }.to change(DiscoursePageVisits::PageVisit, :count).by(1)

      expect(DiscoursePageVisits::PageVisit.last).to have_attributes(
        user_id: nil,
        full_url: topic.url,
        topic_id: topic.id,
      )
    end
  end
end
