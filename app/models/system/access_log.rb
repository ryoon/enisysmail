# coding: utf-8

class System::AccessLog < ActiveRecord::Base
  establish_connection :jgw_core
  attr_accessible :user_id, :user_code, :user_name, :ipaddress,
    :controller_name, :action_name, :parameters, :feature_id, :feature_name

  before_create :before_create_record

  def logging?
    to_feature_id.present?
  end

  def to_feature_id
    f_id = 'mail'
    f_id = nil if parameters[:mailbox].blank? || parameters[:mailbox] != 'INBOX'

    return f_id.to_s
  end

  def to_feature_name
    return 'メール'
  end

  def before_create_record
    self.feature_id = to_feature_id
    self.feature_name = to_feature_name
    self.parameters = parameters.inspect
  end

end
