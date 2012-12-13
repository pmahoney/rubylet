module Rubylet
  module BuilderDefaults
    def initialize(options = {})
      super({ :indent => 2 }.merge(options))
      instruct!
    end
  end
end
