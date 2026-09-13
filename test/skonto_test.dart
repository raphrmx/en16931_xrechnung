import 'package:en16931_xrechnung/en16931_xrechnung.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('writing a discount', () {
    test('writes the form the rule asks for', () {
      expect(
        skontoPaymentTerms([Skonto.of(days: 14, percentage: 2)]),
        '#SKONTO#TAGE=14#PROZENT=2.00#\n',
      );
    });

    test('pads the percentage to two decimals', () {
      expect(
        skontoPaymentTerms([Skonto.of(days: 7, percentage: 1.5)]),
        '#SKONTO#TAGE=7#PROZENT=1.50#\n',
      );
    });

    test('carries a base amount when the discount is on part of it', () {
      expect(
        skontoPaymentTerms([
          Skonto.of(days: 14, percentage: 3, baseAmount: 1000),
        ]),
        '#SKONTO#TAGE=14#PROZENT=3.00#BASISBETRAG=1000.00#\n',
      );
    });

    test('puts the free text above the discounts', () {
      expect(
        skontoPaymentTerms(
          [
            Skonto.of(days: 14, percentage: 2),
            Skonto.of(days: 30, percentage: 0)
          ],
          text: 'Zahlbar innerhalb 30 Tagen.',
        ),
        'Zahlbar innerhalb 30 Tagen.\n'
        '#SKONTO#TAGE=14#PROZENT=2.00#\n'
        '#SKONTO#TAGE=30#PROZENT=0.00#\n',
      );
    });

    test('refuses a discount that cannot be written', () {
      expect(
        () => skontoPaymentTerms([Skonto.of(days: 14, percentage: -2)]),
        throwsArgumentError,
      );
      expect(
        () => skontoPaymentTerms([Skonto.of(days: -1, percentage: 2)]),
        throwsArgumentError,
      );
    });
  });

  group('reading one back', () {
    test('reads what it wrote', () {
      final discounts = [
        Skonto.of(days: 14, percentage: 2),
        Skonto.of(days: 30, percentage: 1, baseAmount: 500),
      ];
      final terms = skontoPaymentTerms(discounts, text: 'Zahlbar netto.');
      expect(readSkonto(terms), discounts);
    });

    test('leaves the free text alone', () {
      expect(readSkonto('Zahlbar innerhalb 30 Tagen.'), isEmpty);
      expect(readSkonto(null), isEmpty);
    });

    test('leaves out a line it cannot read', () {
      expect(readSkonto('#SKONTO#TAGE=14#PROZENT=2#\n'), isEmpty);
    });
  });

  group('BR-DE-18', () {
    test('says nothing about payment terms that are only text', () {
      final invoice = validInvoice(paymentTerms: 'Zahlbar innerhalb 30 Tagen.');
      expect(breaches(invoice), isEmpty);
    });

    test('takes what skontoPaymentTerms writes', () {
      final invoice = validInvoice(
        paymentTerms: skontoPaymentTerms(
          [Skonto.of(days: 14, percentage: 2)],
          text: 'Zahlbar innerhalb 30 Tagen.',
        ),
      );
      expect(breaches(invoice), isEmpty);
    });

    test('reports a percentage written without its decimals', () {
      final invoice = validInvoice(
        paymentTerms: '#SKONTO#TAGE=14#PROZENT=2#\n',
      );
      expect(breaches(invoice), contains('BR-DE-18'));
    });

    test('reports a discount in lower case', () {
      final invoice = validInvoice(
        paymentTerms: '#skonto#TAGE=14#PROZENT=2.00#\n',
      );
      expect(breaches(invoice), contains('BR-DE-18'));
    });

    test('takes free text after the discounts', () {
      final invoice = validInvoice(
        paymentTerms: '#SKONTO#TAGE=14#PROZENT=2.00#\nWeitere Infos folgen.',
      );
      expect(breaches(invoice), isEmpty);
    });

    test('reports a last discount that is not closed by a line break', () {
      final invoice = validInvoice(
        paymentTerms: 'Zahlbar netto.\n#SKONTO#TAGE=14#PROZENT=2.00#',
      );
      expect(breaches(invoice), contains('BR-DE-18'));
    });
  });
}
