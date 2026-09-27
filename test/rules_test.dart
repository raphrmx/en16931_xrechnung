import 'dart:typed_data';

import 'package:en16931/en16931.dart';
import 'package:en16931_xrechnung/en16931_xrechnung.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('a German invoice that is in order breaks nothing', () {
    expect(validateXrechnung(validInvoice()), isEmpty);
  });

  group('what an invoice has to carry', () {
    test('BR-DE-1 wants payment instructions', () {
      final invoice = Invoice.fromLines(
        number: '1',
        issueDate: DateTime(2026, 9, 13),
        specificationIdentifier: xrechnungSpecification,
        buyerReference: '991-33333TEST-33',
        seller: validSeller,
        buyer: validBuyer,
        delivery: Delivery(date: CalendarDate(2026, 9, 12)),
        lines: [
          InvoiceLine.of(
            id: '1',
            item: const Item(name: 'Beratung'),
            quantity: 1,
            unitPrice: 100,
            vatRate: 19,
          ),
        ],
      );
      expect(breaches(invoice), contains('BR-DE-1'));
    });

    test('BR-DE-2 wants a seller contact', () {
      final seller = Seller(
        name: validSeller.name,
        address: validSeller.address,
        vatIdentifier: validSeller.vatIdentifier,
        electronicAddress: validSeller.electronicAddress,
      );
      expect(breaches(validInvoice(seller: seller)), contains('BR-DE-2'));
    });

    test('BR-DE-3 and BR-DE-4 want the seller city and post code', () {
      final seller = Seller(
        name: validSeller.name,
        address: const Address(country: 'DE', line1: 'Musterstrasse 1'),
        vatIdentifier: validSeller.vatIdentifier,
        electronicAddress: validSeller.electronicAddress,
        contact: validSeller.contact,
      );
      expect(
        breaches(validInvoice(seller: seller)),
        containsAll(['BR-DE-3', 'BR-DE-4']),
      );
    });

    test('BR-DE-5, BR-DE-6 and BR-DE-7 want the contact filled in', () {
      final seller = Seller(
        name: validSeller.name,
        address: validSeller.address,
        vatIdentifier: validSeller.vatIdentifier,
        electronicAddress: validSeller.electronicAddress,
        contact: const Contact(),
      );
      expect(
        breaches(validInvoice(seller: seller)),
        containsAll(['BR-DE-5', 'BR-DE-6', 'BR-DE-7']),
      );
    });

    test('BR-DE-8 and BR-DE-9 want the buyer city and post code', () {
      final buyer = Buyer(
        name: validBuyer.name,
        address: const Address(country: 'DE'),
        electronicAddress: validBuyer.electronicAddress,
      );
      expect(
        breaches(validInvoice(buyer: buyer)),
        containsAll(['BR-DE-8', 'BR-DE-9']),
      );
    });

    test('BR-DE-10 and BR-DE-11 want them on a delivery address too', () {
      final delivery = Delivery(
        date: CalendarDate(2026, 9, 12),
        address: const Address(country: 'DE', line1: 'Lagerweg 3'),
      );
      expect(
        breaches(validInvoice(delivery: delivery)),
        containsAll(['BR-DE-10', 'BR-DE-11']),
      );
    });

    test('BR-DE-10 says nothing when there is no delivery address', () {
      expect(breaches(validInvoice()), isEmpty);
    });

    test('BR-DE-14 wants a rate on every breakdown entry', () {
      final invoice = _withoutBreakdownRate(validInvoice());
      expect(breaches(invoice), contains('BR-DE-14'));
    });

    test('BR-DE-15 wants the buyer reference', () {
      expect(
        breaches(validInvoice(buyerReference: null)),
        contains('BR-DE-15'),
      );
      expect(
        breaches(validInvoice(buyerReference: '  ')),
        contains('BR-DE-15'),
      );
    });

    test('BR-DE-16 wants the seller identified for tax', () {
      final seller = Seller(
        name: validSeller.name,
        address: validSeller.address,
        electronicAddress: validSeller.electronicAddress,
        contact: validSeller.contact,
      );
      expect(breaches(validInvoice(seller: seller)), contains('BR-DE-16'));
    });

    test('BR-DE-16 takes a tax representative instead', () {
      final seller = Seller(
        name: validSeller.name,
        address: validSeller.address,
        electronicAddress: validSeller.electronicAddress,
        contact: validSeller.contact,
      );
      final invoice = validInvoice(
        seller: seller,
        taxRepresentative: const TaxRepresentative(
          name: 'Vertreter GmbH',
          vatIdentifier: 'DE987654321',
          address: Address(city: 'Köln', postalCode: '50667', country: 'DE'),
        ),
      );
      expect(breaches(invoice), isNot(contains('BR-DE-16')));
    });

    test('BR-DE-17 keeps to the eight type codes', () {
      final invoice = validInvoice(typeCode: InvoiceTypeCode.factoredInvoice);
      expect(breaches(invoice), contains('BR-DE-17'));
    });

    test('BR-DE-21 wants one of the three XRechnung identifiers', () {
      final invoice = validInvoice(
        specificationIdentifier: en16931Specification,
      );
      expect(breaches(invoice), contains('BR-DE-21'));
    });

    test('BR-DE-22 wants each attachment named once', () {
      final invoice = validInvoice(
        supportingDocuments: [
          SupportingDocument(
            'A',
            attachment: Attachment(
              bytes: Uint8List(1),
              mimeCode: 'application/pdf',
              filename: 'beleg.pdf',
            ),
          ),
          SupportingDocument(
            'B',
            attachment: Attachment(
              bytes: Uint8List(1),
              mimeCode: 'application/pdf',
              filename: 'beleg.pdf',
            ),
          ),
        ],
      );
      expect(breaches(invoice), contains('BR-DE-22'));
    });

    test('BR-DE-26 asks a corrected invoice which one it corrects', () {
      final invoice = validInvoice(typeCode: InvoiceTypeCode.correctedInvoice);
      expect(breaches(invoice), contains('BR-DE-26'));

      final corrected = validInvoice(
        typeCode: InvoiceTypeCode.correctedInvoice,
        precedingInvoices: const [PrecedingInvoiceReference('2026-0041')],
      );
      expect(breaches(corrected), isNot(contains('BR-DE-26')));
    });

    test('BR-DE-27 and BR-DE-28 read the contact as a reader would', () {
      final seller = Seller(
        name: validSeller.name,
        address: validSeller.address,
        vatIdentifier: validSeller.vatIdentifier,
        electronicAddress: validSeller.electronicAddress,
        contact: const Contact(
          name: 'Rechnungswesen',
          telephone: 'ext',
          email: 'rechnung.example.de',
        ),
      );
      expect(
        breaches(validInvoice(seller: seller)),
        containsAll(['BR-DE-27', 'BR-DE-28']),
      );
    });

    test('BR-DE-TMP-32 wants to know when it was delivered', () {
      final invoice = validInvoice(delivery: const Delivery(name: 'Lager'));
      expect(breaches(invoice), contains('BR-DE-TMP-32'));
    });

    test('BR-DE-TMP-32 takes a period on every line instead', () {
      final invoice = validInvoice(
        delivery: const Delivery(name: 'Lager'),
        lines: [
          InvoiceLine.of(
            id: '1',
            item: const Item(name: 'Beratung'),
            quantity: 1,
            unitPrice: 100,
            vatRate: 19,
            period: DatePeriod(
              start: CalendarDate(2026, 9, 1),
              end: CalendarDate(2026, 9, 30),
            ),
          ),
        ],
      );
      expect(breaches(invoice), isEmpty);
    });

    test('BR-TMP-2 wants an absolute link to an external document', () {
      final invoice = validInvoice(
        supportingDocuments: [
          SupportingDocument('A', externalUri: Uri.parse('beleg.pdf')),
        ],
      );
      expect(breaches(invoice), contains('BR-TMP-2'));
    });
  });

  group('how payment is made', () {
    test('BR-DE-19 wants an IBAN behind a SEPA transfer', () {
      final invoice = validInvoice(
        paymentInstructions: const PaymentInstructions(
          means: PaymentMeansCode.sepaCreditTransfer,
          creditTransfers: [CreditTransferAccount('DE89370400440532013001')],
        ),
      );
      expect(breaches(invoice), contains('BR-DE-19'));
    });

    test('BR-DE-23-a wants the account a transfer goes to', () {
      final invoice = validInvoice(
        paymentInstructions: const PaymentInstructions(
          means: PaymentMeansCode.sepaCreditTransfer,
        ),
      );
      expect(breaches(invoice), contains('BR-DE-23-a'));
    });

    test('BR-DE-23-b keeps the other two groups out', () {
      final invoice = validInvoice(
        paymentInstructions: const PaymentInstructions(
          means: PaymentMeansCode.sepaCreditTransfer,
          creditTransfers: [CreditTransferAccount('DE89370400440532013000')],
          card: PaymentCard('1234'),
        ),
      );
      expect(breaches(invoice), contains('BR-DE-23-b'));
    });

    test('BR-DE-24-a wants the card behind a card payment', () {
      final invoice = validInvoice(
        paymentInstructions: const PaymentInstructions(
          means: PaymentMeansCode.bankCard,
        ),
      );
      expect(breaches(invoice), contains('BR-DE-24-a'));
    });

    test('BR-DE-24-b keeps the other two groups out', () {
      final invoice = validInvoice(
        paymentInstructions: const PaymentInstructions(
          means: PaymentMeansCode.bankCard,
          card: PaymentCard('1234'),
          creditTransfers: [CreditTransferAccount('DE89370400440532013000')],
        ),
      );
      expect(breaches(invoice), contains('BR-DE-24-b'));
    });

    test('BR-DE-25-a wants the mandate behind a direct debit', () {
      final invoice = validInvoice(
        paymentInstructions: const PaymentInstructions(
          means: PaymentMeansCode.sepaDirectDebit,
        ),
      );
      expect(breaches(invoice), contains('BR-DE-25-a'));
    });

    test('BR-DE-25-b keeps the other two groups out', () {
      final invoice = validInvoice(
        paymentInstructions: const PaymentInstructions(
          means: PaymentMeansCode.sepaDirectDebit,
          directDebit: DirectDebit(
            mandateReference: 'MND-1',
            creditorIdentifier: 'DE98ZZZ09999999999',
            debitedAccountIdentifier: 'DE89370400440532013000',
          ),
          creditTransfers: [CreditTransferAccount('DE89370400440532013000')],
        ),
      );
      expect(breaches(invoice), contains('BR-DE-25-b'));
    });

    test('BR-DE-30 and BR-DE-31 want the creditor and the account', () {
      final invoice = validInvoice(
        paymentInstructions: const PaymentInstructions(
          means: PaymentMeansCode.sepaDirectDebit,
          directDebit: DirectDebit(mandateReference: 'MND-1'),
        ),
      );
      expect(breaches(invoice), containsAll(['BR-DE-30', 'BR-DE-31']));
    });

    test('BR-DE-20 wants an IBAN on the debited account', () {
      final invoice = validInvoice(
        paymentInstructions: const PaymentInstructions(
          means: PaymentMeansCode.sepaDirectDebit,
          directDebit: DirectDebit(
            mandateReference: 'MND-1',
            creditorIdentifier: 'DE98ZZZ09999999999',
            debitedAccountIdentifier: '0532013000',
          ),
        ),
      );
      expect(breaches(invoice), contains('BR-DE-20'));
    });

    test('a direct debit that is in order breaks nothing', () {
      final invoice = validInvoice(
        paymentInstructions: const PaymentInstructions(
          means: PaymentMeansCode.sepaDirectDebit,
          directDebit: DirectDebit(
            mandateReference: 'MND-1',
            creditorIdentifier: 'DE98ZZZ09999999999',
            debitedAccountIdentifier: 'DE89370400440532013000',
          ),
        ),
      );
      expect(breaches(invoice), isEmpty);
    });
  });

  group('the extension', () {
    test('runs its rules only for an invoice claiming it', () {
      final claimed = validInvoice(
        specificationIdentifier: xrechnungExtensionSpecification,
        supportingDocuments: [_attached('application/zip')],
      );
      expect(breaches(claimed), contains('BR-DEX-01'));

      final plain = validInvoice(
        supportingDocuments: [_attached('application/zip')],
      );
      expect(breaches(plain), isNot(contains('BR-DEX-01')));
    });

    test('BR-DEX-01 lets XML through, which the standard does not', () {
      final invoice = validInvoice(
        specificationIdentifier: xrechnungExtensionSpecification,
        supportingDocuments: [_attached('application/xml')],
      );
      expect(breaches(invoice), isNot(contains('BR-DEX-01')));
    });

    test('BR-DEX-04 reads a party identifier scheme', () {
      final seller = Seller(
        name: validSeller.name,
        address: validSeller.address,
        vatIdentifier: validSeller.vatIdentifier,
        electronicAddress: validSeller.electronicAddress,
        contact: validSeller.contact,
        identifiers: const [Identifier('123', scheme: '9999')],
      );
      final invoice = validInvoice(
        seller: seller,
        specificationIdentifier: xrechnungExtensionSpecification,
      );
      expect(breaches(invoice), contains('BR-DEX-04'));
    });

    test('BR-DEX-04 takes the three schemes the extension adds', () {
      final seller = Seller(
        name: validSeller.name,
        address: validSeller.address,
        vatIdentifier: validSeller.vatIdentifier,
        electronicAddress: validSeller.electronicAddress,
        contact: validSeller.contact,
        identifiers: const [Identifier('123', scheme: 'XR01')],
      );
      final invoice = validInvoice(
        seller: seller,
        specificationIdentifier: xrechnungExtensionSpecification,
      );
      expect(breaches(invoice), isNot(contains('BR-DEX-04')));
    });

    test('BR-DEX-06 reads the scheme of an item standard identifier', () {
      final invoice = validInvoice(
        specificationIdentifier: xrechnungExtensionSpecification,
        lines: [
          InvoiceLine.of(
            id: '1',
            item: const Item(
              name: 'Beratung',
              standardIdentifier: Identifier('5412345678901', scheme: '9999'),
            ),
            quantity: 1,
            unitPrice: 100,
            vatRate: 19,
          ),
        ],
      );
      expect(breaches(invoice), contains('BR-DEX-06'));
    });
  });

  group('clean vehicles', () {
    test('a vehicle invoice that is in order breaks nothing', () {
      expect(validateXrechnung(_vehicleInvoice()), isEmpty);
    });

    test('BR-DE-CVD-01 and BR-DE-CVD-02 want the procurement references', () {
      final invoice = _vehicleInvoice(contract: null, tender: null);
      expect(breaches(invoice), containsAll(['BR-DE-CVD-01', 'BR-DE-CVD-02']));
    });

    test('BR-DE-CVD-03 wants at least one vehicle on the invoice', () {
      final invoice = _vehicleInvoice(item: const Item(name: 'Reifen'));
      expect(breaches(invoice), contains('BR-DE-CVD-03'));
    });

    test('BR-DE-CVD-04 keeps to the categories the directive knows', () {
      final invoice = _vehicleInvoice(category: 'M9');
      expect(breaches(invoice), contains('BR-DE-CVD-04'));
    });

    test('BR-DE-CVD-05 keeps to the attributes the directive knows', () {
      final invoice = _vehicleInvoice(attribute: 'electric');
      expect(breaches(invoice), contains('BR-DE-CVD-05'));
    });

    test('BR-DE-CVD-06-a wants one attribute beside the classification', () {
      final invoice = _vehicleInvoice(
        item: const Item(
          name: 'Lieferwagen',
          classificationIdentifiers: [Identifier('N1', scheme: 'CVD')],
        ),
      );
      expect(breaches(invoice), contains('BR-DE-CVD-06-a'));
    });

    test('BR-DE-CVD-06-b wants one classification beside the attribute', () {
      final invoice = _vehicleInvoice(
        item: const Item(
          name: 'Lieferwagen',
          attributes: [ItemAttribute('cva', 'clean')],
        ),
      );
      expect(breaches(invoice), contains('BR-DE-CVD-06-b'));
    });

    test('BR-TMP-CVD-01 reads the classification scheme', () {
      final invoice = _vehicleInvoice(
        item: const Item(
          name: 'Lieferwagen',
          classificationIdentifiers: [
            Identifier('N1', scheme: 'CVD'),
            Identifier('12345', scheme: 'QQQ'),
          ],
          attributes: [ItemAttribute('cva', 'clean')],
        ),
      );
      expect(breaches(invoice), contains('BR-TMP-CVD-01'));
    });

    test('runs its rules only for an invoice claiming the profile', () {
      final invoice = validInvoice();
      expect(breaches(invoice), isNot(contains('BR-DE-CVD-03')));
    });
  });

  group('the rules a profile rewrites', () {
    test('take the narrower rule of the standard off', () {
      // BR-CL-13 refuses CVD as an item classification scheme, since it is
      // not a UNTDID 7143 code. The clean vehicles profile asks for exactly
      // that scheme, so the invoice would break the standard for obeying the
      // profile.
      expect(breaches(_vehicleInvoice()), isNot(contains('BR-CL-13')));
    });

    test('leave it on for an invoice not claiming that profile', () {
      final invoice = validInvoice(
        lines: [
          InvoiceLine.of(
            id: '1',
            item: const Item(
              name: 'Lieferwagen',
              classificationIdentifiers: [Identifier('N1', scheme: 'CVD')],
            ),
            quantity: 1,
            unitPrice: 32000,
            vatRate: 19,
          ),
        ],
      );
      expect(breaches(invoice), contains('BR-CL-13'));
    });

    test('name a rule both catalogues know', () {
      for (final entry in xrechnungOverrides.entries) {
        for (final pair in entry.value.entries) {
          expect(ruleFor(pair.key).id, pair.key);
          expect(xrechnungRuleFor(pair.value).id, pair.value);
        }
      }
    });
  });
}

