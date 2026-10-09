# frozen_string_literal: true

RSpec.describe SqsSimplify::Consumer do
  context 'instance methods' do
    context '#consume_messages' do
      before do
        SqsSimplify.settings.faker = false
        allow(ConsumerExample).to receive(:queue_url).and_return('https://aws.amazon.com')
        allow_any_instance_of(Aws::SQS::Types::ReceiveMessageResult)
          .to receive(:messages).and_return(build_messages)
      end

      after do
        SqsSimplify.settings.faker = true
      end

      it 'must return messages' do
        messages = ConsumerExample.send :fetch_messages
        expect(messages.count).to eq(5)

        consumer = ConsumerExample.send(:new, messages.first, 1)
        expect { consumer.perform }
          .to raise_error('Must implement this method')

        response = ConsumerExample.send(:delete_sqs_message, messages.first)
        expect(response).to eq(true)
      end
    end
  end

  context 'when the message runs out of time' do
    let(:sqs_message) { OpenStruct.new(body: { text: 'slow' }.to_json, receipt_handle: 'handle') }

    before do
      allow(ConsumerExample).to receive(:visibility_timeout).and_return(0.2)
      allow(ConsumerExample).to receive(:delete_sqs_message)
    end

    after { JobExample.errors.clear }

    def consume
      ConsumerExample.send(:consume_sqs_message, sqs_message, Time.now)
    end

    it 'must interrupt the perform with an exception so an open transaction rolls back' do
      seen = nil
      allow_any_instance_of(ConsumerExample).to receive(:perform) do
        sleep 1
      rescue Exception => e
        seen = e
        raise
      end

      consume

      expect(seen).to be_a(SqsSimplify::Errors::ExecutionExpired)
      expect(ConsumerExample).not_to have_received(:delete_sqs_message)
    end

    it 'must keep the message when the perform swallows the timeout' do
      allow_any_instance_of(ConsumerExample).to receive(:perform) do
        sleep 1
      rescue Exception
        nil
      end

      consume

      expect(ConsumerExample).not_to have_received(:delete_sqs_message)
    end

    it 'must delete the message when the perform finishes in time' do
      allow_any_instance_of(ConsumerExample).to receive(:perform)

      consume

      expect(ConsumerExample).to have_received(:delete_sqs_message).with(sqs_message)
    end
  end

  context 'class methods' do
    context '.amount_processes' do
      it do
        expect(ConsumerExample.send(:amount_processes)).to be_nil

        ConsumerExample.set :amount_processes, 10
        expect(ConsumerExample.send(:amount_processes)).to eq(10)
      end
    end

    context '.consume_messages' do
      before do
        ConsumerExample.instance_variable_set :@client, nil
      end
      after do
        ConsumerExample.instance_variable_set :@client, nil
      end

      it 'must return 0 without messages' do
        expect(ConsumerExample.send(:consume_messages)).to eq(0)
      end
    end

    context '.maximum_message_quantity' do
      after do
        ConsumerExample.set :maximum_message_quantity, nil
      end

      it 'must return the chosen number' do
        number = rand(1..10)
        ConsumerExample.set :maximum_message_quantity, number
        expect(ConsumerExample.send(:maximum_message_quantity)).to eq(number)
      end

      it 'must return number 10 to invalid option' do
        [-1, 11, :a, 'b', nil].each do |number|
          ConsumerExample.set :maximum_message_quantity, number
          expect(ConsumerExample.send(:maximum_message_quantity)).to eq(10)
        end
      end
    end
  end

  private

  def build_messages
    messages = []
    5.times do |index|
      messages << OpenStruct.new(
        body: { text: index }.to_json,
        receipt_handle: index.to_s,
        message_attributes: {}
      )
    end
    messages
  end
end
