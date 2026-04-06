class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :orders do |t|
      t.string   :status, null: false, default: "pending"
      t.integer  :total_cents, null: false, default: 0
      t.string   :currency, null: false, default: "USD"
      t.datetime :placed_at

      t.timestamps
    end

    add_index :orders, :status

    add_check_constraint :orders, "total_cents >= 0", name: "orders_total_non_negative"
    add_check_constraint :orders, "status IN ('pending', 'confirmed', 'cancelled')", name: "orders_valid_status"
  end
end
