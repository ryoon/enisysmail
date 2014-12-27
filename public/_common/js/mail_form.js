function openMailForm(uri){
  var opt = null;
  var name = 'mail_form';
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
