require 'singleton'
module AlterEgo
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
end
