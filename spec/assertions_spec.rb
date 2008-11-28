require File.expand_path('spec_helper', File.dirname(__FILE__))

module AssertionsSpecHelper
  def do_success(&block)
    do_assertion(@success_values.first, &block)
  end
  def do_failure(&block)
    do_assertion(@failure_values.first, &block)
  end
end

describe "any assertion", :shared => true do
  it "on failure, should raise an exception with trimmed backtrace" do
    begin
      do_failure
    rescue AssertionFailureError => e
      e.backtrace.first.should include(__FILE__)
    end
  end
end

describe "a basic assertion", :shared => true do
  it "should raise AssertionFailureError when it fails" do
    @failure_values.each do |value|
      lambda do
        do_assertion(value)
      end.should raise_error(AssertionFailureError)
    end
  end

  it "should not raise an exception when it succeeds" do
    @success_values.each do |value|
      lambda do
        do_assertion(value)
      end.should_not raise_error
    end
  end

  it "should return its argument on success" do
    @success_values.each do |value|
      do_assertion(value).should equal(value)
    end
  end

end

describe "an assertion taking a block", :shared => true do
  it "should fail if the block result is not true" do
    lambda do
      do_success { false }
    end.should raise_error(AssertionFailureError)
  end
end

describe "an assertion yielding passed values", :shared => true do

  it_should_behave_like "an assertion taking a block"

  it "should yield values that pass the test" do
    @success_values.each do |value|
      did_yield = false
      do_assertion(value) do |yielded_value|
        did_yield = true
        yielded_value.should equal(value)
        true
      end
      did_yield.should be_true
    end
  end

  it "should not yield values that fail the test" do
    @failure_values.each do |value|
      did_yield = false
      lambda do
        do_assertion(value) do |yielded_value|
          did_yield = true
        end
      end.should raise_error(AssertionFailureError)
      did_yield.should be_false
    end
  end

end

describe "an assertion taking multiple values", :shared => true do
  def gather_arguments(values)
    args = []
    # gather 3 arguments
    3.times do |i|
      args[i] = values[i % values.size]
    end
    args
  end

  it "should not raise error if all values succeed test" do
    values = gather_arguments(@success_values)
    lambda { do_assertion(*values) }.should_not raise_error
  end

  it "should raise error if all values fail test" do
    values = gather_arguments(@failure_values)
    lambda { do_assertion(*values) }.should raise_error(AssertionFailureError)
  end

  it "should raise error if one values fails test" do
    values = gather_arguments(@success_values)
    values[1] = @failure_values.first
    lambda { do_assertion(*values) }.should raise_error(AssertionFailureError)
  end

  it "should return the last argument on success" do
    values = gather_arguments(@success_values)
    do_assertion(*values).should equal(values.last)
  end

end

describe Assertions, "#assert" do

  include Assertions
  include AssertionsSpecHelper

  def do_assertion(*args, &block)
    assert(*args, &block)
  end

  before :each do
    @success_values      = [true, "", 0]
    @failure_values      = [false, nil]
  end

  it_should_behave_like "any assertion"
  it_should_behave_like "a basic assertion"
  it_should_behave_like "an assertion taking multiple values"
  it_should_behave_like "an assertion yielding passed values"
end

describe Assertions, "#assert_exists" do

  include Assertions
  include AssertionsSpecHelper

  def do_assertion(*args, &block)
    assert_exists(*args, &block)
  end

  before :each do
    @success_values = ["foo", 123, false]
    @failure_values = [nil]
  end

  it_should_behave_like "any assertion"
  it_should_behave_like "a basic assertion"
  it_should_behave_like "an assertion taking multiple values"
  it_should_behave_like "an assertion yielding passed values"

end

describe Assertions, "#assert_one_or_more" do

  include Assertions
  include AssertionsSpecHelper

  def do_assertion(*args, &block)
    assert_one_or_more(*args, &block)
  end

  before :each do
    @success_values = [[1], {:foo => :bar }]
    @failure_values = [nil, [], "foo"]
  end

  it_should_behave_like "any assertion"
  it_should_behave_like "a basic assertion"
  it_should_behave_like "an assertion taking multiple values"
  it_should_behave_like "an assertion yielding passed values"
end

describe Assertions, "#deny" do

  include Assertions
  include AssertionsSpecHelper

  def do_assertion(*args, &block)
    deny(*args, &block)
  end

  before :each do
    @success_values = [false, nil]
    @failure_values = [true, "", 0]
  end

  it_should_behave_like "any assertion"
  it_should_behave_like "a basic assertion"
  it_should_behave_like "an assertion taking multiple values"
  it_should_behave_like "an assertion yielding passed values"
end

describe Assertions, "#assert_keys" do

  include Assertions

  def do_assertion(*args, &block)
    assert_keys(*args, &block)
  end

  def do_success(&block)
    assert_keys({}, &block)
  end

  def do_failure(&block)
    assert_keys({}, :foo, &block)
  end

  it_should_behave_like "any assertion"
  it_should_behave_like "an assertion taking a block"

  it "should fail if a specified key does not exist" do
    lambda { assert_keys({}, :foo) }.should raise_error(AssertionFailureError)
  end

  it "should fail if a specified key is nil" do
    lambda do
      assert_keys({:foo => nil}, :foo)
    end.should raise_error(AssertionFailureError)
  end

  it "should fail if any of the specified keys are nil" do
    lambda do
      assert_keys({:foo => true, :bar => nil}, :foo, :bar)
    end.should raise_error(AssertionFailureError)
  end

  it "should fail if the given hash is nil" do
    lambda do
      assert_keys(nil)
    end.should raise_error(AssertionFailureError)
  end

  it "should fail if given something unlike a hash" do
    lambda do
      assert_keys(true)
    end.should raise_error(AssertionFailureError)
  end

  it "should succeed if no keys are given" do
    lambda do
      assert_keys({:foo => true, :bar => nil})
    end.should_not raise_error
  end

  it "should yield key values if they all exist" do
    did_yield = false
    assert_keys({:foo => 23, :bar => 32}, :foo, :bar) do |x, y|
      did_yield = true
      x.should == 23
      y.should == 32
      true
    end
    did_yield.should be_true
  end

  it "should yield nothing if a key is missing" do
    begin
      did_yield = false
      assert_keys({:foo => 23, :bar => 32}, :foo, :bar) do |x, y|
        did_yield = true
      end
    rescue AssertionFailureError
      did_yield.should be_false
    end
  end

  it "should return the hash" do
    @hash = { :buz => 42 }
    assert_keys(@hash, :buz).should equal(@hash)
  end
end

describe AssertionFailureError do
  it "should derive from Exception" do
    AssertionFailureError.superclass.should equal(Exception)
  end
end
