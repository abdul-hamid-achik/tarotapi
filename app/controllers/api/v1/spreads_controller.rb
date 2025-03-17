class Api::V1::SpreadsController < Api::V1::BaseController
  def create
    spread = Spread.new(spread_params)
    
    if spread.save
      render json: SpreadSerializer.new(spread).serializable_hash, status: :created
    else
      render json: {
        errors: spread.errors.map { |error|
          {
            status: '422',
            title: 'validation error',
            detail: error.full_message
          }
        }
      }, status: :unprocessable_entity
    end
  end

  def index
    spreads = Spread.where(is_public: true)
    render json: SpreadSerializer.new(spreads).serializable_hash
  end

  def show
    spread = Spread.find_by(id: params[:id])
    
    if spread
      render json: SpreadSerializer.new(spread).serializable_hash
    else
      render json: {
        errors: [{
          status: '404',
          title: 'not found',
          detail: 'spread not found'
        }]
      }, status: :not_found
    end
  end

  private

  def spread_params
    params.require(:spread).permit(:name, :description, :is_public, :user_id, positions: [])
  end
end
