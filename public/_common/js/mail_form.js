var mail_form_window;
function openMailForm(uri){
  var opt = null;
  var name = 'mail_form';
  if (arguments.length > 1) {
    opt = arguments[1];
  }

  try {
    var win = window.open(uri, name, opt);
    mail_form_window = win;
    win.focus();
    return win;
  } catch(e) {
    return;
  }
}

function change_user(form) {
  if (mail_form_window && !mail_form_window.closed) {
    alert("メール作成画面を開いている場合、ユーザを切り替えることはできません。");
    jQuery("#current_account").val(jQuery("#before_account").val());
  } else {
    form.submit();
  }
  return;
}

function openGwcircularForm(uri){
  var opt = null;
  var name = "gwcircular_form";
  if (arguments.length > 1) {
    opt = arguments[1];
  }

  try {
    var win = window.open(uri, name, opt);
    win.focus();
    return win;
  } catch(e) {
    return;
  }
}

function openGwbbsForm(uri){
  var opt = null;
  var name = "gwbbs_form_select";
  if (arguments.length > 1) {
    opt = arguments[1];
  }

  try {
    var win = window.open(uri, name, opt);
    win.focus();
    return win;
  } catch(e) {
    return;
  }
}
