import 'package:esugid/core/validation/esugid_input_formatters.dart';
import 'package:esugid/core/validation/esugid_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Philippine mobile validation', () {
    test('normalizes common local and international formats', () {
      expect(
        ESugidValidators.normalizePhilippineMobile('0917 123 4567'),
        '+639171234567',
      );
      expect(
        ESugidValidators.normalizePhilippineMobile('+63 917 123 4567'),
        '+639171234567',
      );
      expect(
        ESugidValidators.normalizePhilippineMobile('9171234567'),
        '+639171234567',
      );
    });

    test('rejects incomplete and non-mobile numbers', () {
      expect(ESugidValidators.normalizePhilippineMobile('0917123456'), isNull);
      expect(ESugidValidators.normalizePhilippineMobile('02123456789'), isNull);
    });

    test('formatter converts pasted +63 number to 11 local digits', () {
      const formatter = PhilippineMobileInputFormatter();
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '+63 917 123 4567'),
      );
      expect(result.text, '09171234567');
    });
  });

  group('Peso validation', () {
    test('formats thousands and two centavo digits', () {
      const formatter = PesoInputFormatter();
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '1234567.899'),
      );
      expect(result.text, '1,234,567.89');
      expect(ESugidValidators.normalizePeso(result.text), '1234567.89');
    });

    test('stores and displays a stable two-decimal value', () {
      expect(ESugidValidators.normalizePeso('1,250'), '1250.00');
      expect(ESugidValidators.formatPeso('1250'), '1,250.00');
      expect(ESugidValidators.pesoAmount('0'), isNotNull);
      expect(ESugidValidators.pesoAmount('100.999'), isNotNull);
    });
  });

  group('Text validation', () {
    test('normalizes email casing and rejects malformed input', () {
      expect(
        ESugidValidators.normalizeEmail('  AnaJean@Gmail.com '),
        'anajean@gmail.com',
      );
      expect(ESugidValidators.email('resident@example.com'), isNull);
      expect(ESugidValidators.email('resident @example.com'), isNotNull);
    });

    test('suggests corrections for common provider domain typos', () {
      const examples = <String, String>{
        'jine@gmail.con': 'jine@gmail.com',
        'jine@gmal.com': 'jine@gmail.com',
        'jine@gmial.com': 'jine@gmail.com',
        'jine@gmail.co': 'jine@gmail.com',
        'jine@yahoo.con': 'jine@yahoo.com',
        'jine@outlook.con': 'jine@outlook.com',
        'jine@hotmial.com': 'jine@hotmail.com',
        'jine@icloud.con': 'jine@icloud.com',
      };

      for (final entry in examples.entries) {
        expect(
          ESugidValidators.commonEmailDomainSuggestion(
            entry.key,
          )?.correctedEmail,
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('does not block valid common, custom, or nearby real domains', () {
      for (final address in <String>[
        'jine@gmail.com',
        'jine@yahoo.com',
        'jine@outlook.com',
        'jine@hotmail.com',
        'jine@icloud.com',
        'jine@example.com',
        'jine@mail.com',
        'jine@ymail.com',
      ]) {
        expect(
          ESugidValidators.commonEmailDomainSuggestion(address),
          isNull,
          reason: address,
        );
      }
    });

    test('leaves invalid syntax to the normal email validator', () {
      expect(
        ESugidValidators.commonEmailDomainSuggestion('jine@gmail'),
        isNull,
      );
      expect(
        ESugidValidators.commonEmailDomainSuggestion('jine @gmail.con'),
        isNull,
      );
    });

    test('enforces required text boundaries', () {
      expect(
        ESugidValidators.requiredText(
          'Pothole',
          label: 'Description',
          minLength: 10,
          maxLength: 1000,
        ),
        isNotNull,
      );
      expect(
        ESugidValidators.requiredText(
          'Large pothole near the market',
          label: 'Description',
          minLength: 10,
          maxLength: 1000,
        ),
        isNull,
      );
    });
  });
}
