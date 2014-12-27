// name scope
var rumi = {};

//
// rumi.attachment コンストラクタ
//
rumi.attachment = function(elem_id, maxsize, maxname) {
  var obj = this;
  this.maxname = maxname;

  jQuery("body").live({
    dragover: function(e) {
      if (e.originalEvent.dataTransfer.types[0] == "Files") {
        jQuery("#" + elem_id).removeClass("hover_normal").addClass("hover_window");
      }
    },
    dragleave: function(e) {
      jQuery("#" + elem_id).removeClass("hover_window").addClass("hover_normal");
    }
  });

  jQuery("#" + elem_id).live({
    dragover: function(e) {
      if (e.originalEvent.dataTransfer.types[0] == "Files") {
        e.preventDefault();
        e.stopPropagation();
        jQuery("#" + elem_id).removeClass("hover_window").addClass("hover_self");
      }
    },
    dragleave: function(e) {
      jQuery("#" + elem_id).removeClass("hover_self").addClass("hover_window");
    },
    drop: function(e) {
      jQuery("#" + elem_id).removeClass("hover_self").addClass("hover_normal");
      submit_file(e.originalEvent.dataTransfer.files);
      return false;
    }
  });

  submit_file = function(files) {
    if (files.length == 0) {
      alert("ファイルではないものを添付することはできません。");
      return false;
    }

    var form_data = new FormData();
    form_data.append('authenticity_token',
             jQuery('meta[name="csrf-token"]').attr('content'));

    form_data.append('dnd_tmp_id', jQuery('#item_tmp_id').val());

    var totalsize = 0;
    var html = "";
    for (var i = 0; i < files.length; i++) {
      if (!obj.name_check(files[i])) {
        alert("ファイル名が長すぎるため保存できませんでした。");
        return false;
      }

      if (files[i].size == 0) {
        alert("サイズが 0 byte のファイルは添付できません。");
        return false;
      }
      form_data.append("dnd_file[" + i + "]", files[i]);
      totalsize += files[i].size;
      if (i != 0) html += "<br />";
      html += files[i].name;
    }

    if (totalsize > maxsize*1024*1024) {
      alert("ファイルサイズが容量制限（" + maxsize + "MB）を超えています。");
      return false;
    }

    $("defaultUploaderProgressName").innerHTML = html;
    $("defaultUploaderProgress").style.display = "block";

    jQuery.ajax(
      "/_admin/gw/webmail/INBOX/mails/dnd_upload",
      {
        type: "POST",
        contentType: false,
        processData: false,
        data: form_data
      }).success(function(e) {
        $("defaultUploaderProgress").style.display = "none";
        if (e.status == 'OK') {
          jQuery("#uploadedFiles>span").remove()
          loadUploadedFiles();
        } else {
          alert(e.message);
        }
      }).error(function(e) {
        $("defaultUploaderProgress").style.display = "none";
        alert("ファイルのアップロードに失敗しました。");
      });
  };
};

// 添付ファイル名の長さチェック
rumi.attachment.prototype.name_check = function(file) {
  if (this.bytesize(file.name) > this.maxname) {
    return false;
  } else {
    return true;
  }
};

// 文字列のバイト数をカウント
rumi.attachment.prototype.bytesize = function(str) {
  var encode_str = encodeURI(str);
  return encode_str.length - (encode_str.split("%").length - 1) * 2;
};

