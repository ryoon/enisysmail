class CreateGwPublicAddressGroups < ActiveRecord::Migration
  def self.up
    create_table :gw_webmail_public_address_groups do |t|
      t.integer :public_address_book_id

      t.integer :parent_id
      t.integer :level_no
      t.string :name

      t.timestamps
    end
  end

  def self.down
    drop_table :gw_webmail_public_address_groups
  end
end
