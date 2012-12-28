require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/matchers'

require 'rubylet/integration_test_case'

# A test runner that will run class methods +setup_suite+ and
# +teardown_suite+ before and after each test suite if the suite
# responds to those methods.
class RunnerWithSuiteSetupAndTeardown < MiniTest::Unit
  def _run_suite(suite, type)
    begin
      suite.setup_suite if suite.respond_to?(:setup_suite)
      super(suite, type)
    ensure
      suite.teardown_suite if suite.respond_to?(:teardown_suite)
    end
  end
end

MiniTest::Unit.runner = RunnerWithSuiteSetupAndTeardown.new
