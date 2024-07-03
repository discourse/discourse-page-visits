import { ajax } from "discourse/lib/ajax";
import { withPluginApi } from "discourse/lib/plugin-api";
import discourseDebounce from "discourse-common/lib/debounce";

let pageVisitData = {};
let pageEnter;
let pageExit;
let visitTime;
let viewedPostIds = [];
let screenTrack;
let postStream;

export default {
  name: "page-visits",
  initialize() {
    withPluginApi("1.24.0", (api) => {
      screenTrack = api.container.lookup("service:screen-track");
      const currentUser = api.getCurrentUser();
      const topicController = api.container.lookup("controller:topic");

      // capture when user leaves the page
      document.addEventListener("visibilitychange", () => {
        if (document.visibilityState === "hidden") {
          if (Object.keys(pageVisitData).length > 0) {
            setVisitTime();
            createPageVisitRecord(pageVisitData, viewedPostIds, visitTime);
            reset();
          }
        }
      });

      api.onPageChange(() => {
        if (Object.keys(pageVisitData).length > 0) {
          setVisitTime();
          createPageVisitRecord(pageVisitData, viewedPostIds, visitTime);
          reset();
        }

        const topicId = topicController.model?.id || null;
        postStream = topicController.model?.postStream;
        if (topicId && postStream) {
          window.addEventListener("scroll", scroll, { passive: true });
        }

        captureVisitData(currentUser?.id, topicId);
      });
    });
  },
};

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

async function createPageVisitRecord(data, postIds, time) {
  await ajax("/page-visits.json", {
    type: "POST",
    data: {
      user_id: data.userId,
      full_url: data.fullUrl,
      user_agent: data.userAgent,
      topic_id: data.topicId,
      post_ids: postIds,
      visit_time: time,
    },
  });
}

function captureVisitData(userId, topicId) {
  const data = {
    userId: userId || null,
    fullUrl: window.location.href,
    userAgent: navigator.userAgent,
    topicId,
  };

  pageVisitData = data;
}

function reset() {
  window.removeEventListener("scroll", scroll);
  viewedPostIds = [];
  pageEnter = new Date();
  pageExit = null;
  visitTime = null;
  pageVisitData = {};
}

function setVisitTime() {
  pageExit = new Date();
  visitTime = pageExit - pageEnter;
}
