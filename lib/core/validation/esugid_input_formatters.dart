import 'package:flutter/services.dart';

class BirthDateInputFormatter extends TextInputFormatter {
  const BirthDateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buffer = StringBuffer();
    for (var index = 0; index < limited.length; index += 1) {
      if (index == 2 || index == 4) buffer.write('/');
      buffer.write(limited[index]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class PhilippineMobileInputFormatter extends TextInputFormatter {
  const PhilippineMobileInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('63')) digits = '0${digits.substring(2)}';
    if (digits.length == 10 && digits.startsWith('9')) digits = '0$digits';
    if (digits.length > 11) digits = digits.substring(0, 11);
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

class PhilippineMobilePrefixInputFormatter extends TextInputFormatter {
  const PhilippineMobilePrefixInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('63')) digits = digits.substring(2);
    // The visible field already has a +63 prefix. Remove only local trunk
    // zeroes that immediately precede the required mobile prefix (9). Keep a
    // lone zero while the resident is still typing instead of making the
    // input appear unresponsive.
    digits = digits.replaceFirst(RegExp(r'^0+(?=9)'), '');
    if (digits.length > 10) digits = digits.substring(0, 10);
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

class PesoInputFormatter extends TextInputFormatter {
  const PesoInputFormatter({this.maximumIntegerDigits = 9});

  final int maximumIntegerDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var cleaned = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    final firstDot = cleaned.indexOf('.');
    if (firstDot >= 0) {
      cleaned =
          '${cleaned.substring(0, firstDot)}.${cleaned.substring(firstDot + 1).replaceAll('.', '')}';
    }

    final parts = cleaned.split('.');
    var whole = parts.first;
    if (whole.length > maximumIntegerDigits) {
      whole = whole.substring(0, maximumIntegerDigits);
    }
    whole = whole.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    var fraction = parts.length > 1 ? parts[1] : '';
    if (fraction.length > 2) fraction = fraction.substring(0, 2);

    final grouped = StringBuffer();
    for (var index = 0; index < whole.length; index++) {
      if (index > 0 && (whole.length - index) % 3 == 0) grouped.write(',');
      grouped.write(whole[index]);
    }
    final hasDecimal = cleaned.contains('.');
    final formatted = '${grouped.toString()}${hasDecimal ? '.$fraction' : ''}';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
