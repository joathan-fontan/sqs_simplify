# frozen_string_literal: true

module SqsSimplify
  class Consumer < SqsSimplify::Base
    include SqsSimplify::ExecutionHook

    private_class_method :new
    attr_accessor :delete_sqs_message
    attr_reader :visibility_timeout, :errors

    def initialize(sqs_message, visibility_timeout)
      @sqs_message = sqs_message
      @message = load_message(sqs_message)
      @visibility_timeout = visibility_timeout
      self.delete_sqs_message = visibility_timeout.positive?
    end

    def perform
      raise 'Must implement this method'
    end

    def delete_sqs_message?
      delete_sqs_message
    end

    protected

    attr_reader :message, :sqs_message

    class << self
      def consume_messages(amount = nil, worker_size: nil, parallel_type: nil)
        amount ||= maximum_message_quantity
        @worker_size = worker_size.to_i
        @parallel_type = parallel_type

        visibility_timeout # load
        sqs_messages = fetch_messages(amount)
        consume_sqs_messages(sqs_messages, Time.now)
      rescue Exception => e
        call_hook :resolver_exception, e, sqs_messages
      ensure
        return sqs_messages&.count || 0
      end

      def message_not_deleted(&block)
        hooks[:message_not_deleted] = block
      end

      def around(&block)
        hooks[:around] = block
      end

      protected

      def maximum_message_quantity
        number = settings[:maximum_message_quantity].to_i
        number.positive? && number <= 10 ? number : 10
      rescue StandardError
        10
      end

      private

      def fetch_messages(amount = 10)
        client.receive_message(
          queue_url: queue_url,
          message_attribute_names: ['All'], # Receive all custom attributes.
          max_number_of_messages: amount, # Receive at most one message.
          wait_time_seconds: 0 # Do not wait to check for the message.
        ).messages
      end

      def consume_sqs_messages(sqs_messages, start_time)
        call_hook(:before_all, sqs_messages)
        benchmark { choose_process(sqs_messages, start_time) }
        call_hook(:after_all, sqs_messages)
      end

      def choose_process(messages, start_time)
        parallel_type, amount_processes = build_parallel_parameter(messages.size)

        logger.info "Started loop with: { queue_name: #{queue_name}, #{parallel_type}: #{amount_processes}, messages: #{messages.count} }"
        if amount_processes == 1
          messages.each { |sqs_message| consume_sqs_message(sqs_message, start_time) }
        else
          Parallel.each(messages, parallel_type => amount_processes) do |sqs_message|
            consume_sqs_message(sqs_message, start_time)
          end
        end
      end

      def build_parallel_parameter(messages_size)
        process_in_parallel = messages_size > 1 &&
                              @worker_size > 1 &&
                              %w[in_threads in_processes].include?(@parallel_type.to_s)

        process_in_parallel ? [@parallel_type, @worker_size] : [:without_parallel, 1]
      end

      def consume_sqs_message(sqs_message, start_time)
        time_left = build_time_left(start_time)
        consumer = new(sqs_message, time_left)
        call_hook(:before_each, consumer)

        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        Timeout.timeout(time_left, Errors::ExecutionExpired) do
          around.is_a?(Proc) ? around.call(consumer) : consumer.perform
        end
        raise Errors::ExecutionExpired if Process.clock_gettime(Process::CLOCK_MONOTONIC) - started >= time_left
      rescue Exception => e
        if consumer
          consumer.delete_sqs_message = false
          consumer.instance_variable_set :@errors, ["Exception: #{e.message}"] + e.backtrace
        end
        call_hook :resolver_exception, e, consumer
      ensure
        call_hook(:after_each, consumer)
        delete_message(consumer)
      end

      def build_time_left(start_time)
        time_left = visibility_timeout - (Time.now - start_time).to_f
        time_left = -0.1 if time_left.zero?
        [time_left, 0.1].max
      end

      def delete_message(consumer)
        if consumer&.delete_sqs_message
          delete_sqs_message(consumer.send(:sqs_message))
        else
          call_hook :message_not_deleted, consumer
        end
      end

      def delete_sqs_message(message)
        client.delete_message(
          queue_url: queue_url,
          receipt_handle: message.receipt_handle
        )
        true
      end

      def benchmark(&block)
        start_time = Time.now
        block.call
        logger.info "Finished in #{(Time.now - start_time).to_f} seconds"
      end

      def logger
        SqsSimplify.logger
      end
    end
  end
end
