# frozen_string_literal: true

class AutograderSubmission < ActiveRecord::Base
  self.table_name = "autograder_submissions"

  belongs_to :user
  belongs_to :topic
  belongs_to :post
  belongs_to :upload, optional: true

  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :queued, -> { where(status: "queued") }

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end
end
