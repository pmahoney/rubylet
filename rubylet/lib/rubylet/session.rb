# A Rack compatible session object that forwards to an underlying
# +javax.servlet.http.HttpSession+.
module Rubylet
  class Session
    # @param [javax.servlet.http.HttpServletRequest] req
    # @param [Hash] options
    # @option options [Integer] :expire_after The max inactive interval, in seconds
    def initialize(req, options={})
      @javaSession = req.getSession

      if @javaSession.isNew
        if exp = options[:expire_after]
          req.setMaxInactiveInterval exp.to_i
        end
      end
    end
    
    def store(key, value)
      @javaSession.setAttribute(key, value)
    end
    alias_method :[]=, :store
    
    def fetch(key, default = nil)
      @javaSession.getAttribute(key) || default
    end
    alias_method :[], :fetch
    
    def delete(key)
      @javaSession.removeAttribute(key)
    end
    
    def clear
      @javaSession.getAttributeNames.each {|key| delete(key) }
    end

    # This method is not required by the Rack SPEC for session
    # objects, but Rails calls it anyway in +actionpack (3.2.9)
    # lib/action_dispatch/middleware/flash.rb:258:in `call'+
    def has_key?(key)
      !(fetch(key).nil?)
    end
    alias_method :include?, :has_key?
    alias_method :key?, :has_key?
    alias_method :member?, :has_key?

    # Used by Rails but not required by Rack.
    def destroy
      @javaSession.invalidate
    end

    def to_hash
      hash = {}
      @javaSession.getAttributeNames.each do
        |key| hash[key] = @javaSession.getAttribute(key)
      end
      hash
    end

    def inspect
      to_hash.inspect
    end
  end
end
