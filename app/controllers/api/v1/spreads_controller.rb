class Api::V1::SpreadsController < ApplicationController
  include AuthenticateRequest

  before_action :set_spread, only: [:show, :update, :destroy, :publish]
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    @spreads = policy_scope(Spread)
    render json: @spreads
  end

  def show
    authorize @spread
    render json: @spread
  end

  def create
    @spread = current_user.spreads.build(spread_params)
    authorize @spread

    if @spread.save
      render json: @spread, status: :created
    else
      render json: { errors: @spread.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    authorize @spread

    if @spread.update(spread_params)
      render json: @spread
    else
      render json: { errors: @spread.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @spread
    @spread.destroy
    head :no_content
  end

  def publish
    authorize @spread, :publish?

    if @spread.update(is_public: true)
      render json: @spread
    else
      render json: { errors: @spread.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_spread
    @spread = Spread.find(params[:id])
  end

  def spread_params
    params.require(:spread).permit(:name, :description, :num_cards, :positions)
  end
end
