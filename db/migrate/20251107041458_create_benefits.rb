class CreateBenefits < ActiveRecord::Migration[7.2]
  def change
    create_table :benefits do |t|
      t.string :rule_version_id, null: false
      t.string :category, null: false
      t.string :province, null: false
      t.json :coverage, null: false

      t.timestamps
    end

    add_index :benefits, [:category, :province]
    add_index :benefits, :rule_version_id, unique: true
  end
end
