/**
 * アドレス選択UIを制御するクラス
 * @constructor
 */
function AddressSelector() {
  // AjaxのURL(viewにて付与する)
  this.parseAddressURI = null;
  this.sysAddressesURI = null;
  this.priAddressesURI = null;
  this.publicAddressesURI = null;
  this.publicAllAddressesURI = null;
  // 選択中のアドレス帳
  this._addressBook = null;
  this._callBack = null;
  // 読み込み済グループリスト
  this._loadingGroupIds = {'sys':{}, 'pri':{}, 'public': {}};
  this._selected = {'to': {}, 'cc': {}, 'bcc': {}};
};
//Singleton instance
AddressSelector.instance = new AddressSelector();
//Instance methods
AddressSelector.prototype.toggle = function(prefix, to_addr, cc_addr, bcc_addr, callBack) {
  var selectorElm = $('addressSelector');
  if (selectorElm.visible()) {
    if (!prefix || this._addressBook == prefix) {
      this.clearCheckboxes();
      this.clearSelected();
      selectorElm.hide();
      return false;
    } else {
      this.changeBook(prefix);
      return true;
    }
  } else {
    this.clearCheckboxes();
    this.clearSelected();
    var self = this;
    var showSelector = function(){
      selectorElm.show();
      self.changeBook(prefix);
      self._callBack = callBack;
    };
    if (!to_addr) to_addr = '';
    if (!cc_addr) cc_addr = '';
    if (!bcc_addr) bcc_addr = '';
    if (to_addr == '' && cc_addr == '' && bcc_addr == '') {
      showSelector();
    } else {
      var myAjax = new Ajax.Request(this.parseAddressURI, {
        method: 'post',
        parameters: {to: to_addr, cc: cc_addr, bcc: bcc_addr, authenticity_token: jQuery('meta[name="csrf-token"]').attr('content')},
        onSuccess: function(request){
          showSelector();
        },
        onFailure: function(request){
          alert('読み込みに失敗しました。');
          showSelector();
        }
      });
    }
    return true;
  }  
};
AddressSelector.prototype.changeBook = function(prefix) {
  var addrElm = null;
  var selectElm = null;
  if (this._addressBook) {
    addrElm = $(this._addressBook + 'Addresses');
    if (addrElm.visible()) addrElm.hide();
    selectElm = $(this._addressBook + 'AddressSearchFieldColumn');
    if (selectElm.visible()) selectElm.hide();
  }
  addrElm = $(prefix + 'Addresses');
  if (!addrElm.visible()) addrElm.show();
  selectElm = $(prefix + 'AddressSearchFieldColumn');
  if (!selectElm.visible()) selectElm.show();
  this._addressBook = prefix;
};
AddressSelector.prototype.currentBook = function() {
  if($('addressSelector').visible()) {
    return this._addressBook;
  } else {
    return null;
  }
};

/**
 * 読み込み済グループリストを取得するメソッド
 * @param {string} prefix アドレス帳種別で "sys", "pri", "public" のいずれか
 * @param {string} group_id グループID
 * @param {string} book_id 共有アドレス帳ID
 * @return {Object|null}
 */
AddressSelector.prototype.getLoadingGroupIds = function(prefix, group_id, book_id) {
  // Bookをクリックした場合
  if (group_id == "") {
    return null;
  }

  // 共有アドレス帳の場合
  if (prefix == "public") {
    if (!this._loadingGroupIds[prefix][book_id]) {
      // 読み込み済みリストを遅延初期化
      this._loadingGroupIds[prefix][book_id] = {};
    }
    return this._loadingGroupIds[prefix][book_id];
  } else {
    return this._loadingGroupIds[prefix];
  }
};

/**
 * グループ選択時に配下のグループとアドレスを取得、更新するメソッド
 * @param {string} prefix アドレス帳種別で "sys", "pri", "public" のいずれか
 * @param {string} gid グループID
 * @param {Object} opt
 * @param {string} book_id 共有アドレス帳ID
 * @return {void}
 */
