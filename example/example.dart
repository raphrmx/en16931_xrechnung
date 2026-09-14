// ignore_for_file: avoid_print

import 'package:en16931/en16931.dart';
import 'package:en16931_xrechnung/en16931_xrechnung.dart';

/// Builds an invoice claimed under XRechnung and checks it against the
/// standard and the profile at once. The payment terms carry a discount for
/// paying early, in the form Germany reads it back from.
void main() {
  final invoice = Invoice.fromLines(
    number: '2026-0042',
    issueDate: DateTime(2026, 9, 13),
    dueDate: DateTime(2026, 10, 13),
    specificationIdentifier: xrechnungSpecification,
    buyerReference: '991-33333TEST-33',
    seller: const Seller(
      name: 'COMAPPS GmbH',
      vatIdentifier: 'DE123456789',
      electronicAddress: Identifier(
        '991-33333TEST-33',
        scheme: Scheme.germanLeitwegId,
      ),
      address: Address(
        line1: 'Musterstrasse 1',
        city: 'Berlin',
        postalCode: '10115',
        country: 'DE',
      ),
      contact: Contact(
        name: 'Rechnungswesen',
        telephone: '+49 30 123456',
        email: 'rechnung@example.de',
      ),
    ),
    buyer: const Buyer(
      name: 'Bundesamt',
      electronicAddress: Identifier(
        '991-33333TEST-33',
        scheme: Scheme.germanLeitwegId,
      ),
      address: Address(
        line1: 'Amtsweg 2',
        city: 'Bonn',
        postalCode: '53113',
        country: 'DE',
      ),
    ),
    delivery: Delivery(date: CalendarDate(2026, 9, 12)),
    paymentInstructions: const PaymentInstructions(
      means: PaymentMeansCode.sepaCreditTransfer,
      creditTransfers: [
        CreditTransferAccount('DE89370400440532013000', name: 'COMAPPS GmbH'),
      ],
    ),
    paymentTerms: skontoPaymentTerms([
      Skonto.of(days: 14, percentage: 2),
    ], text: 'Zahlbar innerhalb 30 Tagen.'),
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

  final violations = validateXrechnung(invoice);
  print(violations.isEmpty ? 'ready to send' : 'not yet:');
  for (final violation in violations) {
    print('  $violation');
  }

  for (final discount in readSkonto(invoice.paymentTerms)) {
    print('${discount.percentage}% off within ${discount.days} days');
  }
}
