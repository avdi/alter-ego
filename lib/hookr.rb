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
      assert(handle.nil? || Symbol === handle)
      assert_exists(block)
      handle ||= callbacks.size
      callback = ExternalCallback.new(handle, block, callbacks.size)
      callbacks << callback
      callback.handle
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
  end

  Callback = Struct.new(:handle, :block, :index) do
    include Comparable

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

  # A callback which will execute outside the event source
  class ExternalCallback < Callback
    def call
      block.call
    end
  end

  # A callback which will execute in the context of the event source
  class InternalCallback < Callback
  end

  # A callback which will call a method on the event source
  class MethodCallback < Callback
  end

end
