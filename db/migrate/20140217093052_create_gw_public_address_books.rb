class CreateGwPublicAddressBooks < ActiveRecord::Migration
  def self.up
    create_table :gw_webmail_public_address_books do |t|
      t.string :name
      t.integer :state
      t.text :editable_groups_json
      t.text :editable_users_json
      t.text :readable_groups_json
      t.text :readable_users_json

      t.timestamps
    end
  end

  def self.down
    drop_table :gw_webmail_public_address_books
  end
end
