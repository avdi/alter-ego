require 'set'
require 'rubygems'
require 'fail_fast'

module Hookr
  module Hooks
    module ClassMethods
      # Returns the hooks exposed by this class
      def hooks
        (@hooks ||= HookSet.new)
      end

      # Define a new hook +name+
      def define_hook(name)
        hooks << Hook.new(name)

        # We must use string evaluation in order to define a method that can
        # receive a block.
        instance_eval(<<-END)
          def #{name}(handle=nil, &block)
            add_callback(:#{name}, handle, &block)
          end
        END
      end

      # Add a callback to a named hook
      def add_callback(hook_name, handle=nil, &block)
        hooks[hook_name].add_external_callback(handle, &block)
      end
    end

    def self.included(other)
      other.extend(ClassMethods)
    end

    # returns the hooks exposed by this object
    def hooks
      self.class.hooks
    end

  end

  class HookSet < Set
    def [](key)
      detect {|v| v.name == key}
    end
  end

  # A single named hook
  Hook = Struct.new(:name) do
    include FailFast::Assertions

    def initialize(name)
      assert(Symbol === name)
      @handles = {}
      super(name)
    end

    def callbacks
      (@callbacks ||= CallbackSet.new)
    end

    # Add a callback which will be executed in the context where it was defined
    def add_external_callback(handle=nil, &block)
      add_block_callback(Hookr::ExternalCallback, handle, &block)
    end

    # Add a callback which will be executed in the context of the event source
    def add_internal_callback(handle=nil, &block)
      add_block_callback(Hookr::InternalCallback, handle, &block)
    end

    # Add a callback which will send the given +message+ to the event source
    def add_method_callback(klass, message)
      method = klass.instance_method(message)
      add_callback(Hookr::MethodCallback.new(message, method, next_callback_index))
    end

    def add_callback(callback)
      callbacks << callback
      callback.handle
    end

    # Excute the callbacks in order.  +source+ is the object initiating the event.
    def execute_callbacks(source)
      callbacks.execute(source)
    end

    private

    def next_callback_index
      return 0 if callbacks.empty?
      callbacks.map{|cb| cb.index}.max + 1
    end

    def add_block_callback(type, handle=nil, &block)
      assert_exists(block)
      assert(handle.nil? || Symbol === handle)
      handle ||= next_callback_index
      add_callback(type.new(handle, block, next_callback_index))
    end
  end

  class CallbackSet < SortedSet

    # Fetch callback by either index or handle
    def [](index)
      case index
      when Integer then detect{|cb| cb.index == index}
      when Symbol  then detect{|cb| cb.handle == index}
      else raise ArgumentError, "index must be Integer or Symbol"
      end
    end

    # get the first callback
    def first
      each do |cb|
        return cb
      end
    end

    def execute(source)
      each do |callback|
        callback.call(source)
      end
    end
  end

  Callback = Struct.new(:handle, :index) do
    include Comparable
    include FailFast::Assertions

    # Callbacks with the same handle are always equal, which prevents duplicate
    # handles in CallbackSets.  Otherwise, callbacks are sorted by index.
    def <=>(other)
      if handle == other.handle
        return 0
      end
      self.index <=> other.index
    end

    # Must be overridden in subclass
    def call(*args)
      raise NotImplementedError, "Callback is an abstract class"
    end
  end

  # A base class for callbacks which execute a block
  class BlockCallback < Callback
    attr_reader :block

    def initialize(handle, block, index)
      @block = block
      super(handle, index)
    end
  end

  # A callback which will execute outside the event source
  class ExternalCallback < BlockCallback
    def call(event)
      block.call(*event.to_args(block.arity))
    end
  end

  # A callback which will execute in the context of the event source
  class InternalCallback < BlockCallback
    def initialize(handle, block, index)
      assert(block.arity <= 0)
      super(handle, block, index)
    end

    def call(event)
      event.source.instance_eval(&block)
    end
  end

  # A callback which will call a method on the event source
  class MethodCallback < Callback
    attr_reader :method

    def initialize(handle, method, index)
      @method = method
      super(handle, index)
    end

    def call(event)
      method.bind(event.source).call(*event.to_args(method.arity))
    end
  end

  # Represents an event triggering callbacks
  Event = Struct.new(:source, :name, :arguments) do

    # Convert to arguments for a callback of the given arity
    def to_args(arity)
      case arity
      when -1
        full_arguments
      when (min_argument_count..full_argument_count)
        full_arguments.slice(full_argument_count - arity, arity)
      else
        raise ArgumentError, "Arity must be between #{min_argument_count} "\
                             "and #{full_argument_count}"
      end
    end

    private

    def full_argument_count
      full_arguments.size
    end

    def min_argument_count
      arguments.size
    end

    def full_arguments
      @full_arguments ||= [source, name, *arguments]
    end
  end

end
