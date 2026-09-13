import 'package:en16931_xrechnung/en16931_xrechnung.dart';
import 'package:test/test.dart';

void main() {
  group('an IBAN', () {
    test('closes on its check digits', () {
      expect(isIban('DE89370400440532013000'), isTrue);
      expect(isIban('BE68539007547034'), isTrue);
      expect(isIban('FR1420041010050500013M02606'), isTrue);
      expect(isIban('GB33BUKB20201555555555'), isTrue);
    });

    test('is read the same written in groups of four', () {
      expect(isIban('DE89 3704 0044 0532 0130 00'), isTrue);
    });

    test('fails on a digit that is one out', () {
      expect(isIban('DE89370400440532013001'), isFalse);
      expect(isIban('BE68539007547035'), isFalse);
    });

    test('fails on anything that is not shaped like one', () {
      expect(isIban(''), isFalse);
      expect(isIban('0532013000'), isFalse);
      expect(isIban('de89370400440532013000'), isFalse);
      expect(isIban('DEXX370400440532013000'), isFalse);
      expect(isIban('DE89370400440532013000000000000000000'), isFalse);
    });
  });
}
