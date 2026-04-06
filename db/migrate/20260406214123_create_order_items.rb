class CreateOrderItems < ActiveRecord::Migration[7.1]
  def change
    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :ticket_type, null: false, foreign_key: true
      t.integer    :quantity, null: false
      t.integer    :unit_price_cents_snapshot, null: false

      t.timestamps
    end

    add_index :order_items, [:order_id, :ticket_type_id], unique: true

    add_check_constraint :order_items, "quantity > 0", name: "order_items_quantity_positive"
    add_check_constraint :order_items, "unit_price_cents_snapshot >= 0", name: "order_items_unit_price_non_negative"
  end
end
