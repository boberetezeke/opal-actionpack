if RUBY_ENGINE == "opal"
  require 'opal-rspec'
  require 'opal-actionpack'
else
  $:.insert(0, "opal")

  #$:.insert(0, $:.select{|s| s =~ /activesupport/}.first.gsub(/lib/, "opal"))

  require "active_support/all"
  require "action_pack"
end

module TestUnitHelpers
  def assert_equal actual, expected
    actual.should == expected
  end
end

class SimpleAppender < SemanticLogger::Subscriber
  def initialize(level=nil, &block)
    # Set the log level and formatter if supplied
    super(level, &block)
  end

  # Display the log struct and the text formatted output
  def log(log)
    # Ensure minimum log level is met, and check filter
    return false if (level_index > (log.level_index || 0)) || !include_message?(log)

    # Display the raw log structure
    # p log

    # Display the formatted output
    # puts formatter.call(log, self)
    puts log.message
  end
end


RSpec.configure do |config|
  config.include TestUnitHelpers

  SemanticLogger.default_level = :info
  SemanticLogger.add_appender(appender: SimpleAppender.new)
end

