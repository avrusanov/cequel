require File.expand_path('../environment', __dir__)
require 'cequel'
require 'tzinfo'
require 'pp'

Dir.glob(File.expand_path('../support/**/*.rb', __dir__)).sort.each do |file|
  require file
end
Dir.glob(File.expand_path('../shared/**/*.rb', __dir__)).sort.each do |file|
  require file
end

RSpec.configure do |config|
  config.include(Cequel::SpecSupport::Helpers)
  config.extend(Cequel::SpecSupport::Macros)

  {
    rails: ActiveSupport::VERSION::STRING,
    cql: Cequel::SpecSupport::Helpers.cql_version
  }.each do |tag, actual_version|
    config.filter_run_excluding tag => lambda { |required_version|
      !Gem::Requirement.new(required_version)
                       .satisfied_by?(Gem::Version.new(actual_version))
    }
  end

  unless defined? CassandraCQL
    config.filter_run_excluding thrift: true
  end

  config.before(:all) do
    cequel.schema.create!
    Cequel::Record.connection = cequel
    Time.zone = 'UTC'
    I18n.enforce_available_locales = false
    SafeYAML::OPTIONS[:default_mode] = :safe if defined? SafeYAML
  end

  config.after(:all) do
    cequel.schema.drop!
  end

  config.after { Timecop.return }

  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
  config.order = "random"

  config.verbose_retry = true
  config.default_retry_count = 0
end

# rubocop:disable Lint/Debugger
if defined? byebug
  Kernel.module_eval { alias_method :debugger, :byebug }
end
# rubocop:enable Lint/Debugger
