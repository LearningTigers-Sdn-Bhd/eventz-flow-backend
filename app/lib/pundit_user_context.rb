# Wraps a user and an api_key so Pundit policies can access both.
# Delegates all user methods to the underlying user object.
class PunditUserContext
  attr_reader :user, :api_key

  def initialize(user, api_key)
    @user = user
    @api_key = api_key
  end

  def respond_to_missing?(method_name, include_private = false)
    user.respond_to?(method_name, include_private) || super
  end

  def method_missing(method_name, *args, &block)
    if user.respond_to?(method_name)
      user.public_send(method_name, *args, &block)
    else
      super
    end
  end
end
