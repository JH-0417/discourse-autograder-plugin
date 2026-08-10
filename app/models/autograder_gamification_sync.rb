# frozen_string_literal: true

class AutograderGamificationSync < ActiveRecord::Base
  self.table_name = "autograder_gamification_syncs"

  belongs_to :user
end
