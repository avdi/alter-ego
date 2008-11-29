require File.expand_path('spec_helper', File.dirname(__FILE__))

describe Hookr::Hooks do
  describe "included in a class" do
    before :each do
      @class = Class.new
      @class.instance_eval do
        include Hookr::Hooks
      end
    end

    specify { @class.should have(0).hooks }

    describe "and instantiated" do
      before :each do
        @it = @class.new
      end

      specify { @it.should have(0).hooks }
    end


    describe "with a hook :foo defined" do
      before :each do
        @class.instance_eval do
          define_hook(:foo)
        end
      end

      specify { @class.should have(1).hooks }

      describe "and instantiated" do
        before :each do
          @it = @class.new
        end

        specify { @it.should have(1).hooks }
      end

      describe "and then redefined" do
        before :each do
          @class.instance_eval do
            define_hook(:foo)
          end
        end

        it "should still have only one hook" do
          @class.should have(1).hooks
        end
      end
    end

    describe "with hooks :foo and :bar defined" do
      before :each do
        @class.instance_eval do
          define_hook :foo
          define_hook :bar
        end
      end

      specify { @class.should have(2).hooks }

      it "should have a hook named :bar" do
        @class.hooks[:bar].should_not be_nil
      end

      it "should have a hook named :foo" do
        @class.hooks[:foo].should_not be_nil
      end

      it "should have a hook macro for :foo" do
        @class.should respond_to(:foo)
      end

      it "should have a hook macro for :bar" do
        @class.should respond_to(:bar)
      end

      specify "hooks should be instances of Hook" do
        @class.hooks[:foo].should be_a_kind_of(Hookr::Hook)
        @class.hooks[:bar].should be_a_kind_of(Hookr::Hook)
      end

      describe "and instantiated" do
        before :each do
          @it = @class.new
        end

        specify { @it.should have(2).hooks }
      end
    end
  end
end

describe "a no-param hook named :on_signal" do
  before :each do
    @class = Class.new
    @class.instance_eval do
      include Hookr::Hooks
      define_hook :on_signal
    end
    @instance      = @class.new
    @instance2     = @class.new
    @class_hook    = @class.hooks[:on_signal]
    @instance_hook = @instance.hooks[:on_signal]
  end

  it "should have no callbacks at the class level" do
    @class_hook.should have(0).callbacks
  end

  it "should have no callbacks at the instance level" do
    @instance_hook.should have(0).callbacks
  end

  describe "given an anonymous class-level block callback" do
    before :each do
      @class.instance_eval do
        on_signal do
          1 + 1
        end
      end
    end

    it "should have one callback at the class level" do
      @class_hook.should have(1).callback
    end

    it "should have one callback at the instance level" do
      @instance_hook.should have(1).callback
    end

    specify "class and instance level callbacks should be the same object" do
      @class_hook.callbacks.first.should equal(@instance_hook.callbacks.first)
    end
  end

  describe "given some named class-level block callbacks" do
    before :each do
      pending
      @class.instance_eval do
        on_signal :callback1 do
          1 + 1
        end
        on_signal :callback2 do
          2 + 2
        end
      end
    end

    it "should have two callbacks at the class level" do
      @class_hook.should have(2).callback
    end

    it "should have two callbacks at the instance level" do
      @instance_hook.should have(2).callback
    end

    specify ":callback1 should be the first callback" do
      @class_hook.callbacks[0].handle.should == :callback1
    end

    specify ":callback2 should be the second callback" do
      @class_hook.callbacks[1].handle.should == :callback2
    end

    specify ":callback1 should execute the given code" do
      @class_hook.callbacks[:callback1].call.should == 2
    end

    specify ":callback2 should execute the given code" do
      @class_hook.callbacks[:callback1].call.should == 4
    end
  end
end

describe Hookr::Hook do
  before :each do
    @class = Hookr::Hook
  end

  it "should require name to be a symbol" do
    lambda do
      @class.new("foo")
    end.should raise_error(FailFast::AssertionFailureError)
  end

  describe "named :foo" do
    before :each do
      @it = @class.new(:foo)
    end

    specify { @it.name.should == :foo }

    specify { @it.should have(0).callbacks }

    it "should require callbacks to be callable" do
      lambda do
        @it.add_callback("blah")
      end.should raise_error(FailFast::AssertionFailureError)
    end

    describe "given an anonymous callback" do
      before :each do
        @it.add_callback(lambda {})
      end

      specify { @it.should have(1).callbacks }
    end
  end
end
