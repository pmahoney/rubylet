require 'minitest/autorun'
require 'minitest/matchers'

require 'rubylet/integration_test_case'

# A test runner that will run class methods +setup_suite+ and
# +teardown_suite+ before and after each test suite if the suite
# responds to those methods.
#
# If the suite responds to +:parameters+ then it will be run once with
# each permutation of parameters, which must be a hash of arrays.  One
# permutation, a hash of one permutation of the array values, will be
# passed to +setup_suite+.
#
# For example, parameters of +{ :p1 => [1,2,3], :p2 => ['a', 'b'] }+
# would result in six test runs being passed +{ :p1 => 1, :p2 => 'a'
# }+, +{ :p1 => 2, p2 => 'a' }+, and so on.
class RunnerWithSuiteSetupAndTeardown < MiniTest::Unit
  private
  alias :super_run_suite :_run_suite
  public

  def test_suite_header(suite)
    prefix = "\n" if @not_first
    @not_first = true
    if suite.respond_to? :params
      "#{prefix}running #{suite} with #{suite.params}"
    else
      "#{prefix}running #{suite}"
    end
  end

  def _run_suite(suite, type)
    if suite.respond_to?(:parameters)
      results = [0, 0]
      each_permutation(suite.parameters) do |params|
        tc, ac = run_suite_with_setup_teardown(suite, type, params)
        results[0] += tc
        results[1] += ac
      end
      results
    else
      run_suite_with_setup_teardown(suite, type)
    end
  end

  private

  def run_suite_with_setup_teardown(suite, type, *args)
    begin
      suite.setup_suite(*args) if suite.respond_to?(:setup_suite)
      super_run_suite(suite, type)
    ensure
      suite.teardown_suite if suite.respond_to?(:teardown_suite)
    end
  end

  def each_permutation(hash, &block)
    _each_permutation(hash.dup, &block)
  end

  def _each_permutation(hash)
    if kv = hash.shift
      key, values = kv
      _each_permutation(hash) do |params|
        values.each do |value|
          yield(params.merge(key => value))
        end
      end
    else
      yield({})
    end
  end
end

MiniTest::Unit.runner = RunnerWithSuiteSetupAndTeardown.new
