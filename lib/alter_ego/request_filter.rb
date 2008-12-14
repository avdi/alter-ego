module AlterEgo
  RequestFilter = Struct.new("RequestFilter",
                             :state,
                             :request,
                             :new_state,
                             :action) do
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
end
