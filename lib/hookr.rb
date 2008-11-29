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
          def #{name}(&block)
            add_callback(:#{name}, &block)
          end
        END
      end

      # Add a callback to a named hook
      def add_callback(name, &block)
        hooks[name].add_callback(block)
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
      super(name)
    end

    def callbacks
      (@callbacks ||= [])
    end

    def add_callback(callback)
      assert_respond_to(callback, :call)
      callbacks << callback
    end
  end
end
