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
    @event         = stub("Event", :to_args => [])
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
      @class_hook.callbacks[0].should equal(@instance_hook.callbacks.first)
    end
  end

  describe "given some named class-level block callbacks" do
    before :each do
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
      @class_hook.callbacks[:callback1].call(@event).should == 2
    end

    specify ":callback2 should execute the given code" do
      @class_hook.callbacks[:callback2].call(@event).should == 4
    end
  end
end

describe Hookr::Hook do
  before :each do
    @class = Hookr::Hook
    @sensor = stub("Sensor")
    sensor = @sensor
    @source_class = Class.new do
      define_method :my_method do
        sensor.ping(:my_method)
      end
    end
    @source = @source_class.new
    @event  = stub("Event", :source => @source, :to_args => [])
  end

  it "should require name to be a symbol" do
    lambda do
      @class.new("foo")
    end.should raise_error(FailFast::AssertionFailureError)
  end

  describe "named :foo" do
    before :each do
      @it = @class.new(:foo)
      @callback = stub("Callback", :handle => 123)
      @block = lambda {}
    end

    specify { @it.name.should == :foo }

    specify { @it.should have(0).callbacks }

    describe "when adding a callback" do
      it "should return the handle of the added callback" do
        @it.add_callback(@callback).should == 123
      end
    end

    describe "given an anonymous external callback" do
      before :each do
        @it.add_external_callback(&@block)
      end

      specify { @it.should have(1).callbacks }

    end

    describe "given a selection of callbacks" do
      before :each do
        sensor = @sensor
        @anon_external_cb  = @it.add_external_callback do
          @sensor.ping(:anon_external)
        end
        @named_external_cb = @it.add_external_callback(:my_external) do
          @sensor.ping(:named_external)
        end
        @anon_internal_cb  = @it.add_internal_callback do ||
          sensor.ping(:anon_internal)
        end
        @named_internal_cb = @it.add_internal_callback(:my_internal) do ||
          sensor.ping(:named_internal)
        end
        @method_cb = @it.add_method_callback(@source_class, :my_method)
      end

      specify { @it.should have(5).callbacks }

      specify "the handles of the anonymous callbacks should be their indexes" do
        @it.callbacks[0].handle.should == 0
        @it.callbacks[2].handle.should == 2
      end

      specify "the add methods should return handles" do
        @anon_external_cb.should == 0
        @named_external_cb.should == :my_external
        @anon_internal_cb.should == 2
        @named_internal_cb.should == :my_internal
        @method_cb.should == :my_method
      end

      specify "the callbacks should have the intended types" do
        @it.callbacks[@anon_external_cb].should be_a_kind_of(Hookr::ExternalCallback)
        @it.callbacks[@named_external_cb].should be_a_kind_of(Hookr::ExternalCallback)
        @it.callbacks[@anon_internal_cb].should be_a_kind_of(Hookr::InternalCallback)
        @it.callbacks[@named_internal_cb].should be_a_kind_of(Hookr::InternalCallback)
        @it.callbacks[@method_cb].should be_a_kind_of(Hookr::MethodCallback)
      end

      specify "the callbacks should execute in order of addition" do
        @sensor.should_receive(:ping).with(:anon_external).ordered
        @sensor.should_receive(:ping).with(:named_external).ordered
        @sensor.should_receive(:ping).with(:anon_internal).ordered
        @sensor.should_receive(:ping).with(:named_internal).ordered
        @sensor.should_receive(:ping).with(:my_method).ordered

        @it.execute_callbacks(@event)
      end
    end
  end
end

describe Hookr::CallbackSet do
  before :each do
    @it = Hookr::CallbackSet.new
    @cb1 = Hookr::Callback.new(:cb1, 1)
    @cb2 = Hookr::Callback.new(:cb2, 2)
    @cb3 = Hookr::Callback.new(:cb3, 3)
  end

  describe "given three callbacks" do
    before :each do
      @it << @cb1
      @it << @cb3
      @it << @cb2
    end

    it "should sort the callbacks" do
      @it.to_a.should == [@cb1, @cb2, @cb3]
    end

    it "should be able to locate callbacks by index" do
      @it[1].should equal(@cb1)
      @it[2].should equal(@cb2)
      @it[3].should equal(@cb3)
    end

    it "should return nil if a callback cannot be found" do
      @it[4].should be_nil
    end

    it "should be able to locate callbacks by handle" do
      @it[:cb1].should equal(@cb1)
      @it[:cb2].should equal(@cb2)
      @it[:cb3].should equal(@cb3)
    end
  end
end

