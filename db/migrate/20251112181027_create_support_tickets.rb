class CreateSupportTickets < ActiveRecord::Migration[7.2]
  def change
    create_table :support_tickets do |t|
      t.references :profile, null: false, foreign_key: true, index: true
      t.references :chat_message, null: true, foreign_key: true
      t.string :status, default: "pending", null: false
      t.string :priority, default: "normal", null: false
      t.text :user_question, null: false
      t.text :initial_context
      t.datetime :resolved_at
      t.text :resolution_notes

      t.timestamps
    end

    add_index :support_tickets, :status
  end
end