//
// rumi.dragdrop コンストラクタ
//
rumi.dragdrop = function(file_move_action, folder_move_action) {
  jQuery('table.mails td.drag').draggable({
    opacity: 0.8,
    cursor: 'move',
    helper: function(e) {
      var container = jQuery('<td />');
      var target = jQuery(e.currentTarget).parents('table.mails tr.mail');
      jQuery('table.mails tr.mail').each(function() {
        if ( jQuery(this).get(0) == target.get(0) || jQuery(this).find('input').is(':checked')) {
          var elm = jQuery('<span />').text(jQuery(this).find('td.subject a').text());
          elm.css('padding', '0px 12px');
          container.append(elm);
        }
      });
      return container;
    }
  });

  jQuery('.mailbox .droppable').droppable({
    hoverClass: "ui-hover",
    activeClass: "ui-active",
    tolerance: "pointer",
    greedy: true,
    drop: function(e, ui) {
      var elem_id = ui.draggable.attr('id');
      var distbox = jQuery(e.target).attr('id').gsub(/^mailbox_/, '');
      if (elem_id.search(/^drag_/) != -1) {
        // move file
        var uid = elem_id.gsub(/^drag_/, '');
        jQuery('#mails').append(jQuery('<input />').attr({
          type: 'hidden', name: 'item[mailbox]', value: distbox
        }));
        jQuery('#mails').append(jQuery('<input />').attr({
          type: 'hidden', name: 'item[ids][' + uid + ']', value: 1
        }));
        post(file_move_action);
      } else {
        // move folder
        var srcbox = elem_id.gsub(/^mailbox_/, '');
        jQuery('#mails').append(jQuery('<input />').attr({
          type: 'hidden', name: 'item[srcbox]', value: srcbox }));
        jQuery('#mails').append(jQuery('<input />').attr({
          type: 'hidden', name: 'item[distbox]', value: distbox }));
        post(folder_move_action);
      }
    }
  });

  jQuery("#webmailMenu .mailbox li.folder a").draggable({
    opacity: 0.8,
    cursor: "move",
    helper: "clone",
    drag: function(e) { },
    stop: function(e) { }
  });
};

//
// rumi.polling コンストラクタ
//
rumi.polling = function(url, min) {
  if (min == 0) {
    return;
  }

  var interval = min * 1000 * 60;
  mail_check = function(url) {
    var obj = this;
    jQuery.ajax({
      url: url,
      type: "GET",
      dataType: "json",
      complete: setTimeout("mail_check('" + url + "')", interval)
    }).success(function(obj) {
      if (obj.status == "OK" && obj.new_mail == true) {
        if (confirm("メールが届きました。メールのリストを再読み込みしますか？")) {
          location.reload();
        }
      }
    });
  };

  setTimeout("mail_check('" + url + "')", interval);
};

//
// rumi.preview コンストラクタ
//
rumi.preview = function(list_height, opt_id) {
  var obj = this;
  obj.list_height = list_height;

  jQuery("td.from a").click(function(e) {
    e.stopPropagation();
  });

  jQuery("td.subject, td.from, td.mailbox, td.date, td.size").click(function() {
    obj.mail_id = jQuery(this).parents('tr').attr("id").sub(/^mail_/, "");
    obj.open();
  });

  jQuery("#close_mail").click(function() {
    obj.close();
  });

  var menus = [];
  menus.push('labelMenu');
  PopupMenu.init(menus);

  if (opt_id) {
    obj.mail_id = opt_id;
    obj.open();
  }
};

// プレビュー画面オープン
rumi.preview.prototype.open = function() {
  var obj = this;
  var mail_url = jQuery("#selected_mail_box").val() + "/" + obj.mail_id;

  jQuery("span.labels" + obj.mail_id).hide();
  jQuery("span.loading" + obj.mail_id).show();

  jQuery.ajax({
    url: mail_url,
    type: "GET",
    dataType: "json",
    data: obj.mail_id
  }).success(function(e) {
    preview_open(e.id, e.html);
    jQuery('div.mailbox').html(e.tree);
    var noread = e.noread;
    if (noread != null) {
     rumi.unread.showMailCount(Number(noread));
    }
  }).error(function(e) {
    alert("メールの取得に失敗しました。");
    show_label(this.data);
  });

  preview_open = function(mail_id, html) {
    jQuery("tr.selected[id^='mail_']").removeClass("selected");
    jQuery("#mail_" + mail_id).removeClass("unseen").addClass("selected");
    jQuery("#mail_body").html(html);
    jQuery("#mail_list").height(obj.list_height);

    var menus = [];
    menus.push('labelMenu');
    menus.push('answerMenuBody');
    menus.push('etcMenuBody');
    menus.push('labelMenuBody');
    menus.push('labelMenuBody');
    PopupMenu.init(menus);

    show_label(mail_id);
  };

  show_label = function(id) {
    jQuery("span.loading" + id).hide();
    jQuery("span.labels" + id).show();
  }
};

