# frozen_string_literal: true

RSpec.describe "Page Visits", type: :system do
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }

  let(:topic_page) { PageObjects::Pages::Topic.new }

  # Enable CSRF protection to test real-world behavior
  before { ActionController::Base.allow_forgery_protection = true }
  after { ActionController::Base.allow_forgery_protection = false }

  context "when user is authenticated" do
    before do
      SiteSetting.discourse_page_visits_enabled = true
      sign_in(current_user)
    end

    it "creates a page visit record when user leaves the page via visibilitychange" do
      topic_page.visit_topic(topic)

      # Manually trigger the visibility change event
      page.execute_script("Object.defineProperty(document, 'visibilityState', { value: 'hidden' })")
      page.execute_script("document.dispatchEvent(new Event('visibilitychange'))")

      try_until_success do
        visit_record = DiscoursePageVisits::PageVisit.last
        expect(visit_record).to have_attributes(
          user_id: current_user.id,
          topic_id: topic.id,
        )
        expect(visit_record.full_url).to include(topic.slug)
        expect(visit_record.visit_time).to be > 0
        expect(visit_record.visit_time).to be < 10_000 # Should be less than 10 seconds for test
      end
    end

    it "creates a page visit record when user leaves the page via pagehide event" do
      topic_page.visit_topic(topic)

      # Manually trigger the pagehide event (simulates tab close/browser back)
      page.execute_script("window.dispatchEvent(new Event('pagehide'))")

      try_until_success do
        visit_record = DiscoursePageVisits::PageVisit.last
        expect(visit_record).to have_attributes(
          user_id: current_user.id,
          topic_id: topic.id,
        )
        expect(visit_record.full_url).to include(topic.slug)
        expect(visit_record.visit_time).to be > 0
        expect(visit_record.visit_time).to be < 10_000 # Should be less than 10 seconds for test
      end
    end

    it "creates a page visit record when the user changes the page" do
      topic_page.visit_topic(topic)
      find("#site-logo").click

      try_until_success do
        visit_record = DiscoursePageVisits::PageVisit.last
        expect(visit_record).to have_attributes(
          user_id: current_user.id,
          topic_id: topic.id,
        )
        expect(visit_record.full_url).to include(topic.slug)
        expect(visit_record.visit_time).to be > 0
        expect(visit_record.visit_time).to be < 10_000 # Should be less than 10 seconds for test
      end
    end

    it "creates a page visit record for non-topic pages (homepage)" do
      visit "/"

      # Manually trigger the visibility change event
      page.execute_script("Object.defineProperty(document, 'visibilityState', { value: 'hidden' })")
      page.execute_script("document.dispatchEvent(new Event('visibilitychange'))")

      try_until_success do
        visit_record = DiscoursePageVisits::PageVisit.last
        expect(visit_record).to have_attributes(
          user_id: current_user.id,
          topic_id: nil,
        )
        expect(visit_record.full_url).to include("/")
        expect(visit_record.visit_time).to be > 0
        expect(visit_record.visit_time).to be < 10_000 # Should be less than 10 seconds for test
      end
    end

    it "does not log visit immediately on landing, but logs full time when navigating away" do
      initial_count = DiscoursePageVisits::PageVisit.count

      # Visit topic page - should not log immediately even if onPageChange fires multiple times
      topic_page.visit_topic(topic)

      # Wait a bit to ensure we've spent some time on the page (> 100ms threshold)
      sleep(0.2)

      # Verify no visit was logged immediately
      expect(DiscoursePageVisits::PageVisit.count).to eq(initial_count)

      # Navigate to another page - this should trigger the visit log
      visit "/"

      try_until_success do
        visit_record = DiscoursePageVisits::PageVisit.find_by(topic_id: topic.id)
        expect(visit_record).to be_present
        expect(visit_record).to have_attributes(
          user_id: current_user.id,
          topic_id: topic.id,
        )
        expect(visit_record.full_url).to include(topic.slug)
        # Visit time should be at least 200ms (the sleep time) minus some buffer
        expect(visit_record.visit_time).to be >= 100
        expect(visit_record.visit_time).to be < 10_000
      end

      # Verify only one visit was logged for this topic
      topic_visits = DiscoursePageVisits::PageVisit.where(topic_id: topic.id)
      expect(topic_visits.count).to eq(1)
    end
  end

  context "when user is not authenticated" do
    before { SiteSetting.discourse_page_visits_enabled = true }

    it "creates a page visit record when user leaves the page via visibilitychange" do

      topic_page.visit_topic(topic)

      # manually trigger the visibility change event
      page.execute_script("Object.defineProperty(document, 'visibilityState', { value: 'hidden' })")
      page.execute_script("document.dispatchEvent(new Event('visibilitychange'))")
      try_until_success do
        visit_record = DiscoursePageVisits::PageVisit.last
        expect(visit_record).to have_attributes(
          user_id: nil,
          topic_id: topic.id,
        )
        expect(visit_record.full_url).to include(topic.slug)
        expect(visit_record.visit_time).to be > 0
        expect(visit_record.visit_time).to be < 10_000 # Should be less than 10 seconds for test
      end
    end

    it "creates a page visit record for non-topic pages (homepage)" do
      visit "/"

      # Manually trigger the visibility change event
      page.execute_script("Object.defineProperty(document, 'visibilityState', { value: 'hidden' })")
      page.execute_script("document.dispatchEvent(new Event('visibilitychange'))")

      try_until_success do
        visit_record = DiscoursePageVisits::PageVisit.last
        expect(visit_record).to have_attributes(
          user_id: nil,
          topic_id: nil,
        )
        expect(visit_record.full_url).to include("/")
        expect(visit_record.visit_time).to be > 0
        expect(visit_record.visit_time).to be < 10_000 # Should be less than 10 seconds for test
      end
    end

    it "creates a page visit record when user leaves the page via pagehide event" do
      topic_page.visit_topic(topic)

      # Manually trigger the pagehide event (simulates tab close/browser back)
      page.execute_script("window.dispatchEvent(new Event('pagehide'))")

      try_until_success do
        visit_record = DiscoursePageVisits::PageVisit.last
        expect(visit_record).to have_attributes(
          user_id: nil,
          topic_id: topic.id,
        )
        expect(visit_record.full_url).to include(topic.slug)
        expect(visit_record.visit_time).to be > 0
        expect(visit_record.visit_time).to be < 10_000 # Should be less than 10 seconds for test
      end
    end

    it "creates a page visit record when the user changes the page" do
      topic_page.visit_topic(topic)

      # Wait for navigation to complete
      try_until_success do
        expect(page).to have_current_path("/t/#{topic.slug}/#{topic.id}")
      end

      find("#site-logo").click

      # Wait for navigation to complete
      try_until_success do
        expect(page).to have_current_path("/")
      end

      try_until_success do
        visit_record = DiscoursePageVisits::PageVisit.last
        expect(visit_record).to have_attributes(
          user_id: nil,
          topic_id: topic.id,
        )
        expect(visit_record.full_url).to include(topic.slug)
        expect(visit_record.visit_time).to be > 0
        expect(visit_record.visit_time).to be < 10_000 # Should be less than 10 seconds for test
      end
    end
  end
end
