class BaseService
  attr_reader :user, :params

  def initialize(user, params = {})
    @user = user
    @params = params
  end

  def policy_scope(scope)
    Pundit.policy_scope!(user, scope)
  end

  def policy(record)
    Pundit.policy!(user, record)
  end

  def authorize(record, query)
    raise Pundit::NotAuthorizedError, "not allowed to #{query} this #{record.inspect}" unless policy(record).public_send(query)
  end

  class ServiceResult
    attr_reader :data, :errors, :status

    def initialize(success:, data: nil, errors: nil, status: nil)
      @success = success
      @data = data
      @errors = errors
      @status = status
    end

    def success?
      @success
    end
  end
end
