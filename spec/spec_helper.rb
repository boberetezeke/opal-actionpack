if RUBY_ENGINE == "opal"
  require 'opal-rspec'
  require 'opal-actionpack'
else
  $:.insert(0, "opal")
  require("action_pack")
end

module TestUnitHelpers
  def assert_equal actual, expected
    actual.should == expected
  end
end

RSpec.configure do |config|
  config.include TestUnitHelpers
end