AddressSelector.prototype.loadItems = function(prefix, gid, opt, book_id) {
  var is_public_mode = prefix == "public" && gid != "Search";
  var is_target_book = is_public_mode && gid == "";
  var loadingGroupIds = this.getLoadingGroupIds(prefix, gid, book_id);
  if (!opt) opt = {};

  // Bookをクリックした場合
  if (is_target_book) {
    var elmChildren = $("publicBook" + book_id);
    var toggleElm = $("publicToggleItems" + book_id);
  } else {
    // 共有アドレス帳の場合
    if (is_public_mode) {
      var element_id = [book_id, gid].join("_");
    } else {
      // 組織アドレス帳、個人アドレス帳の場合
      var element_id = gid;
    }
    var elmChildren = $(prefix + 'ChildItems' + element_id);
    var toggleElm = $(prefix + 'ToggleItems' + element_id);
  }

  if (elmChildren) {
    if (toggleElm.firstChild.nodeValue == '+') {
      elmChildren.show();
      toggleElm.firstChild.nodeValue = '-';
      toggleElm.className = "toggleItems toggleItemsOpen";
    // close が false の場合は展開が解除されない
    } else if (opt['close'] != false) {
      elmChildren.hide();
      toggleElm.firstChild.nodeValue = '+';
      toggleElm.className = "toggleItems toggleItemsClose";
    }
    // 読み込み済の場合、またはBookをクリックした場合はここで処理が終了する
    return;
  }

  var search = false;
  if (opt['parameters']) search = true;
  if (!search && !toggleElm) return;

  // 複数回数のクリックを考慮して読み込み済にする
  loadingGroupIds[gid] = true;

  var uri = null;
  switch(prefix) {
  case 'sys':
    if (search) {
      uri = this.sysAddressesURI + ".xml";
    } else {
      uri = this.sysAddressesURI + "/" + gid + "/child_items.xml";
      if (gid.include('_mine')) {
        var rgid = gid;
        gid = gid.sub(/_mine/, "");
        uri = this.sysAddressesURI + "/" + gid + "/child_items.xml";
        gid = rgid;
      }
    }
    break;
  case 'pri':
    if (search || gid == 0) {
      uri = this.priAddressesURI + ".xml";
    } else {
      uri = this.priAddressesURI + "/" + gid + "/child_items.xml";
    }
    break;
  case 'public':
    if (search || gid == 0) {
      if (gid == "Search") {
        uri = this.publicAllAddressesURI + ".xml";
      } else {
        uri = this.publicAddressesURI + ".xml?book_id=" + book_id;
      }
    } else {
      uri = this.publicAddressesURI + "/" + gid + "/child_items.xml?book_id=" + book_id;
    }
    break;
  }

  var self = this;
  var requestOptions = {
    method: 'get',
    onSuccess: function(request){
      if (search) self.showSearchGroup(request, prefix);
      if (prefix == 'sys' &&
          search && opt['parameters']['search_limit']) {
        var limit = Number(opt['parameters']['search_limit']);
        var items = request.responseXML.getElementsByTagName('item');
        var itemsElm = request.responseXML.getElementsByTagName('items')[0];
        var total = self.getNodeValue(itemsElm, 'total');
        if (total > limit) {
          jQuery('#addressesSearchNotice').show();
        } else {
          jQuery('#addressesSearchNotice').hide();
        }
      }
      self.showItems(request, prefix, gid, book_id, is_public_mode);
    },
    onFailure: function(request) {
      delete loadingGroupIds[gid];
      alert('読み込みに失敗しました。');
    }
  };

  if (opt['parameters']) {
    requestOptions['parameters'] = opt['parameters'];
  }
  var myAjax = new Ajax.Request(uri, requestOptions);
};

AddressSelector.prototype.getNodeValue = function(node, name) {
    var elem = node.getElementsByTagName(name);
    if (elem.length > 0 && elem[0].firstChild != null) { return elem[0].firstChild.nodeValue; }
    return null;
};

