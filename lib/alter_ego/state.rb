require 'hookr'

module AlterEgo

  # A customization of HookR::Hook to deal with the fact that State internal
  # callbacks need to be executed in the context of the state's context, not the
  # state object itself.
  class StateHook < HookR::Hook
    class StateContextCallback < HookR::InternalCallback
      def call(event)
        context = event.arguments.first
        context.instance_eval(&block)
      end
    end

    # Add an internal callback that executes in the context of the state
    # context, instead of the state itself
    def add_internal_callback(handle=nil, &block)
      add_block_callback(StateContextCallback, handle, &block)
    end
  end

  class State
    include FailFast::Assertions
    extend FailFast::Assertions
    include HookR::Hooks

    def self.transition(options, &trans_action)
      options.assert_valid_keys(:to, :on, :if)
      assert_keys(options, :to)
      guard    = options[:if]
      to_state = options[:to]
      request  = options[:on]
      if request
        handle(request) do
          transition_to(to_state, request)
        end
      end
      valid_transitions << to_state unless valid_transitions.include?(to_state)
      if guard
        method = guard.kind_of?(Symbol) ? guard : nil
        block  = guard.kind_of?(Proc) ? guard : nil
        predicate = FlexProc.new(method, &block)
        guard_proc = proc do
          result = instance_eval(&predicate)
          throw :cancel unless result
        end
        add_request_filter(request, to_state, guard_proc)
      end
      if trans_action
        add_request_filter(request, to_state, trans_action)
      end
    end

    def self.identifier
      self
    end

    def self.valid_transitions
      (@valid_transitions ||= [])
    end

    def self.handled_requests
      public_instance_methods(false)
    end

    def self.request_filters
      (@request_filters ||= [])
    end

    def self.handle(request, method = nil, &block)
      define_contextual_method_from_symbol_or_block(request, method, &block)
    end

    def self.make_hook(name, parent, params)
      ::AlterEgo::StateHook.new(name, parent, params)
    end

    def initialize(context)
      @context = context
    end

    def __getobj__
      @context
    end

    def valid_transitions
      self.class.valid_transitions
    end

    def inspect
      "#<State:#{identifier}>"
    end

    def to_s
      inspect
    end

    def identifier
      self.class.identifier
    end

    def ==(other)
      (self.identifier == other) or super(other)
    end

    def can_handle_request?(request)
      return true if respond_to?(request)
      return false
    end

    def transition_to(context, request, new_state, *args)
      return true if context.state == new_state
      new_state_obj = context.states[new_state]
      unless new_state_obj
        raise(InvalidTransitionError,
              "Context #{context.inspect} has no state '#{new_state}' defined")
      end

      continue = context.execute_request_filters(self.class.identifier,
                                                 request,
                                                 new_state)
      return false unless continue

      unless valid_transitions.empty? || valid_transitions.include?(new_state)
        raise(InvalidTransitionError,
              "Not allowed to transition from #{self.identifier} to #{new_state}")
      end

      execute_hook(:on_exit, context)
      new_state_obj.execute_hook(:on_enter, context)
      context.state = new_state
      assert(new_state == context.state)
      true
    end

    protected

    define_hook :on_enter, :context
    define_hook :on_exit,  :context

    private

    def self.add_request_filter(request_pattern, new_state_pattern, action)
      new_filter = RequestFilter.new(identifier, request_pattern, new_state_pattern, action)
      self.request_filters << new_filter
    end

    def self.define_contextual_method_from_symbol_or_block(name, symbol, &block)
      if symbol
        define_method(name) do |*args|
           __getobj__.send(symbol, *args)
         end
      elsif block
        define_method(name) do |*args|
          __getobj__.send(:instance_eval, &block)
        end
      end
    end
  end
end
