import { withPluginApi } from "discourse/lib/plugin-api";
import { ajax } from "discourse/lib/ajax";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { tracked } from "@glimmer/tracking";
import { run } from "@ember/runloop";
import { schedule } from "@ember/runloop";
import discourseDebounce from "discourse-common/lib/debounce";

let pageVisitData = {};
let timer = 0;
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

      api.onPageChange((route) => {
        if (Object.keys(pageVisitData).length > 0) {
          createPageVisitRecord(pageVisitData, viewedPostIds, timer);
        }

        reset();
        startTimer();

        const topicId = topicController.model?.id || null;
        postStream = topicController.model?.postStream;
        console.log(topicController.model);
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
    // screen track index is 1-based
    const postId = postStream.stream[index - 1];
    if (postId && !viewedPostIds.includes(postId)) {
      viewedPostIds.push(postId);
    }
  });
}

function reset() {
  window.removeEventListener("scroll", scroll);
  viewedPostIds = [];
  clearInterval(timer);
  timer = 0;
}

function startTimer() {
  setInterval(() => {
    run(() => tickTimer());
  }, 1000);
}

function tickTimer() {
  timer += 1000;
}

function captureVisitData(userId, topicId) {
  const data = {
    userId: userId || null,
    fullUrl: window.location.href,
    userAgent: navigator.userAgent,
    topicId: topicId,
  };

  pageVisitData = data;
}

function resetPageVisitData() {
  pageVisitData = {};
}

async function createPageVisitRecord(data, postIds, timer) {
  try {
    await ajax("/page_visits", {
      type: "POST",
      data: {
        user_id: data.userId,
        full_url: data.fullUrl,
        user_agent: data.userAgent,
        topic_id: data.topicId || null,
        post_ids: postIds,
        visit_time: timer,
      },
    });
  } catch (e) {
    console.error(e);
  } finally {
    resetPageVisitData();
  }
}
