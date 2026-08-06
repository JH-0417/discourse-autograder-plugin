# frozen_string_literal: true

module Autograder
  class Leaderboard
    def self.individual
      target_category_ids = [
        SiteSetting.autograder_liver_category_id.to_i,
        SiteSetting.autograder_lung_category_id.to_i,
      ].reject(&:zero?)

      completed_submissions =
        AutograderSubmission
          .completed
          .where(category_id: target_category_ids)
          .includes(:user)
          .to_a

      best_submissions =
        completed_submissions
          .group_by { |submission| [submission.user_id, submission.topic_id] }
          .values
          .map { |submissions| submissions.max_by { |submission| submission.score.to_f } }

      rows =
        best_submissions
          .group_by(&:user_id)
          .map do |user_id, submissions|
            user = submissions.first.user
            category_ids = submissions.map(&:category_id).uniq
            score = submissions.sum { |submission| submission.score.to_f * 100 }

            dual_bonus =
              (category_ids & target_category_ids).length == 2 ?
                SiteSetting.autograder_dual_participation_bonus.to_f : 0.0

            {
              user_id: user_id,
              username: user.username,
              score: score.round(2),
              bonus: dual_bonus,
              total_score: (score + dual_bonus).round(2),
              solved_topics: submissions.map(&:topic_id).uniq.count,
              category_ids: category_ids,
            }
          end
          .sort_by { |row| [-row[:total_score], -row[:solved_topics], row[:username]] }

      rows.each_with_index.map do |row, index|
        row.merge(rank: index + 1)
      end
    end
  end
end
