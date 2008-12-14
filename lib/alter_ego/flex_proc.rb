module AlterEgo
  class FlexProc < Proc
    def self.new(symbol = nil, &block)
      block = if symbol then
                lambda do
                  self.send(symbol)
                end
              elsif block then
                block
              else raise "Must pass symbol or block"
              end
      super(&block)
    end
  end
end