// プレビュー画面クローズ
rumi.preview.prototype.close = function() {
  jQuery("#mail_" + this.mail_id).removeClass("selected");
  jQuery("#mail_body").html("");
  jQuery("#mail_list").height("auto");
};

//
// rumi.mark コンストラクタ
//
rumi.mark = function(label_url, star_url) {
  this.label_url = label_url;
  this.star_url = star_url;
}

// ラベル操作(複数)
rumi.mark.prototype.labels = function(label_id) {
  var obj = this;
  jQuery("input[name^='item[ids]']:checked").each(function() {
    this.name.match(/item\[ids\]\[(\d+)\]/)
    obj.label(label_id, RegExp.$1);
  });
};

// ラベル操作(単一)
rumi.mark.prototype.label = function(label_id, uid) {
  var obj = this;
  var labels = jQuery("span.labels" + uid);
  var loading = jQuery("span.loading" + uid);

  labels.hide();
  loading.show();
  jQuery.ajax({
    url: obj.label_url,
    type: "GET",
    data: { id: uid, label: label_id }
  }).success(function(data, dataType) {
    labels.html(data);
    if (data == "") {
      labels.hide();
    } else {
      labels.show();
    }
    loading.hide();
  }).error(function(request, status) {
    alert("通信に失敗しました。");
    labels.show();
    loading.hide();
  });
};

// スター操作
rumi.mark.prototype.star = function(uid) {
  var obj = this;
  var star = jQuery(".star" + uid);
  star.addClass("loading");

  var before_stat = star.hasClass("starOn");
  var star_menu = jQuery("a.star_menu" + uid);
  jQuery.ajax({
    url: obj.star_url,
    type: "GET",
    data: { id: uid }
  }).success(function() {
    if (before_stat) {
      star.removeClass("starOn").addClass("starOff");
      star.attr("title", "");
      star_menu.html("スターを付ける");
    } else {
      star.removeClass("starOff").addClass("starOn");
      star.attr("title", "スター");
      star_menu.html("スターをはずす");
    }
    star.removeClass("loading")
  }).error(function() {
    alert("通信に失敗しました。");
    star.removeClass("loading");
  });
};

/**
 * Elementを活性／非活性にするメソッド
 * @param {Element} element
 * @param {boolean} disabled
 * @return {void}
 */
rumi.setDisabled = function(element, disabled) {
  if (disabled) {
    element.attr("disabled", "disable");
  } else {
    element.removeAttr("disabled");
  }
};

// ui namespace
rumi.ui = {};

// current css
rumi.ui.CURRENT_CSS = "current";

/**
 * アドレス登録先アドレス帳選択UIを制御するクラス
 */
rumi.ui.addressBookSelector = function() {
  this.book_category = "private_address_book";
  this.book_id = null;
  this.book_id_disabled = true;
};

/**
 * アドレス表示領域、アドレス帳選択UIを表示するメソッド
 * @param {string} container_id
 */
rumi.ui.addressBookSelector.prototype.show = function(container_id) {
  // 非表示にされるアドレス帳選択UIを削除する
  this.exitDocument();

  // 新たに表示されるアドレス帳選択UIを作成する
  this.container = jQuery(rumi.ui.idSelector(container_id));
  this.enterDocument();
};

/**
 * アドレス表示領域、アドレス帳選択UIを表示するメソッド
 */
rumi.ui.addressBookSelector.prototype.enterDocument = function() {
  var element = this.getElement();
  if (element) {
    var scope = this;
    var ajax_url = "/_admin/gw/webmail_sys_addresses/address_book_selector"
    var success_fn = function(request) {
      scope.handleAjaxSuccess(request);
    };
    var error_fn = function(request) {
      alert("送信に失敗しました。");
    };
    rumi.ui.requestAjax(ajax_url, {}, success_fn, error_fn);
  }
};

/**
 * アドレス帳選択UIを削除するメソッド
 */
rumi.ui.addressBookSelector.prototype.exitDocument = function() {
  var element = this.getElement();
  if (element) {
    // 子要素を全て削除
    element.empty();
  }
};

/**
 * アドレス表示領域、アドレス帳選択UIを表示するメソッド
 * @param {XMLHttpRequest} request
 */
