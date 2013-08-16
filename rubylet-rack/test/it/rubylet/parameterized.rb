module Rubylet
  # Makes a Minitest::Test parameterized by creating multiple
  # subclasses based on parameters.
  module Parameterized
    def parameterize(params)
      self.singleton_class.send(:attr_accessor, *params.keys)

      params.keys.each do |key|
        self.send(:define_method, key) do
          self.class.send(key)
        end
      end

      i = 1
      each_permutation(params) do |inst|
        klass = if i == 1
                  self          # original class gets first permutation
                else
                  const_set("Params#{i}", Class.new(self))
                end

        inst.each do |key, value|
          klass.send("#{key}=", value)
        end

        i += 1
      end
    end

    private

    def each_permutation(hash, &block)
      _each_permutation(hash.dup, &block)
    end

    def _each_permutation(hash)
      if kv = hash.shift
        key, values = kv
        _each_permutation(hash) do |params|
          values.each do |value|
            yield(params.merge(key => value))
          end
        end
      else
        yield({})
      end
    end
  end
end
