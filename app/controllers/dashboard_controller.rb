class DashboardController < ApplicationController
  def index
    @profile = current_profile
    @chat_messages = @profile.chat_messages.ordered
  end

  def create_message
    @profile = current_profile

    user_message = params[:message]

    if user_message.blank?
      render json: { error: "Message cannot be blank" }, status: :unprocessable_entity
      return
    end

    support_service = SupportService.new(profile: @profile)
    result = support_service.process_user_query(user_message)

    if result[:success]
      render json: result[:chat_message].merge(
        source: result[:source],
        support_ticket_id: result.dig(:support_ticket, :id),
        support_ticket_status: result.dig(:support_ticket, :status),
        support_ticket_priority: result.dig(:support_ticket, :priority)
      ).compact
    else
      render json: { error: "Failed to process message" }, status: :internal_server_error
    end
  rescue StandardError => e
    Rails.logger.error("Chat message error: #{e.message}")
    render json: { error: "Failed to process message: #{e.message}" }, status: :internal_server_error
  end
end
