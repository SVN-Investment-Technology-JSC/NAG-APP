void main() {
  String _removeDiacritics(String str) {
    const withDia = 'áàảãạâấầẩẫậăắằẳẵặđéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵ';
    const withoutDia = 'aaaaaaaaaaaaaaaaadeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyy';
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
      str = str.replaceAll(withDia[i].toUpperCase(), withoutDia[i].toUpperCase());
    }
    return str;
  }

  String _normalizeWorkType(String value) {
    String v = _removeDiacritics(value).toLowerCase();
    return v.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  }

  print(_normalizeWorkType('LÁI XE'));
  print(_normalizeWorkType('VẬN HÀNH'));
  print(_normalizeWorkType('ÔM VÒI'));
}
