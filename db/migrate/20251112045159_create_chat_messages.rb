class CreateChatMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :chat_messages do |t|
      t.references :profile, null: false, foreign_key: true, index: true
      t.text :user_message, null: false
      t.text :ai_response
      t.json :ai_metadata

      t.timestamps
    end
  end
end