rumi.ui.addressBookSelector.prototype.handleAjaxSuccess = function(request) {
  var element = this.getElement();
  if (element) {
    element.append(request);
    this.getBookIdElement().val(this.book_id);
    this.setBookIdDisabled();
    if (this.book_id_disabled) {
      this.getPrivateAddressBookCategoryElement().attr("checked", true);
    } else {
      this.getPublicAddressBookCategoryElement().attr("checked", true);
    }
    this.container.show();
  }
};

/**
 * アドレス帳選択UIを包括するElementを返却するメソッド
 * @return {Element=}
 */
rumi.ui.addressBookSelector.prototype.getElement = function() {
  if (this.container) {
    return this.container.find("div.address-book-selector").first();
  } else {
    return null;
  }
};

/**
 * 共有アドレス帳選択Elementを返却するメソッド
 * @return {Element=}
 */
rumi.ui.addressBookSelector.prototype.getBookIdElement = function() {
  var element = this.getElement();
  if (element) {
    return element.find("select[id='dummy_item_book_id']").first();
  } else {
    return null;
  }
};

/**
 * アドレス帳種別選択(個人アドレス帳)Elementを返却するメソッド
 * @return {Element=}
 */
rumi.ui.addressBookSelector.prototype.getPrivateAddressBookCategoryElement = function() {
  var element = this.getElement();
  if (element) {
    return element.find("input[type='radio'][id='dummy_item_book_category_private_address_book']").first();
  } else {
    return null;
  }
};

/**
 * アドレス帳種別選択(共有アドレス帳)Elementを返却するメソッド
 * @return {Element=}
 */
rumi.ui.addressBookSelector.prototype.getPublicAddressBookCategoryElement = function() {
  var element = this.getElement();
  if (element) {
    return element.find("input[type='radio'][id='dummy_item_book_category_public_address_book']").first();
  } else {
    return null;
  }
};

/**
 * 共有アドレス帳選択Elementの活性/非活性を切り替えるメソッド
 */
rumi.ui.addressBookSelector.prototype.setBookIdDisabled = function() {
  var bookIdElement = this.getBookIdElement();
  if (bookIdElement) {
    rumi.setDisabled(bookIdElement, this.book_id_disabled);
  }
};

/**
 * アドレス帳種別選択値を保存するメソッド
 * @param {string} value
 */
rumi.ui.addressBookSelector.prototype.setBookCategory = function(value) {
  this.book_category = value;
  this.book_id_disabled = "private_address_book" == value;

  // 組織アドレス帳が選択されていた場合は 共有アドレス帳セレクトボックスを非活性化する
  this.setBookIdDisabled();
};

/**
 * 共有アドレス帳選択値を保存するメソッド
 * @param {string} value
 */
rumi.ui.addressBookSelector.prototype.setBookId = function(value) {
  this.book_id = value;
};

/**
 * 共有アドレス帳選択値を返却するメソッド
 * @return {string}
 */
rumi.ui.addressBookSelector.prototype.getBookId = function() {
  return this.book_id;
};

/**
 * アドレス帳種別選択(個人アドレス帳)か評価するメソッド
 * @return {boolean}
 */
rumi.ui.addressBookSelector.prototype.isSelectedPrivateAddressBook = function() {
  return this.book_id_disabled;
};

/**
 * jQuery Selectorを返却するメソッド
 * @param {string} element_id
 * @return {string}
 */
rumi.ui.idSelector = function(element_id) {
  return "#" + element_id;
};

/**
 * jQuery Selectorを返却するメソッド
 * @param {string} value
 * @return {string}
 */
rumi.ui.optionSelector = function(value) {
  return "option[value='" + value + "']";
};

/**
 * Optionを返却するメソッド
 * @param {string} name 選択肢表示名
 * @param {string} value 選択値
 * @param {string} title MouseHover時のツールチップ
 * @return {Element}
 */
rumi.ui.createOptionElement = function(name, value, title) {
  var option = jQuery("<option>").html(name).val(value);
  option.attr("title", title);

  return option;
};

/**
 * アドレスを登録時のエラー処理をするメソッド
 * @param {XMLHttpRequest} request
 * @return {void}
 */
