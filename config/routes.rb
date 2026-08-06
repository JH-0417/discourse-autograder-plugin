# frozen_string_literal: true

Autograder::Engine.routes.draw do
  get "/rankings" => "leaderboards#index"
  get "/leaderboard" => "leaderboards#show"
end

Discourse::Application.routes.draw do
  mount ::Autograder::Engine, at: "/autograder"
end
