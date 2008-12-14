module AlterEgo
  module States
    include FailFast::Assertions

    module ClassMethods
      def state(identifier, options={}, &block)
        if states.has_key?(identifier)
          raise InvalidDefinitionError, "State #{identifier.inspect} already defined"
        end
        new_state = Class.new(State)
        new_state_eigenclass = class << new_state; self; end
        new_state_eigenclass.send(:define_method, :identifier) { identifier }
        new_state.module_eval(&block) if block

        add_state(new_state, identifier, options)
      end

      def request_filter(options, &block)
        options.assert_valid_keys(:state, :request, :new_state, :action)
        options = {
          :state     => not_nil,
          :request   => not_nil,
          :new_state => nil
        }.merge(options)
        add_request_filter(options[:state],
                           options[:request],
                           options[:new_state],
                           FlexProc.new(options[:method], &block))
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
        options.assert_valid_keys(:default)

        self.states[identifier] = new_state

        if options[:default]
          if @default_state
            raise InvalidDefinitionError, "Cannot have more than one default state"
          end
          @default_state = identifier
        end

        new_requests = (new_state.handled_requests - all_handled_requests)
        new_requests.each do |request|
          @state_proxy.send(:define_method, request) do |*args|
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
    ############################################################################

    def self.append_features(klass)
      # Give the other module my instance methods at the class level
      klass.extend(ClassMethods)

      state_proxy = Module.new
      klass.instance_variable_set :@state_proxy, state_proxy
      klass.send(:include, state_proxy)
      klass.const_set(:State, State)
      super(klass)
    end

    def current_state
      state_id = self.state
      state_id ? self.states[state_id] : nil
    end

    def states
      @states ||= Hash.new do |states, state_id|
        state_obj = state_class_for_identifier(state_id).new(self)
        states[state_id] = state_obj
        state_obj
      end
    end

    def state
      result = (@state || self.class.default_state)
      assert(result.nil? || self.class.states.keys.include?(result))
      result
    end

    def state=(identifier)
      @state = identifier
    end

    def state_class_for_identifier(identifier)
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

  end
end
