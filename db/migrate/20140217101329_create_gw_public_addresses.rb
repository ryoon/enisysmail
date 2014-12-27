class CreateGwPublicAddresses < ActiveRecord::Migration
  def self.up
    create_table :gw_webmail_public_addresses do |t|
      t.integer :public_address_book_id

      t.string :name
      t.string :kana
      t.integer :sort_no
      t.integer :state
      t.string :email
      t.string :mobile_tel
      t.string :uri
      t.string :tel
      t.string :fax
      t.string :zip_code
      t.string :address
      t.string :company_name
      t.string :company_kana
      t.string :official_position
      t.string :company_tel
      t.string :company_fax
      t.string :company_zip_code
      t.string :company_address
      t.string :memo

      t.timestamps
    end
  end

  def self.down
    drop_table :gw_webmail_public_addresses
  end
end
