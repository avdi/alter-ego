module AlterEgo
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
end
