$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

gem 'hookr',     "~> 1.0.0"
gem 'fail-fast', "~> 1.1.0"

require 'forwardable'
require 'singleton'
require 'rubygems'
require 'fail_fast'
require 'hookr'

module AlterEgo
  VERSION = '1.0.1'

  include FailFast::Assertions

  class StateError < RuntimeError
  end
  class InvalidDefinitionError < StateError
  end
  class InvalidTransitionError < StateError
  end
  class InvalidRequestError < StateError
  end
  class WrongStateError < StateError
  end

  RequestFilter = Struct.new("RequestFilter",
                             :state,
                             :request,
                             :new_state,
                             :action)
  class RequestFilter
    def ===(other)
      result = (matches?(self.state, other.state) and
                matches?(self.request, other.request) and
                matches?(self.new_state, other.new_state))
     result
    end

    def matches?(lhs, rhs)
      if rhs.respond_to?(:include?)
        rhs.include?(lhs)
      else
        rhs == lhs
      end
    end
  end

  class AnyMatcher
    include Singleton

    def ===(other)
      self == other
    end

    def ==(other)
      true
    end
  end

  class NotNilMatcher
    include Singleton

    def ===(other)
      self == other
    end

    def ==(other)
      not other.nil?
    end
  end

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
      assert_only_keys(options, :to, :on, :if)
      assert_keys(options, :to)
      guard    = options[:if]
      to_state = options[:to]
      request   = options[:on]
      if request
        handle(request) do
          transition_to(to_state, request)
        end
      end
      valid_transitions << to_state unless valid_transitions.include?(to_state)
      if guard
        method = guard.kind_of?(Symbol) ? guard : nil
        block  = guard.kind_of?(Proc) ? guard : nil
        predicate = AlterEgo.proc_from_symbol_or_block(method, &block)
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

    def valid_transitions
      self.class.valid_transitions
    end

    def to_s
      "<State:#{identifier}>"
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
      new_state_obj = context.state_for_identifier(new_state)
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
        define_method(name) do |context, *args|
           context.send(symbol, *args)
         end
      elsif block
        define_method(name) do |context, *args|
          context.send(:instance_eval, &block)
        end
      end
    end
  end

  module ClassMethods
    include FailFast::Assertions

    def state(identifier, options={}, &block)
      if states.has_key?(identifier)
        raise InvalidDefinitionError, "State #{identifier.inspect} already defined"
      end
      new_state = Class.new(State)
      new_state_eigenclass = class << new_state; self; end
      new_state_eigenclass.send(:define_method, :identifier) { identifier }
      new_state.instance_eval(&block) if block

      add_state(new_state, identifier, options)
    end

    def request_filter(options, &block)
      assert_only_keys(options, :state, :request, :new_state, :action)
      options = {
        :state     => not_nil,
        :request   => not_nil,
        :new_state => nil
      }.merge(options)
      add_request_filter(options[:state],
                         options[:request],
                         options[:new_state],
                         AlterEgo.proc_from_symbol_or_block(options[:method], &block))
    end

    def all_handled_requests
      methods = @state_proxy.public_instance_methods(false)
      methods -= ["identifier", "on_enter", "on_exit"]
      methods.map{|m| m.to_sym}
    end

    def states
      (@states ||= {})
    end

    def states=(value)
      @states = value
    end

    def add_state(new_state, identifier=new_state.identifier, options = {})
      assert_only_keys(options, :default)

      self.states[identifier] = new_state.new

      if options[:default]
        if @default_state
          raise InvalidDefinitionError, "Cannot have more than one default state"
        end
        @default_state = identifier
      end

      new_requests = (new_state.handled_requests - all_handled_requests)
      new_requests.each do |request|
        @state_proxy.send(:define_method, request) do |*args|
          args.unshift(self)
          begin
            continue = execute_request_filters(current_state.identifier,
                                               request,
                                               nil)
            return false unless continue
            current_state.send(request, *args)
          rescue NoMethodError => error
            if error.name.to_s == request.to_s
              raise WrongStateError,
                    "Request '#{request}' not supported by state #{current_state}"
            else
              raise
            end
          end
        end
      end

      self.request_filters += new_state.request_filters
    end

    def add_request_filter(state_pattern, request_pattern, new_state_pattern, action)
      @request_filters << RequestFilter.new(state_pattern,
                                            request_pattern,
                                            new_state_pattern,
                                            action)
    end

    def default_state
      @default_state
    end

    def request_filters
      (@request_filters ||= [])
    end

    protected

    def request_filters=(value)
      @request_filters = value
    end

    def any
      AlterEgo::AnyMatcher.instance
    end

    def not_nil
      AlterEgo::NotNilMatcher.instance
    end

  end                           # End ClassMethods

  def self.append_features(klass)
    # Give the other module my instance methods at the class level
    klass.extend(ClassMethods)
    klass.extend(Forwardable)

    state_proxy = Module.new
    klass.instance_variable_set :@state_proxy, state_proxy
    klass.send(:include, state_proxy)

    super(klass)
  end

  def current_state
    state_id = self.state
    state_id ? self.class.states[state_id] : nil
  end

  def state
    result = (@state || self.class.default_state)
    assert(result.nil? || self.class.states.keys.include?(result))
    result
  end

  def state=(identifier)
    @state = identifier
  end

  def state_for_identifier(identifier)
    self.class.states[identifier]
  end

  def transition_to(new_state, request=nil, *args)
    current_state.transition_to(self, request, new_state, *args)
  end

  def all_handled_requests
    self.class.all_handled_requests
  end

  def execute_request_filters(state, request, new_state)
    pattern = RequestFilter.new(state, request, new_state)
    self.class.request_filters.grep(pattern) do |filter|
      result = catch(:cancel) do
        self.instance_eval(&filter.action)
        true
      end
      return false unless result
    end
    true
  end

  def self.proc_from_symbol_or_block(symbol = nil, &block)
    if symbol then
      proc do
        self.send(symbol)
      end
    elsif block then
      block
    else raise "Should never get here"
    end
  end

end
