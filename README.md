# discourse-page-visits

## Project History

| Description               | Internal Topic                                   | Contributors |
| ------------------------- | ------------------------------------------------ | ------------ |
| Comprehensive page visit tracking and analytics system for Discourse | [project topic](https://dev.discourse.org/t/wix-data-dev-52-hours/131628/) | @discourse   |

## Major Custom Features

### 1. Comprehensive Page Visit Tracking System

**Summary (non-technical):**
Tracks detailed analytics about how users interact with pages on the Discourse site. Records time spent on pages, which posts were viewed, and visit patterns for both logged-in and anonymous users. Provides reliable tracking even when users close tabs or navigate away quickly.

**Technical description:**
Implements client-side page visit tracking using multiple event handlers (visibilitychange, pagehide, onPageChange) to ensure visits are logged reliably. Tracks visit duration, viewed post IDs via scroll tracking integration with screen-track service, and captures full URL, IP address, and user agent. Uses sendBeacon API for reliable delivery during page unload events. Includes duplicate prevention logic with timing checks to avoid logging visits immediately on page load. Stores visit data in page_visits table with support for both authenticated and anonymous users.

### 2. Post-Level View Tracking

**Summary (non-technical):**
Tracks which specific posts within a topic were actually viewed by users as they scroll through content. This provides granular analytics about post engagement beyond just topic-level visits.

**Technical description:**
Integrates with Discourse's screen-track service to monitor scroll position and identify which posts are currently visible on screen. Uses debounced scroll event handlers to efficiently capture viewed post IDs. Stores post IDs as an array in the page_visits record, allowing analysis of which posts received the most attention during a visit.

### 3. Reliable Visit Capture Across Navigation Scenarios

**Summary (non-technical):**
Ensures that page visits are accurately recorded regardless of how users leave a page - whether they navigate to another page, close the tab, switch browser tabs, or use browser back/forward buttons. This provides complete analytics coverage without missing data.

**Technical description:**
Implements multiple event listeners to capture visits in all scenarios: onPageChange for normal navigation, visibilitychange for tab switches/minimization, and pagehide for tab closure and browser navigation. Uses sendBeacon API for visibilitychange and pagehide events to ensure data is sent even during page unload. Falls back to standard AJAX for normal navigation with error handling. Includes timing validation to prevent duplicate logging from rapid page changes.
