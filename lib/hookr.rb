require 'set'
require 'rubygems'
require 'fail_fast'

# TODO:
# * Handle-based callback removal
# * Recursive-style hooks
# * Global callbacks
module Hookr

  # Include this module to decorate your class with hookable goodness
  #
  # Note: remember to call super() if you define your own self.inherited().
  module Hooks
    module ClassMethods
      # Returns the hooks exposed by this class
      def hooks
        (@hooks ||= HookSet.new)
      end

      # Define a new hook +name+
      def define_hook(name, *params)
        hooks << Hook.new(name, nil, params)

        # We must use string evaluation in order to define a method that can
        # receive a block.
        instance_eval(<<-END)
          def #{name}(handle_or_method=nil, &block)
            add_callback(:#{name}, handle_or_method, &block)
          end
        END
      end

      # Add a callback to a named hook
      def add_callback(hook_name, handle_or_method=nil, &block)
        if block
          add_block_callback(hook_name, handle_or_method, block)
        else
          add_method_callback(hook_name, handle_or_method)
        end
      end

      def inherited(child)
        child.instance_variable_set(:@hooks, hooks.deep_copy)
      end

      private

      def add_block_callback(hook_name, handle, block)
        case block.arity
        when -1, 0
          hooks[hook_name].add_internal_callback(handle, &block)
        else
          hooks[hook_name].add_external_callback(handle, &block)
        end
      end

      def add_method_callback(hook_name, method)
        hooks[hook_name].add_method_callback(self, method)
      end
    end                         # ClassMethods

    def self.included(other)
      other.extend(ClassMethods)
    end

    # returns the hooks exposed by this object
    def hooks
      (@hooks ||= self.class.hooks.deep_copy)
    end

    def execute_hook(hook_name, *args)
      event = Event.new(self, hook_name, args)
      hooks[hook_name].execute_callbacks(event)
    end
  end

  class HookSet < Set
    def [](key)
      detect {|v| v.name == key} or raise IndexError, "No such hook: #{key}"
    end

    def deep_copy
      result = HookSet.new
      each do |hook|
        result << hook.dup
      end
      result
    end
  end

  # A single named hook
  Hook = Struct.new(:name, :parent, :params) do
    include FailFast::Assertions

    def initialize(name, parent=nil, params=[])
      assert(Symbol === name)
      @handles = {}
      super(name, parent || NullHook.new, params)
    end

    def initialize_copy(original)
      self.name = original.name
      self.parent = original
      @callbacks = CallbackSet.new
    end

    def ==(other)
      name == other.name
    end

    def eql?(other)
      self.class == other.class && name == other.name
    end

    def hash
      name.hash
    end

    def callbacks
      (@callbacks ||= CallbackSet.new)
    end

    # Add a callback which will be executed in the context where it was defined
    def add_external_callback(handle=nil, &block)
      if block.arity > -1 && block.arity < params.size
        raise ArgumentError, "Callback has incompatible arity"
      end
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
    def execute_callbacks(event)
      parent.execute_callbacks(event)
      callbacks.execute(event)
    end

    # Callback count including parents
    def total_callbacks
      callbacks.size + parent.total_callbacks
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

  # A null object class for terminating Hook inheritance chains
  class NullHook
    def execute_callbacks(event)
      # NOOP
    end

    def total_callbacks
      0
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

    def execute(event)
      each do |callback|
        callback.call(event)
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

  # Represents an event which is triggering callbacks.
  #
  # +source+::    The object triggering the event.
  # +name+::      The name of the event
  # +arguments+:: Any arguments passed associated with the event
  Event = Struct.new(:source, :name, :arguments) do

    # Convert to arguments for a callback of the given arity. Given an event
    # with three arguments, the rules are as follows:
    #
    # 1. If arity is -1 (meaning any number of arguments), or 5, the result will
    #    be [+source+, +name+, +arguments[0]+, +arguments[1]+, +arguments[2]+]
    # 2. If arity is 4, the result will be [+name+, +arguments[1]+, +arguments[2]+,
    #    +arguments[3]+]
    # 3. If arity is 3, the result will just be +arguments+
    # 4. If arity is < 3, an error will be raised.
    #
    # Notice that as the arity is reduced, first the source and then the event
    # name are trimmed off.  However, it is not permitted to generate a subset
    # of the +arguments+ list.  If the arity is too small to allow all arguments
    # to be passed, the method fails.
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
