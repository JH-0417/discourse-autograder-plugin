# frozen_string_literal: true

module ::Autograder
  class LeaderboardsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    skip_before_action :preload_json,
                       :check_xhr,
                       :redirect_to_login_if_required,
                       :redirect_to_profile_if_required,
                       only: %i[index show]

    before_action :prepend_plugin_view_path, only: :index

    def index
      @individual = Leaderboard.individual
      @teams = Leaderboard.teams(@individual)

      render template: "autograder/leaderboards/index", layout: false
    end

    def show
      individual = Leaderboard.individual

      render json: {
        leaderboard: individual,
        individual: individual,
        teams: Leaderboard.teams(individual),
      }
    end

    private

    def prepend_plugin_view_path
      prepend_view_path Rails.root.join("plugins", PLUGIN_NAME, "app", "views")
    end
  end
end
