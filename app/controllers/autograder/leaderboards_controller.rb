# frozen_string_literal: true

module ::Autograder
  class LeaderboardsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    def show
      render json: {
        leaderboard: Leaderboard.individual,
      }
    end
  end
end
