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
      load_leaderboard

      render template: "autograder/leaderboards/index", layout: false
    end

    def show
      load_leaderboard

      render json: {
        selected_category_id: @selected_category&.id,
        selected_category_name: @selected_category&.name || "종합",
        leaderboard: @individual,
        individual: @individual,
        teams: @teams,
      }
    end

    private

    def load_leaderboard
      @categories =
        Category
          .where(id: Leaderboard.target_category_ids)
          .order(:id)
          .to_a

      requested_category_id = params[:category_id].to_i
      @selected_category = @categories.find { |category| category.id == requested_category_id }

      @individual = Leaderboard.individual(category_id: @selected_category&.id)
      @teams = Leaderboard.teams(@individual)
    end

    def prepend_plugin_view_path
      prepend_view_path Rails.root.join("plugins", PLUGIN_NAME, "app", "views")
    end
  end
end
