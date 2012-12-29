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

    def to_hash
      hash = {}
      @javaSession.getAttributeNames.each do
        |key| hash[key] = @javaSession.getAttribute(key)
      end
      hash
    end
  end
end