/**
 * グループ選択時に配下のグループとアドレスを更新するメソッド
 * @param {string} prefix アドレス帳種別で "sys", "pri", "public" のいずれか
 * @param {string} group_id グループID
 * @param {string} book_id 共有アドレス帳ID
 * @param {boolean} is_public_mode 共有アドレス帳の場合、true
 * @return {void}
 */
AddressSelector.prototype.showItems = function(request, prefix, group_id, book_id, is_public_mode) {
  var groups = request.responseXML.getElementsByTagName("group");
  var items = request.responseXML.getElementsByTagName("item");
  // 共有アドレス帳の場合
  if (is_public_mode) {
    var parent_id = [book_id, group_id].join("_");
  } else {
    var parent_id = group_id;
  }

  var parentElm = $(prefix + 'Group' + parent_id);
  var ul = document.createElement('ul');
  ul.id = prefix + 'ChildItems' + parent_id;
  ul.className = 'children';

  for (var i = 0; i < groups.length; i++) {
    var group  = groups[i];
    var id = this.getNodeValue(group, 'id');
    var name  = this.getNodeValue(group, 'name');
    var hasChildren = this.getNodeValue(group, 'has_children');
    ul.appendChild(this.makeGroupElement(prefix, id, name, hasChildren == '1', book_id, is_public_mode));
  }
  if (items.length > 0) {
    ul.appendChild(this.makeAddressElement(prefix, parent_id, '0', '（すべてをチェックする）', '', null));
  }
  for (var i = 0; i < items.length; i++) {
    var item  = items[i];
    var id    = this.getNodeValue(item, 'id');
    var name  = this.getNodeValue(item, 'name');
    var email  = this.getNodeValue(item, 'email');
    var groupName = this.getNodeValue(item, 'group_name');
    ul.appendChild(this.makeAddressElement(prefix, parent_id, id, name, email, groupName));
  }
  if (ul.childNodes.length > 0) parentElm.appendChild(ul);

  // もし既に読み込み済だった場合は最小化する?
  var toggleElm = $(prefix + 'ToggleItems' + parent_id);
  if (toggleElm) {
    toggleElm.firstChild.nodeValue = '-';
    toggleElm.className = "toggleItems toggleItemsOpen";
  }
  var loadingGroupIds = this.getLoadingGroupIds(prefix, group_id, book_id);
  delete loadingGroupIds[group_id];
};

/**
 * グループ選択時に配下のグループを作成するメソッド
 * @param {string} prefix アドレス帳種別で "sys", "pri", "public" のいずれか
 * @param {string} id グループID
 * @param {string} name グループ名
 * @param {boolean} hasChildren 配下のグループ、アドレスが存在するか
 * @param {string} book_id 共有アドレス帳ID
 * @param {boolean} is_public_mode 共有アドレス帳の場合、true
 * @return {void}
 */
