# coding: utf-8
module RumiHelper

  # RumiHelper#build_select_parent_groupsで使用するoptions
  PARENT_GROUP_SETTINGS = {
    default: {
      without_disable: true,
      include_no_limit: false
    },
    include_no_limit: {
      without_disable: true,
      include_no_limit: true
    }
  }

  # get_users アクションへのURL
  GET_USERS_URL = "/_api/gw/webmail/get_users"

  # shared/select_group で利用する get_users アクションへのparams
  GET_USERS_SETTINGS = {
    default: {
      s_genre: "group_id",
      without_level_no_2_organization: true
    },
    public_address_book_role: {
      s_genre: "group_id",
      without_level_no_2_organization: false
    }
  }

  # get_child_groups アクションへのURL
  GET_CHILD_GROUPS_URI = "/_api/gw/webmail/get_child_groups"

  # shared/select_group で利用する get_child_groups アクションへのparams
  GET_CHILD_GROUPS_SETTINGS = {
    default: {
      s_genre: "group_id",
      without_disable: true
    }
  }

  # === 通常のグループ選択UI Modeのシンボルを返す
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  Symbol
  def ui_mode_groups_default
    return :groups_default
  end

  # === 制限なしを選択肢に含むグループ選択UI Modeのシンボルを返す
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  Symbol
  def ui_mode_groups_include_no_limit
    return :groups_include_no_limit
  end

  # === グループ選択UI Modeか判定する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def ui_mode_groups?(ui_mode)
    return [ui_mode_groups_default, ui_mode_groups_include_no_limit].include?(ui_mode)
  end

  # === 通常のユーザー選択UI Modeのシンボルを返す
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  Symbol
  def ui_mode_users_default
    return :users_default
  end

  # === 共有アドレス帳管理権限のユーザー選択UI Modeのシンボルを返す
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  Symbol
  def ui_mode_users_public_address_book_role
    return :users_public_address_book_role
  end

  # === ユーザー選択UI Modeか判定する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def ui_mode_users?(ui_mode)
    return [ui_mode_users_default, ui_mode_users_public_address_book_role].include?(ui_mode)
  end

  # === 共有アドレス帳関連の処理か判定する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  boolean
  def public_address_action_member?
    return !!(controller_name =~ /^public_address/) || @book.present?
  end

  # === Gwにおけるプロフィール画面へのリンクを生成する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  Gwにおけるプロフィール画面へのリンク
  def link_to_show_profile
    url = Enisys::Config.application["gw.root_url"]
    display_name = h(safe{Core.user.name_with_account})

    if url.blank?
      return display_name
    else
      begin
        show_profile_url = URI.join(url, "/system/users/#{Core.user.account}/show_profile").to_s
      rescue
        # 有効でないURLの場合はリンクを付加しない
        return display_name
      else
        return link_to(display_name, show_profile_url)
      end
    end
  end

  # === 個人/共有アドレス帳のグループが選択された際のアドレス更新Ajax付きリンクを作成するメソッド
  #
  # ==== 引数
  #  * group_name: 表示するグループ名
  #  * group_id: Ajaxで送信するグループID
  #  * book_id: Ajaxで送信する共有アドレス帳ID
  #  * opt_current_group_id: 選択中のグループID
  # ==== 戻り値
  #  Ajax付きリンク
  def link_to_update_affiliated_address(group_name, group_id, opt_current_group_id = 0)
    links_css = ["address_group_link"]
    links_css << "current" if group_id == opt_current_group_id

    # 共有アドレス帳
    if public_address_action_member?
      ajax_url = update_affiliated_address_gw_webmail_public_address_group_path(
        id: group_id, book_id: @book.id, s_name_or_kana: params[:s_name_or_kana], s_email: params[:s_email])
    # 個人アドレス帳
    else
      ajax_url = update_affiliated_address_gw_webmail_address_group_path(
        id: group_id, s_name_or_kana: params[:s_name_or_kana], s_email: params[:s_email])
    end

    return link_to(group_name, "#", id: "group#{group_id}", class: links_css.join(" "),
      onclick: remote_function(update: "addressesAll", method: :get, url: ajax_url,
      complete: "jQuery('#addressesAll').show();", before: "jQuery('#addressesAll').hide();"))
  end

  # === 個人/共有アドレス帳を検索した時に使用する仮想の検索結果グループID
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  仮想の検索結果グループID
  def address_search_group_id
    return "search"
  end

  # === 個人/共有アドレス帳の初期表示の仮想のすべてグループID
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  仮想のすべてグループID
  def all_address_group_id
    return 0
  end

  # === 個人/共有アドレス帳の初期表示の選択済みグループIDを返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  検索した場合：検索結果グループID / デフォルト:すべてグループID
  def inital_current_address_group_id
    if params[:search].present?
      return address_search_group_id
    else
      return all_address_group_id
    end
  end

  # === 個人/共有アドレス帳の初期表示の選択済みグループ名を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  検索した場合：検索結果グループ名 / デフォルト:すべてグループ名
  def inital_current_address_group_name
    if params[:search].present?
      return t("rumi.public_address_group.search_group.name")
    else
      return t("rumi.public_address_group.all_address_group.name")
    end
  end

  # === 共有アドレス帳のURLクエリを生成するメソッド
  #
  # ==== 引数
  #  * options: 各Modelのインスタンス
  # ==== 戻り値
  #  Hash
  def build_public_address_path_queries(options = {})
    book = (options.key?(:book) && options[:book]) || @book
    group = (options.key?(:group) && options[:group]) || @group
    address = (options.key?(:address) && options[:address]) || nil

    public_address_path_queries = {}
    public_address_path_queries.store(:book_id, book.id) if book.present?
    public_address_path_queries.store(:group_id, group.id) if group.present?
    public_address_path_queries.store(:id, address.id) if address.present?

    return public_address_path_queries
  end

  # === アドレスグループ選択UIにて階層レベルを表す表現の選択肢を返却する
  #
  # ==== 引数
  #  * groups: Gw::WebmailPublicAddressGroup
  #  * without_group: Gw::WebmailPublicAddressGroup
  # ==== 戻り値
  #  配列(options_for_selectで使用するため)
  def build_select_address_groups(groups, without_group = nil)
    return Gw::WebmailPublicAddressGroup.sorted_address_groups(
      groups, without_group).map { |group| group.to_select_option }
  end

  # === アドレスグループ表示画面にて階層レベルをパンくずリスト表現の文字列を返却する
  #
  # ==== 引数
  #  * book: Gw::WebmailPublicAddressBook
  #  * target_groups: Gw::WebmailPublicAddressGroup
  # ==== 戻り値
  #  パンくずリスト表現の文字列
  def build_breadcrumbs_list_address_groups(book, target_groups)
    without_groups = book.groups.without_target_groups(target_groups)
    sorted_address_groups = Gw::WebmailPublicAddressGroup.sorted_address_groups(
      book.groups, without_groups, false)
    return sorted_address_groups.map { |group| group.to_breadcrumbs_list }
  end

  # === ユーザー選択UIの選択肢を返却する
  #
  # ==== 引数
  #  * users: Sys::User
  #  * value_method: Symbol e.g. :code
  # ==== 戻り値
  #  配列(options_for_selectで使用するため)
  def build_select_users(users, value_method = :id)
    return users.map { |user| user.to_select_option(value_method) }
  end

  # === 所属選択UIにて階層レベルを表す表現の選択肢を返却する
  #
  # ==== 引数
  #  * groups: Sys::Group
  #  * value_method: Symbol e.g. :code
  # ==== 戻り値
  #  配列(options_for_selectで使用するため)
  def build_select_groups(groups, value_method = :id)
    return groups.map { |group| group.to_select_option(value_method) }
  end

  # === 所属選択UIにて階層レベルを表す表現の選択肢を返却する
  #
  # ==== 引数
  #  * groups: Sys::Group || Gwcircular::CustomGroup || nil
  #  * options: Hash || nil
  #      e.g. without_disable: boolean, include_no_limit: boolean
  #  * value_method: Symbol e.g. :code
  # ==== 戻り値
  #  配列(options_for_selectで使用するため)
  def build_select_parent_groups(groups = nil, options = RumiHelper::PARENT_GROUP_SETTINGS[:default], value_method = :id)
    no_relation = groups.is_a?(Array)
    # 制限なしを表示するか
    include_no_limit = options.key?(:include_no_limit) && options[:include_no_limit] == true

    show_groups = []
    show_groups << Sys::Group.no_limit_group if include_no_limit

    if no_relation
      show_groups << groups.to_a
    else
      # 無効なグループを表示するか
      without_disable = options.key?(:without_disable) && options[:without_disable] == true

      groups = Sys::Group.order(:id) if groups.nil?
      groups = groups.without_disable if without_disable

      # Sys::Groupの場合
      if groups.first.is_a?(Sys::Group)
        # 階層レベル2, 3のみ
        groups = groups.without_root
        groups = groups.order_sort_no_and_code
        # 階層レベル、グループIDの昇順でソートする
        groups.extract_level_no_2.each do |level_2_group|
          show_groups << level_2_group
          show_groups << groups.where(parent_id: level_2_group.id).to_a
        end
      # その他、Gwcircular::CustomGroupの場合
      else
        show_groups << groups.to_a
      end
    end

    return build_select_groups(show_groups.flatten.compact, value_method)
  end

  # === 共有アドレス帳選択UIの選択肢を返却する
  #
  # ==== 引数
  #  * books: 共有アドレス帳
  # ==== 戻り値
  #  配列(options_for_selectで使用するため)
  def build_select_public_address_books(books)
    return books.map { |book| [book.name, book.id] }
  end

  # === メール作成ボタンを作成するメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  HTML
  def build_create_mail_button
    create_mail_title = t("rumi.operation.create_mail.name")
    return link_to(create_mail_title, "#", class: "create", title: create_mail_title,
      onclick: "return createMail();")
  end

  # === 最新のグループ名、codeにするメソッド
  #
  # ==== 引数
  #  * values: string(JSON形式)
  # ==== 戻り値
  #  string(JSON形式)
  def update_select_group_values(values)
    return nil if values.blank?

    group_infos = JSON.parse(values)
    show_values = group_infos.map do |group_info|
      origin_group = Sys::Group.where(id: group_info[1]).first
      # 制限なしの場合
      origin_group = Sys::Group.no_limit_group if origin_group.blank? && Sys::Group.no_limit_group_id?(group_info[1])
      if origin_group
        origin_group.to_json_option
      else
        # 予期せぬデータの場合
        group_info
      end
    end

    return show_values.to_s
  end

  # === 最新のユーザー名、codeにするメソッド
  #
  # ==== 引数
  #  * values: string(JSON形式)
  # ==== 戻り値
  #  string(JSON形式)
  def update_select_user_values(values)
    return nil if values.blank?

    user_infos = JSON.parse(values)
    show_values = user_infos.map do |user_info|
      origin_user = Sys::User.where(id: user_info[1]).first
      if origin_user
        origin_user.to_json_option
      else
        # 予期せぬデータの場合
        user_info
      end
    end

    return show_values.to_s
  end

  # === 所属選択UIにてIDの重複がないようにuniqな文字列を返却する
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  文字列(a-zの内20文字がランダムで入る)
  def create_uniq_id
    return ("a".."z").to_a.sample(20).join
  end

  # === 所属選択UIにてフォーム送信するitem名をIDにした場合の文字列を返却する
  #
  # ==== 引数
  #  * item_name: 文字列 e.g. item[editable_groups_json]
  # ==== 戻り値
  #  文字列 e.g. item_editable_groups_json
  def trim_form_item_name(item_name)
    return item_name.sub(/\[/, "_").sub(/\]/, "")
  end

  # === アンダーバーで文字列を結合するメソッド
  #
  # ==== 引数
  #  * args: 複数の文字列
  # ==== 戻り値
  #  文字列
  def join_underbar(*args)
    return args.to_a.join("_")
  end

  # === /で文字列を結合するメソッド
  #
  # ==== 引数
  #  * target_array: 結合対象の配列
  # ==== 戻り値
  #  文字列
  def join_directory_notation(target_array)
    return target_array.to_a.join(I18n.t("rumi.public_address_group.directory_notation"))
  end

  # === 編集操作を表す文字を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  文字列
  def operation_edit_name
    return t("rumi.operation.edit.name")
  end

  # === 削除操作を表す文字を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  文字列
  def operation_destroy_name
    return t("rumi.operation.destroy.name")
  end

  # === 編集操作を表す文字を返すメソッド
  #
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  文字列
  def operation_authority_change_name
    return t("rumi.operation.authority_change.name")
  end

  # === ログアウト時に遷移するURLを生成する
  # === mailのログアウト時はgwのログイン画面を表示する
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  ログアウト時に遷移するURL
  def make_logout_url
    url = Enisys::Config.application["gw.root_url"]

    if url.blank?
      return '/_admin/login'
    else
      begin
        logout_url = URI.join(url, "/_admin/logout").to_s
      rescue
        return '/_admin/login'
      else
        return logout_url
      end
    end
  end

  # === ログイン時に遷移するURLを生成する
  # === mailのログイン時はgwのログイン画面を表示する
  # ==== 引数
  #  * なし
  # ==== 戻り値
  #  ログイン時に遷移するURL
  def make_login_url
    url = Enisys::Config.application["gw.root_url"]

    if url.blank?
      return ''
    else
      begin
        login_url = URI.join(url, "/_admin/login").to_s
      rescue
        return ''
      else
        return login_url
      end
    end
  end

  # === 必須項目の項目列に表示するHTMLを返すメソッド
  #
  # ==== 引数
  #  * str: 表示する文字列
  # ==== 戻り値
  #  HTML
  def required(str = "※")
    return ("<span class='required'>#{str}</span>").html_safe
  end

  # === メールツリーを生成するためのヘルパー
  def create_mail_tree(mailbox, mailboxes)
    tree = ""
    plv  = 0

    mailboxes.each_with_index do |box, idx|
      clv       = box.parents_count
      idt       = "  " * clv
      if box.name =~ /^(INBOX|Drafts|Sent|Trash|Star)$/
        li_class = [box.name.downcase]
      else
        li_class = ["folder", "dragdrop"]
      end
      li_class  = %Q(class="#{li_class.join(' ')}")
      nm_class  = ["name"]
      nm_class << "current" if box.name == mailbox.name
      nm_class << "unseen" if box.unseen > 0
      nm_class << "droppable" if box.name !~ /^(Drafts|Star)$/
      nm_class = nm_class.join(' ')

      tree += "</li></ul>" * (plv - clv) if clv < plv
      if clv > plv
        plv.upto(clv - 1) {|i|
          tree += %Q(<ul class="children level#{(i + 1)}">\n#{idt}<li class="folder dragdrop">) }
      elsif idx > 0
        tree += %Q(</li>\n#{idt}<li #{li_class}>)
      else
        tree += %Q(\n#{idt}<li #{li_class}>)
      end
      tree += %Q(<a href="#{url_for(:action => :index, :mailbox => box.name)}" class="#{nm_class}" id="mailbox_#{box.name}">#{ERB::Util.html_escape(box.title)}</a>)
      tree += %Q{<span class="unseenNum">(<span class="num">#{box.unseen}</span>)</span>} if box.unseen > 0

      if box.trash_box? && (box.messages > 0 || box.children.length > 0)
        tree += %Q(<a href="#{empty_gw_webmail_mails_path(box.name)}" class="empty" onclick="return confirm('空にしてよろしいですか？');">≫空にする</a>)
      end

      tree += %Q(</li>) if mailboxes.size == idx + 1

      plv = clv
    end
    tree = %Q(<ul class="root">#{tree}</ul>) if !tree.blank?

  end

  # === テーブルが無いがvalidationを実行したいフォームに対応するクラス
  #
  class ActiveForm
    include ActiveModel::Validations
    include ActiveModel::Conversion
    extend  ActiveModel::Naming

    # === 初期化
    #
    # ==== 引数
    #  * attributes: Hash
    # ==== 戻り値
    #  ActiveFormクラスのインスタンス
    def initialize(attributes = nil)
      # Mass Assignment implementation
      if attributes
        attributes.each do |key, value|
          self[key] = value
        end
      end
      yield self if block_given?
    end

    # === Getter
    #
    # ==== 引数
    #  * key: Attr名
    # ==== 戻り値
    #  Attr名のインスタンス変数の値
    def [](key)
      instance_variable_get("@#{key}")
    end

    # === Setter
    #
    # ==== 引数
    #  * key: Attr名
    # ==== 戻り値
    #  なし
    def []=(key, value)
      instance_variable_set("@#{key}", value)
    end

    # === 未保存のレコードか?
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  常にtrue
    def new_record?
      true
    end

    # === 保存済みのレコードか?
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  常にfalse
    def persisted?
      false
    end

    # === idのgetter
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  常にnil
    def id
      nil
    end

  end

  # === CSVインポート画面のフォームに使用するクラス
  #
  class CsvForm < ActiveForm
    FORM_MODES = ["import", "export"]
    FORMAT_TYPES = ["rumi_address_csv", "win_ms_address_csv"]

    # 許可するattr
    attr_accessor :file, :form_mode, :format_type

    validates :form_mode, inclusion: { in: RumiHelper::CsvForm::FORM_MODES }
    validates :format_type, inclusion: { in: RumiHelper::CsvForm::FORMAT_TYPES }

    # CSVインポート時は必須とする
    validates :file, presence: true, if: Proc.new{ |record| record.import_mode? }
    validate :ext_name_valid, if: Proc.new{ |record| record.import_mode? && file.present? }


    # === 拡張子の検証
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  なし
    def ext_name_valid
      ext_name = File.extname(file.original_filename)
      errors.add :file, I18n.t("rumi.rumi_helper.csv_form.file.message.invalid") if ".csv" != ext_name
    end

    # === 縁sys用か?
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  boolean
    def format_rumi?
      return self.format_type == RumiHelper::CsvForm.format_rumi_value
    end

    # === Windows Essentials用か?
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  boolean
    def format_win_ms?
      return self.format_type == RumiHelper::CsvForm.format_win_ms_value
    end

    # === CSVインポート画面か?
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  boolean
    def import_mode?
      return self.form_mode == RumiHelper::CsvForm.import_mode
    end

    # === CSVエクスポート画面か?
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  boolean
    def export_mode?
      return self.form_mode == RumiHelper::CsvForm.export_mode
    end

    # === エラーメッセージを一行で表した文字列を返すメソッド
    #
    # ==== 引数
    #  * なし
    # ==== 戻り値
    #  エラーメッセージ
    def error_full_messages
      return self.errors.full_messages.join("<br />").html_safe
    end

    class << self

      # === 形式の選択肢を返すメソッド
      #
      # ==== 引数
      #  * なし
      # ==== 戻り値
      #  [name, value]
      def format_types
        format_names = I18n.t("activemodel.attributes.rumi_helper/csv_form.format_names")
        return RumiHelper::CsvForm::FORMAT_TYPES.map { |value| [format_names[value.to_sym] , value] }
      end

      # === 形式で縁sys用を表す文字列を返すメソッド
      #
      # ==== 引数
      #  * なし
      # ==== 戻り値
      #  文字列
      def format_rumi_value
        return RumiHelper::CsvForm::FORMAT_TYPES.first
      end

      # === 形式でWindows Essentials用を表す文字列を返すメソッド
      #
      # ==== 引数
      #  * なし
      # ==== 戻り値
      #  文字列
      def format_win_ms_value
        return RumiHelper::CsvForm::FORMAT_TYPES.last
      end

      # === CSVインポート画面のフォームの初期値を設定したものを返す
      #
      # ==== 引数
      #  * なし
      # ==== 戻り値
      #  CsvFormのインスタンス
      def new_import_mode
        return RumiHelper::CsvForm.new(
          form_mode: RumiHelper::CsvForm.import_mode,
          format_type: RumiHelper::CsvForm.format_rumi_value)
      end

      # === CSVエクスポート画面のフォームの初期値を設定したものを返す
      #
      # ==== 引数
      #  * なし
      # ==== 戻り値
      #  CsvFormのインスタンス
      def new_export_mode
        return RumiHelper::CsvForm.new(
          form_mode: RumiHelper::CsvForm.export_mode,
          format_type: RumiHelper::CsvForm.format_rumi_value)
      end

      # === CSVインポート画面モード
      #
      # ==== 引数
      #  * なし
      # ==== 戻り値
      #  string
      def import_mode
        RumiHelper::CsvForm::FORM_MODES.first
      end

      # === CSVエクスポート画面モード
      #
      # ==== 引数
      #  * なし
      # ==== 戻り値
      #  string
      def export_mode
        RumiHelper::CsvForm::FORM_MODES.last
      end

    end

  end

end
