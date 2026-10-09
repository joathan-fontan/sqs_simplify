# frozen_string_literal: true

require_relative 'lib/sqs_simplify/version'

Gem::Specification.new do |spec|
  spec.name          = 'sqs_simplify'
  spec.version       = SqsSimplify::VERSION
  spec.authors       = ['Ralph Baesso', 'Nathan Meira', 'Joathan Fontan']
  spec.email         = ['ralphsbaesso@gmail.com', 'nathanmeira1@gmail.com', 'joathan.fontan@brobotbr.com.br']

  spec.summary       = 'Simple producers, consumers and jobs on top of Amazon SQS'
  spec.description   = 'Send, consume and schedule Amazon SQS messages with jobs, consumers, ' \
                       'dead letter queues, FIFO group ids and a worker command.'
  spec.homepage      = 'https://github.com/joathan-fontan/sqs_simplify'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 3.0.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'aws-sdk-sqs', '~> 1.0'
  spec.add_runtime_dependency 'parallel', '>= 1.20', '< 3'
end