AddressSelector.prototype.makeGroupElement = function(prefix, id, name, hasChildren, book_id, is_public_mode) {
  function escape_html(str) {
    return str.escapeHTML().replace(/"/g, '&quot;');
  }

  var li = document.createElement('li');
  li.className = 'group';
  // // 共有アドレス帳の場合
  if (is_public_mode) {
    var li_id_suffix = [book_id, id].join("_");
  } else {
    // 組織アドレス帳、個人アドレス帳の場合
    var li_id_suffix = id;
  }
  li.id = prefix + 'Group' + li_id_suffix;

  var html = '';
  if (hasChildren) {
    var toggleLoadItemParams = ["'" + prefix + "'", "'" + id + "'", "{}", "'" + book_id + "'"].join(",");
    html += '<a href="#" id="' + prefix + 'ToggleItems' + li_id_suffix + '" class="toggleItems toggleItemsClose" onclick="AddressSelector.instance.loadItems(' + toggleLoadItemParams + ');return false;">+</a>';
  } else {
    html += '<a href="#" class="toggleItems" style="visibility:hidden;">+</a>';
  }
  var addressloadItemParams = ["'" + prefix + "'", "'" + id + "'", "{ 'close': false}", "'" + book_id + "'"].join(",");
  html += '<a href="#" class="itemName groupName" onclick="AddressSelector.instance.loadItems(' + addressloadItemParams + ');return false;">' + escape_html(name) + '</a>';

  li.innerHTML = html;
  return li;
};

/**
 * グループ選択時に配下のアドレスを作成するメソッド
 * @param {string} prefix アドレス帳種別で "sys", "pri", "public" のいずれか
 * @param {string} gid グループID
 * @param {string} id アドレスID
 * @param {string} name アドレス名称
 * @param {string} email
 * @param {string} group グループ名
 * @return {void}
 */
AddressSelector.prototype.makeAddressElement = function(prefix, gid, id, name, email, group) {
  function escape_html(str) {
    return str.escapeHTML().replace(/"/g, '&quot;');
  }
  var li = document.createElement('li');
  li.className = 'address';
  li.id = prefix + 'Address' + id + '_' + gid;
  var checkId = prefix + 'CheckAddress' + id + '_' + gid;
  var checkValue = "1";
  if (id != '0') {
    checkValue = escape_html(name + "\t" + email);
  }
  var nameValue = name;
  if (group != null) nameValue += " （" + group + "）";
  var html = '';
  html += '<a href="#" class="toggleItems" style="visibility:hidden;">+</a> ';
  html += '<input type="checkbox" id="' + checkId + '" class="check" value="' + checkValue + '" onclick="AddressSelector.instance.checked(this)">';
  html += '<a href="#" class="itemName addressName" title="' + escape_html(email) + '" onclick="AddressSelector.instance.toggleCheckbox(\'' + checkId + '\');return false;">' + nameValue.escapeHTML() + '</a>';
  li.innerHTML = html;
  return li;
};
AddressSelector.prototype.showSearchGroup = function(request, prefix) {
  var items = request.responseXML.getElementsByTagName("items")[0];
  var count = this.getNodeValue(items, "count");
  var total = this.getNodeValue(items, "total");
  var name = '検索結果';
  if (total != null && total > count) {
    name += '（' + total + ' 件中 ' + count + ' 件を表示）';
  }
  var rsltElm = this.makeGroupElement(prefix, 'Search', name, count > 0);
  var rootElm = $(prefix + 'AddressesRoot');
  if (rootElm.firstChild) {
    rootElm.insertBefore(rsltElm, rootElm.firstChild);
  } else {
    rootElm.appendChild(rsltElm);
  }
  return count;
};
AddressSelector.prototype.removeSearchGroup = function(prefix) {
  var rsltElm = $(prefix + 'GroupSearch');
  if (rsltElm) rsltElm.parentNode.removeChild(rsltElm);
};
AddressSelector.prototype.search = function() {
  var prefix = this._addressBook;
  var keyword = $('addressSearchKeyword').value;
  var field = $(prefix + 'AddressSearchField').value;
  var searchLimit = $('searchLimit').value;
  if (keyword == '') return false;
  var param = {'search':'on'};
  param[field] = keyword;
  param['search_limit'] = searchLimit;
  this.removeSearchGroup(prefix);
  this.loadItems(prefix, 'Search', {'parameters':param});
};
AddressSelector.prototype.resetSearchResult = function() {
  this.removeSearchGroup(this._addressBook);
};
AddressSelector.prototype.addAddresses = function(type) {
  var prefix = this._addressBook;
  var reg = new RegExp('^' + prefix + 'CheckAddress(.+?)_.+$');
  var inputs = $(prefix + 'Addresses').getElementsByTagName('input');
  for (var i = 0;i < inputs.length;i++) {
    if (inputs[i].type != 'checkbox' || !inputs[i].checked) continue;
    var mt = reg.exec(inputs[i].id);
    if (!mt) continue;
    if (mt[1] != '0') {
      var splits = inputs[i].value.split("\t");
      if (splits.length >= 2) this.add(type, splits[0], splits[1]);
    }
    inputs[i].checked = false;
  }
};
AddressSelector.prototype.add = function(type, name, email) {
  var address = email;
  if (name) {
    address = name + ' <' + email + '>';
  }
  var newAddress = false;
  var elm = null;
  if (this._selected[type][email]) elm = $(type + '_' + email);
  if (!elm) {
    elm = document.createElement('div');
    elm.className = 'selectedAddress';
    elm.id = type + '_' + email;
    newAddress = true;
  }
  escaped_id = elm.id.replace(/[\\'"]/g, "\\$&").escapeHTML().replace(/"/g, '&quot;');
  var html = '<a href="#" class="deleteButton" title="削除" onclick="AddressSelector.instance.remove(\'' + escaped_id + '\'); return false;">削除</a>';
  html += '<span class="addressName">' + address.escapeHTML() + '</span>';
  elm.innerHTML = html;
  if (newAddress) $(type + 'Addresses').appendChild(elm);
  this._selected[type][email] = address;
};
AddressSelector.prototype.remove = function(id) {
  var elm = $(id);
  if (elm) elm.parentNode.removeChild(elm);
  var mt = id.match(/^(to|cc|bcc)_(.+)$/);
  if (mt) {
    delete this._selected[mt[1]][mt[2]];
  }
};
AddressSelector.prototype.finishSelection = function(ok) {
  if (this._callBack) {
    var to = null, cc = null, bcc = null;
    if (ok) {
      to = this.selected('to');
      cc = this.selected('cc');
      bcc = this.selected('bcc');
    }
    this._callBack(ok, to, cc, bcc);
  }
  this.toggle();
};
AddressSelector.prototype.clearCheckboxes = function() {
  var prefixes = ['sys', 'pri', 'public'];
  for (var i = 0;i < prefixes.length;i++) {
    var inputs = $(prefixes[i] + 'Addresses').getElementsByTagName('input');
    for (var k = 0;k < inputs.length;k++) {
      if (inputs[k].type == 'checkbox') inputs[k].checked = false;
    }
  }
};
AddressSelector.prototype.clearSelected = function() {
  var types = ['to', 'cc', 'bcc'];
  for (var i = 0;i < types.length;i++) {
    this._selected[types[i]] = {};
    var elm = $(types[i] + 'Addresses');
    for (var k = elm.childNodes.length - 1;k >= 0;k--) {
      elm.removeChild(elm.childNodes[k]);
    }
  }
};
AddressSelector.prototype.toggleCheckbox = function(checkId) {
  var checkElm = $(checkId);
  if (checkElm) {
    checkElm.checked = !checkElm.checked;
  }
  this.checked(checkElm);
};
AddressSelector.prototype.checked = function(checkElm) {
  var prefix, id, gid;
  var checkIdPattern = /^(.+?)CheckAddress(.+?)_(.+)$/;
  var mt = checkElm.id.match(checkIdPattern);
  if (mt) {
    prefix = mt[1]
    id = mt[2];
    gid = mt[3];
  }
  if (id == '0') {
    var itemsElm = $(prefix + 'ChildItems' + gid);
    var inputs = itemsElm.getElementsByTagName('input');
    for (var i = 0;i < inputs.length;i++) {
      if (inputs[i].type != 'checkbox') continue;
      var mt = inputs[i].id.match(checkIdPattern);
      if (!mt || mt[2] == '0' || mt[3] != gid) continue;
      inputs[i].checked = checkElm.checked;
    }
  } else {
    if (checkElm.checked) return;
    var allElm = $(prefix + 'CheckAddress0_' + gid);
    if (allElm) allElm.checked = false;
  }
};
AddressSelector.prototype.selected = function(type) {
  var list = '';
  var nodes = $(type + 'Addresses').childNodes;
  var reg = new RegExp('^' + type + '_(.+)$');
  for (var i = 0;i < nodes.length;i++) {
    if (nodes[i].nodeType != 1 /* ELEMENT_NODE */ || nodes[i].tagName.toLowerCase() != 'div') continue;
    var mt = reg.exec(nodes[i].id);
    if (!mt) continue;
    var address = this._selected[type][mt[1]];
    if (address) {
      if (list != '') list += ', ';
      list += address;
    }
  }
  return list;
};
