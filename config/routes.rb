# frozen_string_literal: true

DiscoursePageVisits::Engine.routes.draw do
  post "/page_visits" => "page_visits#create"
end

Discourse::Application.routes.draw { mount ::DiscoursePageVisits::Engine, at: "discourse-page-visits" }
