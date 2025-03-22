module Api
  module V1
    class OrganizationsController < ApplicationController
      include AuthenticateRequest

      before_action :set_organization, except: [:index, :create]
      after_action :verify_authorized, except: :index
      after_action :verify_policy_scoped, only: :index

      def index
        @organizations = policy_scope(Organization)
        render json: @organizations
      end

      def show
        authorize @organization
        render json: @organization
      end

      def create
        @organization = Organization.new(organization_params)
        authorize @organization

        if @organization.save
          # Create initial membership for creator as admin
          @organization.memberships.create!(
            user: current_user,
            role: :admin,
            status: :active
          )
          
          render json: @organization, status: :created
        else
          render json: { errors: @organization.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        authorize @organization

        if @organization.update(organization_params)
          render json: @organization
        else
          render json: { errors: @organization.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        authorize @organization
        @organization.destroy
        head :no_content
      end

      def add_member
        authorize @organization, :manage_members?

        @membership = @organization.memberships.build(membership_params)
        
        if @membership.save
          # Send invitation email
          OrganizationMailer.invitation_email(@membership).deliver_later
          
          render json: @membership, status: :created
        else
          render json: { errors: @membership.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def remove_member
        authorize @organization, :manage_members?

        @membership = @organization.memberships.find_by!(user_id: params[:user_id])
        @membership.destroy
        
        head :no_content
      end

      def usage
        authorize @organization, :view_usage?

        metrics = @organization.usage_metrics(
          start_date: params[:start_date]&.to_date,
          end_date: params[:end_date]&.to_date,
          granularity: params[:granularity]&.to_sym || :daily
        )
        
        render json: metrics
      end

      def analytics
        authorize @organization, :view_analytics?

        analytics = @organization.analytics(
          start_date: params[:start_date]&.to_date,
          end_date: params[:end_date]&.to_date,
          metrics: params[:metrics]
        )
        
        render json: analytics
      end

      private

      def set_organization
        @organization = Organization.find(params[:id])
      end

      def organization_params
        params.require(:organization).permit(
          :name,
          :plan,
          :billing_email,
          settings: [:white_label, :custom_domain, :webhook_url]
        )
      end

      def membership_params
        params.require(:membership).permit(:email, :role, :name).merge(
          user: User.find_by(email: params[:membership][:email])
        )
      end
    end
  end
end 