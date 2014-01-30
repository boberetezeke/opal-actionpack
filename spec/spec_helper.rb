if RUBY_ENGINE == "opal"
  require 'opal-rspec'
  require 'opal-actionpack'
else
  require_relative '../opal/action_pack/core'
end

module TestUnitHelpers
  def assert_equal actual, expected
    actual.should == expected
  end
end

RSpec.configure do |config|
  config.include TestUnitHelpers
end