rumi.ui.handleAddAddressError = function(request) {
  var message = "送信に失敗しました。";
  var errors = request.responseXML.getElementsByTagName("error");
  if (errors.length > 0) {
    message = errors[0].firstChild.nodeValue;
  }
  alert(message);
};

/**
 * 個人アドレス帳にアドレスを登録するメソッド
 * @param {string} email
 * @param {string} name
 * @param {string} kana
 * @param {string=} opt_public_address_id
 * @return {void}
 */
rumi.ui.addAddressToPrivateAddressBook = function(email, name, kana, opt_public_address_id) {
  var ajax_url = "/_admin/gw/webmail_addresses.xml";
  var address_values = {
    "easy_entry": true,
    "email": email,
    "name": name,
    "kana": kana
  }
  // 共有アドレス帳から個人アドレス帳にアドレスを登録する際の項目
  if (opt_public_address_id) {
    address_values["copy_public_address_id"] = opt_public_address_id;
  }

  var ajax_data = {
    "item": address_values
  };
  var success_fn = function(request) {
    alert("個人アドレス帳に登録しました。");
  };
  rumi.ui.requestAjax(ajax_url, ajax_data, success_fn, rumi.ui.handleAddAddressError, "POST");
};

/**
 * 共有アドレス帳にアドレスを登録するメソッド
 * @param {string} email
 * @param {string} name
 * @param {string} kana
 * @param {string=} opt_private_address_id
 * @return {void}
 */
rumi.ui.addAddressToPublicAddressBook = function(email, name, kana, book_id, opt_private_address_id) {
  var ajax_url = "/_admin/gw/webmail_public_addresses.xml";
  var address_values = {
    "easy_entry": true,
    "email": email,
    "name": name,
    "kana": kana
  }
  // 個人アドレス帳から共有アドレス帳にアドレスを登録する際の項目
  if (opt_private_address_id) {
    address_values["copy_private_address_id"] = opt_private_address_id;
  }

  var ajax_data = {
    "book_id": book_id,
    "gw_webmail_public_address": address_values
  };
  var success_fn = function(request) {
    alert("共有アドレス帳に登録しました。");
  };
  rumi.ui.requestAjax(ajax_url, ajax_data, success_fn, rumi.ui.handleAddAddressError, "POST");
};

/**
 * TO、CC、BCC選択UIを制御するクラス
 * @param {string} element_id
 * @param {string} name_prefix
 * @param {boolean} opt_checked
 * @constructor
 */
rumi.ui.CheckableColumn = function(element_id, name_prefix, opt_checked) {
  this.element = jQuery(rumi.ui.idSelector(element_id));
  this.checkbox_selector = ["input[type=checkbox][name^=", name_prefix, "]"].join("");
  // private property
  this.checked_ = !!opt_checked;

  // handleClick
  var scope = this;
  this.element.live("click", function(e) {
    scope.setChecked();

    e.preventDefault();
    e.stopPropagation();
  });
};

/**
 * handleClick
 */
rumi.ui.CheckableColumn.prototype.setChecked = function() {
  var checked = !this.checked_;
  jQuery.find(this.checkbox_selector).each(function(checkbox, i) {
    checkbox = jQuery(checkbox);

    if (checked) {
      checkbox.attr("checked", "checked");
    } else {
      checkbox.removeAttr("checked");
    }
  });

  this.checked_ = checked;
};

/**
 * aタグにcurrentクラスを付けるクラス
 * @param {string} parent_element_id
 * @param {string} links_css
 * @param {string} opt_current_css
 * @constructor
 */
rumi.ui.CurrentLinkSetter = function(parent_element_id, links_css, opt_current_css) {
  this.parent_element = jQuery(rumi.ui.idSelector(parent_element_id));
  var selector = ["a.", links_css].join("");
  var target_links = this.parent_element.find(selector);

  var current_css = opt_current_css || rumi.ui.CURRENT_CSS;

  // handleClick
  target_links.live("click", function(e) {
    target_links.removeClass(current_css);
    jQuery(this).addClass(current_css);
  });
};

/**
 * aタグに▲を付けるクラス
 * @param {Element} handler_element
 * @param {string} th_element_id
 * @constructor
 */
