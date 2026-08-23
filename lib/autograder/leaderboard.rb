# frozen_string_literal: true

module Autograder
  class Leaderboard
    def self.target_category_ids
      SiteSetting.autograder_category_ids
        .to_s
        .split("|")
        .map(&:to_i)
        .reject(&:zero?)
    end

    def self.individual(category_id: nil)
      target_category_ids = self.target_category_ids
      selected_category_id = category_id.to_i if category_id.present?
      return [] if selected_category_id && !target_category_ids.include?(selected_category_id)

      ranking_category_ids = selected_category_id ? [selected_category_id] : target_category_ids

      completed_submissions =
        AutograderSubmission
          .completed
          .joins(:topic)
          .where(topics: { category_id: ranking_category_ids })
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

            participated_category_count =
              (category_ids & target_category_ids).length

            participation_bonus =
              if selected_category_id
                0.0
              else
                [participated_category_count - 1, 0].max *
                  SiteSetting.autograder_additional_category_bonus.to_f
              end

            {
              user_id: user_id,
              username: user.username,
              score: score.round(2),
              bonus: participation_bonus.round(2),
              total_score: (score + participation_bonus).round(2),
              solved_topics: submissions.map(&:topic_id).uniq.count,
              category_ids: category_ids,
            }
          end
          .sort_by { |row| [-row[:total_score], -row[:solved_topics], row[:username]] }

      rows.each_with_index.map do |row, index|
        row.merge(rank: index + 1)
      end
    end

    def self.teams(individual_rows = individual)
      return [] if individual_rows.empty?

      affiliations =
        UserCustomField
          .where(
            user_id: individual_rows.map { |row| row[:user_id] },
            name: "affiliation",
          )
          .pluck(:user_id, :value)
          .to_h

      rows =
        individual_rows
          .group_by do |row|
            affiliation = affiliations[row[:user_id]].to_s.strip
            affiliation.presence || row[:username]
          end
          .map do |team_name, members|
            {
              team_name: team_name,
              members: members.map { |member| member[:username] }.sort,
              member_count: members.length,
              score: members.sum { |member| member[:score].to_f }.round(2),
              bonus: members.sum { |member| member[:bonus].to_f }.round(2),
              total_score: members.sum { |member| member[:total_score].to_f }.round(2),
              solved_topics: members.sum { |member| member[:solved_topics].to_i },
            }
          end
          .sort_by do |row|
            [-row[:total_score], -row[:solved_topics], row[:team_name]]
          end

      rows.each_with_index.map do |row, index|
        row.merge(rank: index + 1)
      end
    end
  end
end
