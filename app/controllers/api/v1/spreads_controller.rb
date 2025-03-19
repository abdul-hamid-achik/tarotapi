class Api::V1::SpreadsController < Api::V1::BaseController
  def create
    spread = Spread.new(spread_params)

    if spread.save
      render json: SpreadSerializer.new(spread).serializable_hash, status: :created
    else
      render json: {
        errors: spread.errors.map { |error|
          {
            status: "422",
            title: "validation error",
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
    spread = Spread.where(id: params[:id]).first

    if spread
      render json: SpreadSerializer.new(spread).serializable_hash
    else
      render json: {
        errors: [ {
          status: "404",
          title: "not found",
          detail: "spread not found"
        } ]
      }, status: :not_found
    end
  end

  private

  def spread_params
    # Parse the positions JSON if it's a string
    params_with_parsed_positions = spread_params_base
    
    if params_with_parsed_positions[:positions].is_a?(String)
      begin
        params_with_parsed_positions[:positions] = JSON.parse(params_with_parsed_positions[:positions])
      rescue JSON::ParserError => e
        # Log the error and keep the original value
        Rails.logger.error("Failed to parse positions JSON: #{e.message}")
      end
    end
    
    params_with_parsed_positions
  end
  
  def spread_params_base
    params.require(:spread).permit(:name, :description, :is_public, :user_id, :positions)
  end
end
