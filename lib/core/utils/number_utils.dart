String numberToVietnamese(int n) {
  const ones = ['', 'một', 'hai', 'ba', 'bốn', 'năm', 'sáu', 'bảy', 'tám', 'chín'];
  const teens = ['mười', 'mười một', 'mười hai', 'mười ba', 'mười bốn', 'mười lăm', 'mười sáu', 'mười bảy', 'mười tám', 'mười chín'];

  if (n == 0) return 'Không';
  if (n < 10) return _capitalize(ones[n]);
  if (n < 20) return _capitalize(teens[n - 10]);
  if (n < 100) {
    final t = n ~/ 10;
    final o = n % 10;
    var s = '${ones[t]} mươi';
    if (o == 1) {
      s += ' mốt';
    } else if (o == 5) {
      s += ' lăm';
    } else if (o > 0) {
      s += ' ${ones[o]}';
    }
    return _capitalize(s);
  }
  if (n < 1000) {
    final h = n ~/ 100;
    final remainder = n % 100;
    var s = '${ones[h]} trăm';
    if (remainder > 0 && remainder < 10) {
      s += ' lẻ ${ones[remainder]}';
    } else if (remainder >= 10) {
      s += ' ${numberToVietnamese(remainder).toLowerCase()}';
    }
    return _capitalize(s);
  }
  if (n < 1000000) {
    final th = n ~/ 1000;
    final remainder = n % 1000;
    var s = '${numberToVietnamese(th).toLowerCase()} nghìn';
    if (remainder > 0 && remainder < 100) {
      s += ' không trăm ${numberToVietnamese(remainder).toLowerCase()}';
    } else if (remainder >= 100) {
      s += ' ${numberToVietnamese(remainder).toLowerCase()}';
    }
    return _capitalize(s);
  }
  return n.toString();
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
