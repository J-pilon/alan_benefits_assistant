class SupportTicket < ApplicationRecord
  belongs_to :profile
  belongs_to :chat_message, optional: true

  validates :user_question, presence: true
  validates :status, inclusion: { in: %w[pending in_progress resolved closed] }
  validates :priority, inclusion: { in: %w[low normal high urgent] }

  # Scopes for common queries
  scope :pending, -> { where(status: "pending") }
  scope :in_progress, -> { where(status: "in_progress") }
  scope :open, -> { where(status: %w[pending in_progress]) }
  scope :resolved, -> { where.not(resolved_at: nil) }
  scope :by_priority, ->(priority) { where(priority: priority) }

  # Order by priority and creation date
  scope :by_urgency, -> {
    order(
      Arel.sql(
        "CASE priority
          WHEN 'urgent' THEN 1
          WHEN 'high' THEN 2
          WHEN 'normal' THEN 3
          WHEN 'low' THEN 4
        END"
      ),
      created_at: :asc
    )
  }

  # Mark ticket as resolved
  def resolve!(notes = nil)
    update!(
      status: "resolved",
      resolved_at: Time.current,
      resolution_notes: notes
    )
  end

  # Check if ticket is open
  def open?
    %w[pending in_progress].include?(status)
  end

  # Check if ticket is resolved
  def resolved?
    resolved_at.present?
  end
end
