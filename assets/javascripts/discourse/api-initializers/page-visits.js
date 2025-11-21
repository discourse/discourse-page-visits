import { ajax, updateCsrfToken } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import { withPluginApi } from "discourse/lib/plugin-api";

let pageVisitData = {};
let pageEnter;
let viewedPostIds = [];
let screenTrack;
let postStream;
let hasLoggedVisit = false;
let scrollListenerAttached = false;
let session;

export default {
  name: "page-visits",
  initialize() {
    withPluginApi((api) => {
      screenTrack = api.container.lookup("service:screen-track");
      session = api.container.lookup("service:session");
      const currentUser = api.getCurrentUser();
      const topicController = api.container.lookup("controller:topic");

      // capture when user leaves the page (tab switch, minimize, etc.)
      document.addEventListener("visibilitychange", () => {
        if (document.visibilityState === "hidden") {
          const useBeacon = true;
          const skipTimeCheck = true;
          flushVisitRecord(useBeacon, skipTimeCheck);
        }
      });

      // capture when page is being unloaded (tab close, browser back/forward)
      window.addEventListener("pagehide", () => {
        const useBeacon = true;
        const skipTimeCheck = true;
        flushVisitRecord(useBeacon, skipTimeCheck);
      });

      // Safari fallback - beforeunload sometimes works when pagehide doesn't
      window.addEventListener("beforeunload", () => {
        const useBeacon = true;
        const skipTimeCheck = true;
        flushVisitRecord(useBeacon, skipTimeCheck);
      });

      function setupScrollTracking(topicId, postStreamModel) {
        // Remove existing listener if any
        if (scrollListenerAttached) {
          window.removeEventListener("scroll", scroll);
          scrollListenerAttached = false;
        }

        // Add scroll listener if we're on a topic page
        if (topicId && postStreamModel) {
          postStream = postStreamModel;
          window.addEventListener("scroll", scroll, { passive: true });
          scrollListenerAttached = true;
        }
      }

      api.onPageChange(() => {
        // Log previous visit before navigating to new page
        const useBeacon = false;
        flushVisitRecord(useBeacon);

        const topicId = topicController.model?.id || null;
        const postStreamModel = topicController.model?.postStream;
        setupScrollTracking(topicId, postStreamModel);
        captureVisitData(currentUser?.id, topicId);
      });
    });
  },
};

function captureVisitData(userId, topicId) {
  const data = {
    userId: userId || null,
    fullUrl: window.location.href,
    topicId,
  };

  pageVisitData = data;
  // Initialize pageEnter when user lands on the page
  pageEnter = new Date();
  hasLoggedVisit = false;
}

function scroll() {
  discourseDebounce(this, captureOnScreenPosts, 100);
}

function captureOnScreenPosts() {
  screenTrack._readPosts.forEach((index) => {
    // screenTrack index is 1-based
    const postId = postStream.stream[index - 1];
    if (postId && !viewedPostIds.includes(postId)) {
      viewedPostIds.push(postId);
    }
  });
}

function flushVisitRecord(useBeacon, skipTimeCheck = false) {
  // Don't flush if we've already logged this visit or if there's no data
  if (hasLoggedVisit || Object.keys(pageVisitData).length === 0) {
    return;
  }

  // Don't flush if we just started tracking (pageEnter was just set)
  // This prevents logging visits immediately when onPageChange fires multiple times
  // Skip this check for visibility/pagehide events (skipTimeCheck = true)
  if (!skipTimeCheck && pageEnter) {
    const timeSincePageEnter = Date.now() - pageEnter.getTime();
    // If less than 100ms has passed, we're likely in a duplicate onPageChange call
    // Don't log yet - wait for the user to actually navigate away
    if (timeSincePageEnter < 100) {
      return;
    }
  }

  // Calculate visit time before resetting
  if (!pageEnter) {
    // Fallback: if pageEnter wasn't set, use current time minus a small buffer
    pageEnter = new Date(Date.now() - 1000);
  }
  const pageExitTime = new Date();
  const visitTimeMs = pageExitTime - pageEnter;

  // Save current state before resetting (so we can capture new page data immediately)
  const savedPageData = { ...pageVisitData };
  const savedPostIds = [...viewedPostIds];

  // Mark as logged BEFORE resetting to prevent duplicate logs
  hasLoggedVisit = true;

  // Reset state immediately so we can start tracking the new page
  reset();

  // Log the saved visit asynchronously
  createPageVisitRecord(savedPageData, savedPostIds, visitTimeMs, useBeacon);
}

async function createPageVisitRecord(data, postIds, time, useBeacon = false) {
  const payload = {
    user_id: data.userId,
    full_url: data.fullUrl,
    topic_id: data.topicId,
    post_ids: postIds,
    visit_time: time,
  };

  if (useBeacon && navigator.sendBeacon) {
    // Use sendBeacon for reliable delivery during page unload
    // FormData is the most reliable format for sendBeacon

    // Ensure CSRF token is available before sending
    if (!session?.csrfToken) {
      await updateCsrfToken();
    }

    const formData = createFormDataFromPayload(payload, session?.csrfToken);
    const url = new URL("/page-visits.json", window.location.origin);
    navigator.sendBeacon(url.toString(), formData);
  } else {
    // Use ajax for normal page navigation (more reliable, can handle errors)
    try {
      await ajax("/page-visits.json", {
        type: "POST",
        data: payload,
      });
    } catch {
      // If ajax fails and we're unloading, fallback to sendBeacon
      if (navigator.sendBeacon) {

        // Ensure CSRF token is available
        if (!session?.csrfToken) {
          await updateCsrfToken();
        }

        const formData = createFormDataFromPayload(payload, session?.csrfToken);
        const url = new URL("/page-visits.json", window.location.origin);
        navigator.sendBeacon(url.toString(), formData);
      }
    }
  }
}

function createFormDataFromPayload(payload, csrfToken) {
  const formData = new FormData();

  if (csrfToken) {
    formData.append("authenticity_token", csrfToken);
  }

  if (payload.user_id !== null && payload.user_id !== undefined) {
    formData.append("user_id", payload.user_id);
  }
  if (payload.full_url) {
    formData.append("full_url", payload.full_url);
  }
  if (payload.topic_id !== null && payload.topic_id !== undefined) {
    formData.append("topic_id", payload.topic_id);
  }
  if (Array.isArray(payload.post_ids) && payload.post_ids.length > 0) {
    payload.post_ids.forEach((postId) => {
      formData.append("post_ids[]", postId);
    });
  }
  if (payload.visit_time !== null && payload.visit_time !== undefined) {
    formData.append("visit_time", payload.visit_time);
  }
  return formData;
}

function reset() {
  if (scrollListenerAttached) {
    window.removeEventListener("scroll", scroll);
    scrollListenerAttached = false;
  }
  viewedPostIds = [];
  pageEnter = null;
  pageVisitData = {};
  hasLoggedVisit = false;
  postStream = null;
}
