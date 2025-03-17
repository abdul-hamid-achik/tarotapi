class UserResolutionService
  def initialize(params = {})
    @params = params
  end
  
  def resolve
    return find_by_id if @params[:id].present?
    return find_by_external_id if @params[:external_id].present?
    return find_by_email if @params[:email].present?
    create_anonymous
  end
  
  private
  
  def find_by_id
    User.find(@params[:id])
  rescue ActiveRecord::RecordNotFound
    create_anonymous
  end
  
  def find_by_external_id
    provider = find_provider
    User.find_by(external_id: @params[:external_id], identity_provider: provider) || 
      create_for_provider(provider)
  end
  
  def find_by_email
    User.find_by(email: @params[:email]) ||
      User.create!(
        email: @params[:email],
        identity_provider: IdentityProvider.registered,
        external_id: SecureRandom.uuid
      )
  end
  
  def create_anonymous
    User.find_or_create_anonymous
  end
  
  def find_provider
    return IdentityProvider.agent if @params[:provider] == 'agent'
    return IdentityProvider.registered if @params[:provider] == 'registered'
    IdentityProvider.anonymous
  end
  
  def create_for_provider(provider)
    case provider.name
    when IdentityProvider::AGENT
      User.find_or_create_agent(@params[:external_id])
    when IdentityProvider::REGISTERED
      User.create!(
        external_id: @params[:external_id],
        identity_provider: provider,
        email: @params[:email]
      )
    else
      User.find_or_create_anonymous(@params[:external_id])
    end
  end
end 