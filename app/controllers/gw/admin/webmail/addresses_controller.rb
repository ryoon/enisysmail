# encoding: utf-8
class Gw::Admin::Webmail::AddressesController < Gw::Controller::Admin::Base
  include Sys::Controller::Scaffold::Base
  layout "admin/gw/webmail"
  helper Gw::AddressHelper
  
  def pre_dispatch
    #return error_auth unless Core.user.has_auth?(:designer)
  end
  
  def index
    return render(:text => '')
    
    item = Gw::WebmailAddress.new.readable
    item.and :group_id, @parent.id if @parent
    item.and :user_id, Core.user.id
    item.page  params[:page], params[:limit]
    item.order params[:sort], 'kana, id'
    @items = item.find(:all)
    _index @items
  end
  
  def show
    @item = Gw::WebmailAddress.new.find(params[:id])
    return error_auth unless @item.readable?
    
    @item.in_groups = @item.groups.collect {|g| g.id}.join(",")
    
    _show @item
  end

  def new
    @item = Gw::WebmailAddress.new()
  end
  
  def create
    @item = Gw::WebmailAddress.new(params[:item])
    @item.user_id = Core.user.id
    
    _create(@item, :location => gw_webmail_address_groups_path)
  end
  
  def update
    @item = Gw::WebmailAddress.new.find(params[:id])
    return error_auth unless @item.editable?
    @item.attributes = params[:item]
    @item.user_id = Core.user.id
    
    _update(@item, :location => gw_webmail_address_groups_path)
  end
  
  def destroy
    @item = Gw::WebmailAddress.new.find(params[:id])
    return error_auth unless @item.deletable?
    
    _destroy(@item, :location => gw_webmail_address_groups_path)
  end

  def create_mail
    @item = Gw::WebmailAddress.new.find(params[:id])
    return error_auth unless @item.readable?
    flash[:mail_to] = "#{@item.name} <#{@item.email}>"
    redirect_to new_gw_webmail_mail_path('INBOX')
  end

  # === CSVインポート画面 アクション
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def import
    @csv_form = RumiHelper::CsvForm.new_import_mode
  end

  # === CSVインポート確認画面 アクション
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def candidate_import
    @csv_form = RumiHelper::CsvForm.new(params[:rumi_helper_csv_form] || {})

    begin
      raise @csv_form.error_full_messages if @csv_form.invalid?

      values = Gw::WebmailAddress.candidate_import_csv(@csv_form)

      @valid_addresses = values[:valid_addresses]
      @invalid_addresses = values[:invalid_addresses]
      @new_groups = values[:new_groups]

      respond_to do |format|
        format.html { render action: :candidate_import }
      end

    rescue => e
      flash.now[:notice] = I18n.t("rumi.private_address_book.action.csv.import.message.error")

      # 本番のログでも出力する
      Rails.logger.error "[ERROR] private address candidate_import_csv Invalid Error"
      Rails.logger.error e.inspect
      Rails.logger.error e.backtrace.join("\n") if e.respond_to?(:backtrace)

      respond_to do |format|
        format.html { render action: :import }
      end
    end
  end

  # === CSVインポート実行 アクション
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def exec_import
    candidate_data = params[:candidate_data] || {}
    # CSV形式を特定するためインスタンスを生成
    csv_form = RumiHelper::CsvForm.new(format_type: params[:csv_format_type])

    begin
      Gw::WebmailAddress.import_csv(candidate_data, csv_form)

      flash[:notice] = I18n.t("rumi.private_address_book.action.csv.import.message.success")
    rescue => e
      # 本番のログでも出力する
      Rails.logger.error "[ERROR] public address exec_import_csv Invalid Error"
      Rails.logger.error e.inspect
      Rails.logger.error e.backtrace.join("\n") if e.respond_to?(:backtrace)

      flash[:notice] = I18n.t("rumi.private_address_book.action.csv.import.message.error")
    ensure
      respond_to do |format|
        format.html { redirect_to action: :import }
      end
    end

  end

  # === CSVエクスポート画面 アクション
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def export
    @csv_form = RumiHelper::CsvForm.new_export_mode
  end

  # === CSVエクスポート実行 アクション
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  なし
  def exec_export
    @csv_form = RumiHelper::CsvForm.new(params[:rumi_helper_csv_form] || {})

    begin
      raise @csv_form.error_full_messages if @csv_form.invalid?

      csv_string = Gw::WebmailAddress.to_csv(@csv_form)
      filename = Gw::WebmailAddress.export_csv_filename(@csv_form)

      send_data csv_string, filename: filename, type: "text/csv", disposition: "attachment"

    rescue => e
      flash.now[:notice] = I18n.t("rumi.private_address_book.action.csv.export.message.error")

      # 本番のログでも出力する
      Rails.logger.error "[ERROR] private address exec_export_csv Invalid Error"
      Rails.logger.error e.inspect
      Rails.logger.error e.backtrace.join("\n") if e.respond_to?(:backtrace)

      respond_to do |format|
        format.html { render action: :export }
      end
    end
  end

protected
  
  def return_path(item)
    item.group_id ? gw_webmail_address_group_path(item.group_id) : gw_webmail_address_groups_path
  end
  
  def conv_lf(s)
    s ? s.gsub("\n", '') : nil
  end
  
  def split_addr(addr)
    addr = addr.to_s
    match = addr.scan(/(.+[都|道|府|県])(.+[市|区|町|村])(.*)/)
    return match[0] if match.length >= 1 && match[0].length == 3
    return [addr, '', '']
  end
  
  def get_dispname(data)
    disp = data['表示名'].to_s
    return disp if disp != ""
    names = [data['姓'].to_s, data['ミドル ネーム'].to_s, data['名'].to_s]
    return names.join(" ").strip
  end
  
  def check_duplication_email(email)
    check = Gw::WebmailAddress.find(:all, 
         :select => "*", :conditions => {:email => email, :user_id => Core.current_user.id})
    if check.size == 0
      return true
    else
      return false
    end
  end
end
