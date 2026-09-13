import 'package:en16931/en16931.dart';
import 'package:en16931_xrechnung/en16931_xrechnung.dart';
import 'package:test/test.dart';

/// The invoice the README shows, kept here so the README cannot go stale
/// without a test going red.
Invoice _fromReadme() => Invoice.fromLines(
      number: '2026-0042',
      issueDate: DateTime(2026, 9, 13),
      specificationIdentifier: xrechnungSpecification,
      buyerReference: '991-33333TEST-33',
      seller: const Seller(
        name: 'COMAPPS GmbH',
        vatIdentifier: 'DE123456789',
        electronicAddress:
            Identifier('991-33333TEST-33', scheme: Scheme.germanLeitwegId),
        address: Address(city: 'Berlin', postalCode: '10115', country: 'DE'),
        contact: Contact(
          name: 'Rechnungswesen',
          telephone: '+49 30 123456',
          email: 'rechnung@example.de',
        ),
      ),
      buyer: const Buyer(
        name: 'Bundesamt',
        electronicAddress:
            Identifier('991-33333TEST-33', scheme: Scheme.germanLeitwegId),
        address: Address(city: 'Bonn', postalCode: '53113', country: 'DE'),
      ),
      delivery: Delivery(date: CalendarDate(2026, 9, 12)),
      paymentInstructions: const PaymentInstructions(
        means: PaymentMeansCode.sepaCreditTransfer,
        creditTransfers: [CreditTransferAccount('DE89370400440532013000')],
      ),
      lines: [
        InvoiceLine.of(
          id: '1',
          item: const Item(name: 'Beratung'),
          quantity: 8,
          unitPrice: 150.00,
          vatRate: 19,
          unit: UnitCode.hour,
        ),
      ],
    );

void main() {
  test('the invoice in the README passes the standard and the profile', () {
    expect(validateXrechnung(_fromReadme()), isEmpty);
  });

  test('the payment terms in the README are written as shown', () {
    expect(
      skontoPaymentTerms(
        [Skonto.of(days: 14, percentage: 2)],
        text: 'Zahlbar innerhalb 30 Tagen.',
      ),
      'Zahlbar innerhalb 30 Tagen.\n#SKONTO#TAGE=14#PROZENT=2.00#\n',
    );
  });

  test('the counts in the README are the ones the package holds', () {
    expect(xrechnungCatalogue, hasLength(61));
    expect(implementedXrechnungRules, hasLength(47));
    expect(xrechnungMetByConstruction, hasLength(12));
    expect(xrechnungForTheSyntax, hasLength(2));
  });
}