SupportingDocument _attached(String mimeCode) => SupportingDocument(
      'A',
      attachment: Attachment(
        bytes: Uint8List(1),
        mimeCode: mimeCode,
        filename: 'beleg',
      ),
    );

/// The same invoice with the rate taken off its breakdown, which is how an
/// invoice read from elsewhere comes back when the document left it out.
Invoice _withoutBreakdownRate(Invoice invoice) => Invoice(
      number: invoice.number,
      issueDate: invoice.issueDate,
      typeCode: invoice.typeCode,
      currency: invoice.currency,
      specificationIdentifier: invoice.specificationIdentifier,
      buyerReference: invoice.buyerReference,
      seller: invoice.seller,
      buyer: invoice.buyer,
      lines: invoice.lines,
      delivery: invoice.delivery,
      paymentInstructions: invoice.paymentInstructions,
      totals: invoice.totals,
      vatBreakdown: [
        for (final entry in invoice.vatBreakdown)
          VatBreakdown(
            category: entry.category,
            taxableAmount: entry.taxableAmount,
            taxAmount: entry.taxAmount,
          ),
      ],
    );

/// An invoice for a vehicle, under the clean vehicles profile.
Invoice _vehicleInvoice({
  String? contract = 'V-2026-11',
  String? tender = 'LOT-3',
  String category = 'N1',
  String attribute = 'clean',
  Item? item,
}) {
  final lines = [
    InvoiceLine.of(
      id: '1',
      item: item ??
          Item(
            name: 'Lieferwagen',
            classificationIdentifiers: [Identifier(category, scheme: 'CVD')],
            attributes: [ItemAttribute('cva', attribute)],
          ),
      quantity: 1,
      unitPrice: 32000,
      vatRate: 19,
    ),
  ];
  final breakdown = deriveBreakdown(lines: lines, entries: const []);
  return Invoice(
    number: '2026-0043',
    issueDate: CalendarDate(2026, 9, 13),
    typeCode: InvoiceTypeCode.commercialInvoice,
    currency: 'EUR',
    specificationIdentifier: xrechnungCleanVehiclesSpecification,
    buyerReference: '991-33333TEST-33',
    contractReference: contract,
    tenderReference: tender,
    seller: validSeller,
    buyer: validBuyer,
    lines: lines,
    delivery: Delivery(date: CalendarDate(2026, 9, 12)),
    paymentInstructions: validTransfer,
    vatBreakdown: breakdown,
    totals: deriveTotals(lines: lines, entries: const [], breakdown: breakdown),
  );
}
