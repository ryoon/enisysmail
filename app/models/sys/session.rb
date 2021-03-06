class Sys::Session < ActiveRecord::Base
  set_table_name 'sessions'
  
  def self.delete_past_sessions_at_random(rand_max = 10000)
    return unless rand(rand_max) == 0
    self.delete_expired_sessions
  end
  
  def self.delete_expired_sessions
    expiration = Enisys.config.application['sys.session_expiration']
    self.delete_all(["updated_at < ?", expiration.hours.ago])
  end
  
end