# frozen_string_literal: true

module ::Autograder
  class LeaderboardsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

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
  end
end
