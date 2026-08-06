# frozen_string_literal: true

require "json"
require "net/http"

module Jobs
  class AutograderGradeSubmission < ::Jobs::Base
    def execute(args)
      submission = AutograderSubmission.find(args[:submission_id])
      endpoint = SiteSetting.autograder_grader_url

      raise "채점 서버 주소가 설정되지 않았습니다." if endpoint.blank?

      submission.update!(
        status: "processing",
        message: "CSV 파일을 채점하고 있습니다.",
      )

      post = submission.post

      payload = {
        post: {
          id: post.id,
          topic_id: post.topic_id,
          user_id: post.user_id,
          post_number: post.post_number,
          cooked: post.cooked,
        },
      }

      uri = URI.parse(endpoint)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["X-Discourse-Event"] = "post_created"
      request.body = JSON.generate(payload)

      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: 10,
        read_timeout: 120,
      ) do |http|
        http.request(request)
      end

      result = JSON.parse(response.body.presence || "{}")

      unless response.is_a?(Net::HTTPSuccess)
        raise "채점 서버 오류 (HTTP #{response.code}): #{result}"
      end

      submission.update!(
        status: "completed",
        score: result["final_score"],
        auc: result["auc"],
        precision_score: result["precision"],
        brier_score: result["brier"],
        message: result["status"] || "채점 완료",
        result_data: result,
      )

      publish_result_comment(post, submission)
    rescue StandardError => e
      submission&.update(
        status: "failed",
        message: "채점 실패: #{e.message}",
      )

      Rails.logger.error(
        "[autograder] submission_id=#{args[:submission_id]} 채점 실패: #{e.class}: #{e.message}",
      )

      raise
    end

    private

    def publish_result_comment(post, submission)
      raw = <<~MARKDOWN
        ## 자동채점 결과

        - 제출자: @#{post.user.username}
        - AUC: #{format('%.4f', submission.auc.to_f)}
        - Precision: #{format('%.4f', submission.precision_score.to_f)}
        - Brier score: #{format('%.4f', submission.brier_score.to_f)}
        - 종합 점수: **#{format('%.4f', submission.score.to_f)}**
      MARKDOWN

      PostCreator.create!(
        Discourse.system_user,
        topic_id: post.topic_id,
        reply_to_post_number: post.post_number,
        raw: raw,
      )
    rescue StandardError => e
      Rails.logger.error(
        "[autograder] submission_id=#{submission.id} 결과 댓글 작성 실패: #{e.class}: #{e.message}",
      )
    end
  end
end