describe Hookr::Callback, "with handle :cb1 and an index of 1" do
  before :each do
    @block = stub("block", :call => nil)
    @it = Hookr::Callback.new(:cb1, 1)
  end

  it "should sort as greater than a callback with index of 0" do
    @other = Hookr::Callback.new(:cb2, 0)
    (@it <=> @other).should == 1
  end

  it "should sort as less than a callback with index of 2" do
    @other = Hookr::Callback.new(:cb2, 2)
    (@it <=> @other).should == -1
  end

  it "should sort as equal to a callback with index of 1" do
    @other = Hookr::Callback.new(:cb2, 1)
    (@it <=> @other).should == 0
  end

  it "should sort as equal to any callback with the same handle" do
    @other = Hookr::Callback.new(:cb1, 2)
    (@it <=> @other).should == 0
  end
end

describe "Callbacks: " do
  before :each do
    @handle = :foo
    @sensor = stub("Sensor")
    @index  = 1
    @source = stub("Source")
    @name   = :we_get_signal!
    @arguments = []
    @event = stub("Event", :source => @source)
  end

  describe Hookr::ExternalCallback do
    describe "with a no-param block" do
      before :each do
        @block = stub("Block", :arity => 0, :call => nil)
        @it = Hookr::ExternalCallback.new(@handle, @block, @index)
      end

      it "should take 0 args from event and call block with no args" do
        @event.should_receive(:to_args).with(0).and_return([])
        @block.should_receive(:call).with()
        @it.call(@event)
      end
    end

    describe "with a two-param block" do
      before :each do
        @block = stub("Block", :arity => 2, :call => nil)
        @it = Hookr::ExternalCallback.new(@handle, @block, @index)
      end

      it "should take 2 args from event and call block with 2 args" do
        @event.should_receive(:to_args).with(2).and_return([:a, :b])
        @block.should_receive(:call).with(:a, :b)
        @it.call(@event)
      end
    end
  end

  describe Hookr::InternalCallback do
    describe "with a no-param block" do
      before :each do
        source = @source
        @block = lambda do
          source.ping
        end
        @it = Hookr::InternalCallback.new(@handle, @block, @index)
      end

      it "should instance eval the block on the event source" do
        @source.should_receive(:instance_eval).and_yield
        @source.should_receive(:ping)
        @it.call(@event)
      end
    end

    describe "with a one-param block" do
      it "should raise error" do
        @block = stub("Block", :arity => 1, :call => nil)
        lambda do
          @it = Hookr::InternalCallback.new(@handle, @block, @index)
        end.should raise_error
      end
    end
  end

  describe Hookr::MethodCallback do
    describe "with a no-param method" do
      before :each do
        @method = stub("Method", :arity => 0, :call => nil)
        @it = Hookr::MethodCallback.new(@handle, @method, @index)
      end

      it "should take 0 args from event and call method with no args" do
        @event.should_receive(:to_args).with(0).and_return([])
        @method.should_receive(:bind).with(@source).and_return(@bound_method)
        @bound_method.should_receive(:call).with()
        @it.call(@event)
      end
    end

    describe "with a two-param block" do
      before :each do
        @method = stub("Method", :arity => 2, :call => nil)
        @it = Hookr::MethodCallback.new(@handle, @method, @index)
      end

      it "should take 2 args from event and call method with 2 args" do
        @event.should_receive(:to_args).with(2).and_return([:a, :b])
        @method.should_receive(:bind).with(@source).and_return(@bound_method)
        @bound_method.should_receive(:call).with(:a, :b)
        @it.call(@event)
      end
    end
  end

end

describe Hookr::Event do
  describe "with three arguments" do
    before :each do
      @source              = stub("Source")
      @name                = :on_signal
      @arguments           = ["arg1", "arg2", "arg3"]
      @it = Hookr::Event.new(@source,
                             @name,
                             @arguments)
    end

    describe "given an arity of -1" do
      it "should convert to five arguments" do
        @it.to_args(-1).should == [@source, @name, *@arguments]
      end
    end

    describe "given an arity of 2" do
      it "should raise an error" do
        lambda do
          @it.to_args(2).should == [@source, @name, *@arguments]
        end.should raise_error
      end
    end

    describe "given an arity of 3" do
      it "should convert to three arguments" do
        @it.to_args(3).should == @arguments
      end
    end

    describe "given an arity of 4" do
      it "should convert to four arguments" do
        @it.to_args(4).should == [@name, *@arguments]
      end
    end

    describe "given an arity of 5" do
      it "should convert to four arguments" do
        @it.to_args(-1).should == [@source, @name, *@arguments]
      end
    end

    describe "given an arity of 6" do
      it "should raise an error" do
        lambda do
          @it.to_args(6).should == [@source, @name, *@arguments]
        end.should raise_error
      end
    end
  end
end
