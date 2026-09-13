import 'package:en16931/en16931.dart';
import 'package:en16931_xrechnung/en16931_xrechnung.dart';

/// A German invoice that satisfies the standard and XRechnung both.
///
/// Every test starts from this and breaks one thing, so a violation that
/// comes back is the one the test is about and not a second omission.
Invoice validInvoice({
  String? buyerReference = '991-33333TEST-33',
  String? specificationIdentifier = xrechnungSpecification,
  InvoiceTypeCode typeCode = InvoiceTypeCode.commercialInvoice,
  Seller? seller,
  Buyer? buyer,
  Delivery? delivery,
  String? paymentTerms,
  PaymentInstructions? paymentInstructions,
  List<SupportingDocument> supportingDocuments = const [],
  List<PrecedingInvoiceReference> precedingInvoices = const [],
  List<InvoiceLine>? lines,
  TaxRepresentative? taxRepresentative,
}) =>
    Invoice.fromLines(
      number: '2026-0042',
      issueDate: DateTime(2026, 9, 13),
      dueDate: DateTime(2026, 10, 13),
      specificationIdentifier: specificationIdentifier,
      typeCode: typeCode,
      buyerReference: buyerReference,
      seller: seller ?? validSeller,
      buyer: buyer ?? validBuyer,
      delivery: delivery ?? Delivery(date: CalendarDate(2026, 9, 12)),
      paymentTerms: paymentTerms,
      paymentInstructions: paymentInstructions ?? validTransfer,
      supportingDocuments: supportingDocuments,
      precedingInvoices: precedingInvoices,
      taxRepresentative: taxRepresentative,
      lines: lines ??
          [
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

const Seller validSeller = Seller(
  name: 'COMAPPS GmbH',
  vatIdentifier: 'DE123456789',
  electronicAddress:
      Identifier('991-33333TEST-33', scheme: Scheme.germanLeitwegId),
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
);

const Buyer validBuyer = Buyer(
  name: 'Bundesamt',
  electronicAddress:
      Identifier('991-33333TEST-33', scheme: Scheme.germanLeitwegId),
  address: Address(
    line1: 'Amtsweg 2',
    city: 'Bonn',
    postalCode: '53113',
    country: 'DE',
  ),
);

const PaymentInstructions validTransfer = PaymentInstructions(
  means: PaymentMeansCode.sepaCreditTransfer,
  creditTransfers: [
    CreditTransferAccount('DE89370400440532013000', name: 'COMAPPS GmbH'),
  ],
);

/// The identifiers of the rules [invoice] breaks.
List<String> breaches(Invoice invoice) =>
    validateXrechnung(invoice).map((violation) => violation.rule.id).toList();
