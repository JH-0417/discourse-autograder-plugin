# frozen_string_literal: true

module ::Autograder
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace Autograder
  end
end
