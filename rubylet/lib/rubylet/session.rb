class Rubylet::Session

  def initialize(req)
    @javaSession = req.getSession
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
    @javaSession.getAttributeNames.each {|key| hash[key] = @javaSession.getAttribute(key) }
    hash
  end
  
end
