class CreateTicketTypes < ActiveRecord::Migration[7.1]
  def change
    create_table :ticket_types do |t|
      t.references :event, null: false, foreign_key: true
      t.string     :name, null: false
      t.integer    :price_cents, null: false
      t.string     :currency, null: false, default: "USD"
      t.integer    :total_quantity, null: false
      t.integer    :sold_quantity, null: false, default: 0

      t.timestamps
    end

    add_index :ticket_types, [:event_id, :name], unique: true

    add_check_constraint :ticket_types, "price_cents >= 0", name: "ticket_types_price_non_negative"
    add_check_constraint :ticket_types, "total_quantity >= 0", name: "ticket_types_total_qty_non_negative"
    add_check_constraint :ticket_types, "sold_quantity >= 0", name: "ticket_types_sold_qty_non_negative"
    add_check_constraint :ticket_types, "sold_quantity <= total_quantity", name: "ticket_types_sold_lte_total"
  end
end
