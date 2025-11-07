class CreateCoverageBalances < ActiveRecord::Migration[7.2]
  def change
    create_table :coverage_balances do |t|
      t.references :profile, null: false, foreign_key: true
      t.string :category, null: false
      t.decimal :remaining_amount, precision: 10, scale: 2
      t.date :reset_date
      t.string :rule_version_id, null: false

      t.timestamps
    end

    add_index :coverage_balances, [:profile_id, :category]
    add_index :coverage_balances, :rule_version_id
  end
end
