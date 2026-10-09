# frozen_string_literal: true

require 'aws-sdk-sqs'
require 'fileutils'
require 'json'
require 'logger'
require 'ostruct'
require 'parallel'
require 'pathname'
require 'timeout'

require 'sqs_simplify/execution_hook'
require 'sqs_simplify/client'
require 'sqs_simplify/base'

require 'sqs_simplify/command'
require 'sqs_simplify/consumer'
require 'sqs_simplify/faker_client'

require 'sqs_simplify/message'
require 'sqs_simplify/scheduler'
require 'sqs_simplify/version'

require 'sqs_simplify/worker'
require 'sqs_simplify/job'
require 'sqs_simplify/dead_queue'

require 'sqs_simplify/errors/execution_expired'
require 'sqs_simplify/errors/non_existent_queue'
require 'sqs_simplify/errors/reserved_method_name'

module SqsSimplify
  include SqsSimplify::ExecutionHook

  add_hook :message_not_deleted, :after_fork

  class << self
    def configure
      block_given? ? yield(settings) : settings
    end

    def settings
      @settings ||= OpenStruct.new(
        hooks: self,
        worker: self::Worker,
        root: Pathname.new(Dir.pwd)
      )
    end

    def consumers
      @consumers ||= []
    end

    def schedulers
      @schedulers ||= []
    end

    def logger
      return @logger if @logger

      path = settings.log_dir || "#{settings.root}/log"
      FileUtils.mkdir_p(path) unless File.directory?(path)
      @logger = Logger.new("#{path}/sqs_simplify.log")
    end
  end

  class Error < StandardError; end
end
