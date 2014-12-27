class LoadInitalSchema < ActiveRecord::Migration
  def self.up
    load Rails.root.join('db', 'inital_schema.rb').to_s
  end

  def self.down
  end
end
