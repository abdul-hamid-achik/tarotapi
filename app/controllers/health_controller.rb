class HealthController < ApplicationController
  def show
    render json: { 
      status: "ok", 
      version: ENV["GIT_COMMIT_SHA"] || "development",
      rails_env: Rails.env,
      db_connection: ActiveRecord::Base.connection.active?
    }
  end
end