rumi.ui.setSortedMark = function(handler_element, th_element_id) {
  handler_element = jQuery(handler_element);
  var th_element = jQuery(rumi.ui.idSelector(th_element_id));

  var current_desc = th_element.hasClass("tablesorter-headerDesc");
  var current_asc = th_element.hasClass("tablesorter-headerAsc");
  var current_text = handler_element.text();

  var asc_mark = "▲";
  var desc_mark = "▼";

  var sortable_table = jQuery(rumi.ui.idSelector("sortable-table"));

  sortable_table.find("th.sortable-th > div > a").each(function(i, handler_link) {
    handler_link = jQuery(handler_link);
    var handler_text = handler_link.text();
    handler_text = handler_text.replace(asc_mark, "");
    handler_text = handler_text.replace(desc_mark, "");

    handler_link.text(handler_text);
  });

  if (!current_desc && !current_asc) {
    handler_element.text(current_text + asc_mark);
  } else {
    if (current_desc) {
      handler_element.text(current_text.replace(desc_mark, asc_mark));
    } else {
      handler_element.text(current_text.replace(asc_mark, desc_mark));
    }
  }
};

/**
 * AjaxRequestメソッド
 * @param {string} ajax_url 送信先URL
 * @param {Object} ajax_data 送信データ
 * @param {Function} success_fn Ajax成功時のメソッド
 * @param {Function=} opt_error_fn Ajax失敗時のメソッド
 * @param {string} opt_method 送信メソッド
 * @return {Element}
 */
rumi.ui.requestAjax = function(ajax_url, ajax_data, success_fn, opt_error_fn, opt_method) {
  var error_fn = opt_error_fn || function(e) {};
  var request_method = opt_method || "GET";
  jQuery.ajax({
    url: ajax_url,
    type: request_method,
    data: ajax_data,
    success: success_fn,
    error: opt_error_fn,
    beforeSend: function() {
      jQuery("body").css("cursor", "wait");
    },
    complete: function() {
      jQuery("body").css("cursor", "default");
    }
  });
};

/**
 * 選択肢UIの選択肢を更新するメソッド
 * @param {JSON?} json レスポンス
 * @param {string} to_id 更新先ID
 * @return {void}
 */
rumi.ui.updateSelectOptions = function(json, to_id) {
  if (json && jQuery.isArray(json)) {
    var to = jQuery(rumi.ui.idSelector(to_id));
    to.children().remove();

    json.each(function(option) {
      to.append(rumi.ui.createOptionElement(option[2], option[1], option[0]));
    });
  }
};

/**
 * 選択肢UIの選択肢を更新するメソッド
 * @param {string} group_id 親グループID
 * @param {string} to_id 更新先ID
 * @param {boolean=} opt_with_level_no_2 階層レベル2のユーザーを表示するか
 * @return {void}
 */
rumi.ui.singleSelectGroupOnChange = function(group_id, to_id, opt_with_level_no_2) {
  var ajax_url = "/_admin/gwboard/ajaxgroups/get_users.json";
  var with_level_no_2 = opt_with_level_no_2 == true;
  var ajax_data = {
    "s_genre": group_id,
    "without_level_no_2_organization": !with_level_no_2
  };

  rumi.ui.requestAjax(ajax_url, ajax_data, function(json) {
    rumi.ui.updateSelectOptions(json, to_id);
  });
};

/**
 * グループ、ユーザー選択UIを制御するクラス
 * @param {string} uniq_id ユニークな文字列
 * @param {string} hidden_item_name フォーム送信時のitem名
 * @param {string} ajax_url ChildList取得URL
 * @param {Object} ajax_data ChildList取得Query
 * @param {number=} opt_fix_json_value JSON要素の固定値
 * @constructor
 */
