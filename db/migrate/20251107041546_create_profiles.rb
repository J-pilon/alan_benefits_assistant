class CreateProfiles < ActiveRecord::Migration[7.2]
  def change
    create_table :profiles do |t|
      t.string :postal_code, null: false
      t.string :province, null: false

      t.timestamps
    end

    add_index :profiles, :postal_code
  end
end
