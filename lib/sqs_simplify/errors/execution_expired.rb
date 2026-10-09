# frozen_string_literal: true

module SqsSimplify
  module Errors
    class ExecutionExpired < ::Timeout::Error
      def initialize(message = 'execution expired')
        super
      end
    end
  end
end