rumi.ui.SelectGroup = function(uniq_id, hidden_item_name, ajax_url, ajax_data, opt_fix_json_value) {
  this.uniq_id = uniq_id;
  this.hidden_item_name = hidden_item_name;
  this.ajax_url = ajax_url;
  this.ajax_data = ajax_data;

  var ids = rumi.ui.SelectGroup.Ids;
  this.parent_list_id = rumi.ui.idSelector([ids.PREFIX, uniq_id, ids.PARENT].join("_"));
  this.selected_list_id = rumi.ui.idSelector([ids.PREFIX, uniq_id, ids.SELECTED].join("_"));
  this.child_list_id = rumi.ui.idSelector([ids.PREFIX, uniq_id, ids.CHILD].join("_"));
  this.add_btn_id = rumi.ui.idSelector([ids.PREFIX, uniq_id, ids.ADD_BTN].join("_"));
  this.remove_btn_id = rumi.ui.idSelector([ids.PREFIX, uniq_id, ids.REMOVE_BTN].join("_"));

  // 承認UIのみ利用
  this.approval_hook = false;
  this.approval_hidden_item_name_prefix = null;
  this.approval_max_count = null;
  // JSONの最初の要素における固定値
  this.fix_first_factor_json_value = opt_fix_json_value;
};

/**
 * 各UIのID
 * @enum {string}
 */
rumi.ui.SelectGroup.Ids = {
  PREFIX: "dummy",
  PARENT: "parent_list",
  CHILD: "child_list",
  SELECTED: "selected_list",
  ADD_BTN: "add_btn",
  REMOVE_BTN: "remove_btn"
};

/**
 * 部／課局を選択するUIのElementを返却する
 * @return {Element}
 */
rumi.ui.SelectGroup.prototype.getParentList = function() {
  return jQuery(this.parent_list_id);
};

/**
 * 選択済みの選択肢を格納するUIのElementを返却する
 * @return {Element}
 */
rumi.ui.SelectGroup.prototype.getSelectedList = function() {
  return jQuery(this.selected_list_id);
};

/**
 * 選択肢を格納するUIのElementを返却する
 * @return {Element}
 */
rumi.ui.SelectGroup.prototype.getChildList = function() {
  return jQuery(this.child_list_id);
};

/**
 * フォームに送信するitemのElementを返却する
 * @return {Element}
 */
rumi.ui.SelectGroup.prototype.getHiddenItem = function() {
  return jQuery(rumi.ui.idSelector(this.hidden_item_name));
};


/**
 * ApprovalHook時のフォームに送信するitemのElementを返却する
 * @return {jQuery} jQueryオブジェクト
 */
rumi.ui.SelectGroup.prototype.getApprovalHiddenItems = function() {
  return jQuery("[name^='" + this.approval_hidden_item_name_prefix + "']");
};

/**
 * 選択済みUIに選択肢を追加するメソッド
 * @return {void}
 */
rumi.ui.SelectGroup.prototype.addSelectedChild = function() {
  var fr = this.getChildList();
  var to = this.getSelectedList();

  var option = null;
  var option_selector = null;
  var values = fr.val();

  var approval_hook = this.approval_hook;
  var approval_max_count = this.approval_max_count;
  var approval_overflow = false;

  if (values && jQuery.isArray(values)) {
    values.each(function(option_id) {
      option_selector = rumi.ui.optionSelector(option_id);
      // 選択肢が存在しない場合は追加する
      if (to.find(option_selector).length == 0) {
        // 承認UIの場合は選択上限を設定する
        if (approval_hook && to.children().length >= approval_max_count) {
          approval_overflow = true;
        } else {
          option = fr.find(option_selector).first();
          to.append(rumi.ui.createOptionElement(option.text(), option_id, option.attr("title")));
        }
      }

    });

    if (approval_overflow) {
      alert("承認者の設定は5人までです");
    }
  }

  this.updateSelected();
};

/**
 * 選択済みUIから選択肢を削除するメソッド
 * @return {void}
 */
rumi.ui.SelectGroup.prototype.removeSelectedChild = function() {
  var to = this.getSelectedList();
  var values = to.val();

  if (values && jQuery.isArray(values)) {
    values.each(function(option_id) {
      to.find(rumi.ui.optionSelector(option_id)).remove();
    });
  }

  this.updateSelected();
};

/**
 * フォーム送信するitemのvalueを更新するメソッド
 * @return {void}
 */
