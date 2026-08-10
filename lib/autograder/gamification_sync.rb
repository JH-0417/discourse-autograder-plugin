# frozen_string_literal: true

module Autograder
  class GamificationSync
    DESCRIPTION = "Auto Grader 대회 점수 (자동 동기화)"

    def self.call(user)
      return unless SiteSetting.discourse_gamification_enabled
      return unless defined?(DiscourseGamification::GamificationScoreEvent)

      row = Leaderboard.individual.find { |leaderboard_row| leaderboard_row[:user_id] == user.id }
      points = row ? row[:total_score].to_f.round : 0

      sync = AutograderGamificationSync.find_or_initialize_by(user_id: user.id)

      event =
        DiscourseGamification::GamificationScoreEvent.find_by(
          id: sync.gamification_score_event_id,
        )

      event ||= DiscourseGamification::GamificationScoreEvent.new

      event.assign_attributes(
        user_id: user.id,
        date: Date.current,
        points: points,
        description: DESCRIPTION,
      )
      event.save!

      sync.update!(
        gamification_score_event_id: event.id,
        points: points,
      )
    rescue StandardError => e
      Rails.logger.error(
        "[autograder] gamification sync failed for user_id=#{user.id}: #{e.class}: #{e.message}",
      )
    end
  end
end
