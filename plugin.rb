# frozen_string_literal: true

# name: discourse-autograder
# about: CSV 자동채점 제출 이력과 개인·팀 랭킹을 관리합니다.
# version: 0.1
# authors: ahyeon

enabled_site_setting :autograder_enabled

module ::Autograder
  PLUGIN_NAME = "discourse-autograder"
end

require_relative "lib/autograder/engine"

after_initialize do
  require_relative "app/models/autograder_submission"
  require_relative "lib/autograder/leaderboard"
  require_relative "app/jobs/regular/autograder_grade_submission"

  require_dependency File.expand_path(
    "app/controllers/autograder/leaderboards_controller.rb",
    __dir__
  )

  DiscourseEvent.on(:post_created) do |post, *_args|
    next unless SiteSetting.autograder_enabled
    next if post.post_number == 1

    category_ids = [
      SiteSetting.autograder_liver_category_id.to_i,
      SiteSetting.autograder_lung_category_id.to_i,
    ].reject(&:zero?)

    next unless category_ids.include?(post.topic.category_id)

    csv_upload = post.uploads.find do |upload|
      upload.original_filename.to_s.downcase.end_with?(".csv")
    end

    next unless csv_upload

    submission = AutograderSubmission.create!(
      user_id: post.user_id,
      category_id: post.topic.category_id,
      topic_id: post.topic_id,
      post_id: post.id,
      upload_id: csv_upload.id,
      status: "queued",
      message: "채점 대기 중입니다.",
    )

    Jobs.enqueue(:autograder_grade_submission, submission_id: submission.id)
  rescue ActiveRecord::RecordNotUnique
    Rails.logger.info(
      "[autograder] post_id=#{post.id} 제출은 이미 처리 대기 중입니다.",
    )
  rescue StandardError => e
    Rails.logger.error(
      "[autograder] post_id=#{post.id} 제출 등록 실패: #{e.class}: #{e.message}",
    )
  end
end