rumi.ui.SelectGroup.prototype.updateSelected = function() {
  var arr = [];
  var to = this.getSelectedList();
  var record_name = null;
  var first_value = null;
  var fix_first_value = this.fix_first_factor_json_value;

  to.find("option").each(function(i, option) {
    option = jQuery(option);

    // "+-- (グループコード) グループ名" の場合は "グループ名" に変換する
    record_name = option.text();
    record_name = record_name.replace(/^\+\-*\s/, "");

    // 固定値があれば優先する
    if (fix_first_value) {
      first_value = fix_first_value;
    } else {
      first_value = option.attr("title");
    }

    arr.push([first_value, option.val(), record_name]);
  });

  if (this.approval_hook) {
    this.updateSelectedApprovalHook(arr);
  } else {
    this.getHiddenItem().val(Object.toJSON(arr));
  }

};

/**
 * 承認UIのフォーム送信時のパラメータを HookするFunction を使用するフラグをOnにするメソッド
 * @param {string} form_name フォーム名
 * @param {number} max_count 要素数
 * @return {void}
 */
rumi.ui.SelectGroup.prototype.setApprovalHook = function(hidden_item_name_prefix, max_count) {
  this.approval_hook = true;
  this.approval_hidden_item_name_prefix = hidden_item_name_prefix;
  this.approval_max_count = max_count;
};

/**
 * フォーム送信時のパラメータを HookするFunction
 * @param {Array.<title, val, name>} arr 選択済みUIの値
 * @return {void}
 */
rumi.ui.SelectGroup.prototype.updateSelectedApprovalHook = function(arr) {
  var factor = null;
  this.getApprovalHiddenItems().each(function(i, item) {
    factor = arr[i];
    item = jQuery(item);
    if (factor) {
      item.val(factor[1]);
    } else {
      item.val("");
    }
  });
};

/**
 * 選択肢UIの選択肢を更新するメソッド
 * @param {JSON?} json レスポンス
 * @return {void}
 */
rumi.ui.SelectGroup.prototype.updateChildList = function(json) {
  // replace use rumi.ui.updateSelectOptions(json, to_id);
  if (json && jQuery.isArray(json)) {
    var to = this.getChildList();
    to.children().remove();

    json.each(function(option) {
      to.append(rumi.ui.createOptionElement(option[2], option[1], option[0]));
    });
  }
};

/**
 * AjaxRequest時に渡すQueryを生成するメソッド
 * @param {string} group_id 選択された部／課局id
 * @return {Object}
 */
rumi.ui.SelectGroup.prototype.createAjaxData = function(group_id) {
  var data = {};
  jQuery.each(this.ajax_data, function(key, value) {
    if (value == "group_id") {
      value = group_id;
    }
    // group_id以外のものはそのままQueryとして格納する
    data[key] = value;
  });
  return data;
};

/**
 * 部／課局を選択UIの選択肢が変更された時に実行するメソッド
 * @param {string} group_id 選択された部／課局id
 * @return {void}
 */
rumi.ui.SelectGroup.prototype.changeParent = function(group_id) {
  var scope = this;
  rumi.ui.requestAjax(this.ajax_url, this.createAjaxData(group_id),
    function(json) {
      scope.updateChildList(json);
    });
};

/**
 * 選択済みUIの初期値設定メソッド
 * @param {JSON?} values
 * @return {void}
 */
rumi.ui.SelectGroup.prototype.initSelected = function(values) {
  if (values && jQuery.isArray(values)) {
    var to = this.getSelectedList();
    values.each(function(option) {
      to.append(rumi.ui.createOptionElement(option[2], option[1], option[0]));
    });
  }

  this.updateSelected();
};

/**
 * SelectGroupを構成する全てのUIを活性／非活性にするメソッド
 * @param {boolean} disabled
 * @return {void}
 */
rumi.ui.SelectGroup.prototype.setDisabled = function(disabled) {
  rumi.setDisabled(this.getParentList(), disabled);
  rumi.setDisabled(this.getSelectedList(), disabled);
  rumi.setDisabled(this.getChildList(), disabled);
  rumi.setDisabled(jQuery(this.add_btn_id), disabled);
  rumi.setDisabled(jQuery(this.remove_btn_id), disabled);
};

// rumi.unread namespace
rumi.unread = {}

// メールの未読件数表示
rumi.unread.showMailCount = function(count) {
  if (count != 0) jQuery('#notificationMailCount').html(count);
  else jQuery('#notificationMailCount').html("");
};
