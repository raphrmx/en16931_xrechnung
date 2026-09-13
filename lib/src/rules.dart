import 'package:en16931/en16931.dart';
import 'package:en16931_xrechnung/src/catalogue.g.dart';
import 'package:en16931_xrechnung/src/iban.dart';
import 'package:en16931_xrechnung/src/profile.dart';
import 'package:en16931_xrechnung/src/skonto.dart';

/// Checks one XRechnung rule against an invoice.
typedef XrechnungCheck = Iterable<RuleViolation> Function(
    Invoice invoice, RuleDescriptor rule);

/// The VAT categories that commit the seller to naming a tax registration.
///
/// Every category but O, outside the scope of VAT: an invoice that charges no
/// VAT because the transaction is not a VAT transaction needs no VAT number.
const Set<VatCategory> _taxedCategories = {
  VatCategory.standardRate,
  VatCategory.zeroRated,
  VatCategory.exempt,
  VatCategory.reverseCharge,
  VatCategory.intraCommunitySupply,
  VatCategory.exportOutsideEu,
  VatCategory.canaryIslands,
  VatCategory.ceutaAndMelilla,
};

/// The payment means that are a transfer into the seller's account.
const Set<String> _transferMeans = {'30', '58'};

/// The payment means that are a card payment.
const Set<String> _cardMeans = {'48', '54', '55'};

/// The payment means that is a SEPA direct debit.
const String _directDebitMeans = '59';

/// The mime types the extension allows an attachment to be.
///
/// The standard's own list stops at the spreadsheet formats. The extension
/// adds XML, which is what carries a second document inside the invoice.
const Set<String> _extensionMimeTypes = {
  'application/pdf',
  'image/png',
  'image/jpeg',
  'text/csv',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.oasis.opendocument.spreadsheet',
  'application/xml',
};

/// The vehicle categories the clean vehicles profile classifies under.
const Set<String> _vehicleCategories = {'M1', 'M2', 'M3', 'N1', 'N2', 'N3'};

/// What a clean vehicle is said to be.
const Set<String> _cleanVehicleAttributes = {
  'clean',
  'zero-emission',
  'other',
};

/// The scheme the clean vehicles profile classifies a vehicle under.
const String _cleanVehicleScheme = 'CVD';

/// The attribute name that carries what kind of clean vehicle it is.
const String _cleanVehicleAttribute = 'cva';

/// The rules XRechnung adds that every invoice is held to.
final Map<String, XrechnungCheck> xrechnungRules = {
  'BR-DE-1': _de1,
  'BR-DE-2': _de2,
  'BR-DE-3': _de3,
  'BR-DE-4': _de4,
  'BR-DE-5': _de5,
  'BR-DE-6': _de6,
  'BR-DE-7': _de7,
  'BR-DE-8': _de8,
  'BR-DE-9': _de9,
  'BR-DE-10': _de10,
  'BR-DE-11': _de11,
  'BR-DE-14': _de14,
  'BR-DE-15': _de15,
  'BR-DE-16': _de16,
  'BR-DE-17': _de17,
  'BR-DE-18': _de18,
  'BR-DE-19': _de19,
  'BR-DE-20': _de20,
  'BR-DE-21': _de21,
  'BR-DE-22': _de22,
  'BR-DE-23-a': _de23a,
  'BR-DE-23-b': _de23b,
  'BR-DE-24-a': _de24a,
  'BR-DE-24-b': _de24b,
  'BR-DE-25-a': _de25a,
  'BR-DE-25-b': _de25b,
  'BR-DE-26': _de26,
  'BR-DE-27': _de27,
  'BR-DE-28': _de28,
  'BR-DE-30': _de30,
  'BR-DE-31': _de31,
  'BR-DE-TMP-32': _tmp32,
  'BR-TMP-2': _tmp2,
};

/// The rules that hold only for an invoice claiming the extension.
///
/// They widen the code lists the standard draws from, so an invoice that is
/// not claiming the extension is held to the narrower ones by `en16931`
/// itself and these never run.
final Map<String, XrechnungCheck> xrechnungExtensionRules = {
  'BR-DEX-01': _dex01,
  'BR-DEX-04': _dex04,
  'BR-DEX-05': _dex05,
  'BR-DEX-06': _dex06,
  'BR-DEX-07': _dex07,
  'BR-DEX-08': _dex08,
};

/// The rules that hold only for an invoice under the clean vehicles profile.
final Map<String, XrechnungCheck> xrechnungCleanVehiclesRules = {
  'BR-DE-CVD-01': _cvd01,
  'BR-DE-CVD-02': _cvd02,
  'BR-DE-CVD-03': _cvd03,
  'BR-DE-CVD-04': _cvd04,
  'BR-DE-CVD-05': _cvd05,
  'BR-DE-CVD-06-a': _cvd06a,
  'BR-DE-CVD-06-b': _cvd06b,
  'BR-TMP-CVD-01': _tmpCvd01,
};

/// The rules an invoice built with this model cannot break.
///
/// Most of them are about the extension's own terms. The semantic model is
/// EN 16931's, and EN 16931 has neither a sub invoice line nor a third party
/// payment, so a rule bearing on one has nothing to find. An extension
/// document read from elsewhere loses those terms on the way in, which is the
/// price of holding one model rather than two.
const Map<String, String> xrechnungMetByConstruction = {
  'BR-DEX-02': 'The model has no sub invoice line to sum.',
  'BR-DEX-03': 'The model has no sub invoice line to carry VAT.',
  'BR-DEX-09': 'With no third party payment, the total due is the one BR-CO-16 '
      'already checks.',
  'BR-DEX-10': 'The model has no third party payment to type.',
  'BR-DEX-11': 'The model has no third party payment to give an amount.',
  'BR-DEX-12': 'The model has no third party payment to describe.',
  'BR-DEX-13': 'The model has no third party payment amount to round.',
  'BR-DEX-14': 'The model has no third party payment amount to denominate.',
  'BR-DEX-15': 'The model has no sub invoice line.',
  'BR-TMP-3': 'A Price carries one base quantity, read for both prices.',
  'BR-TMP-4': 'A SupportingDocument carries one description.',
  'BR-TMP-5': 'A SupportingDocument carries one attachment.',
};

/// The rules that are about the document rather than the invoice.
///
/// These say how the XML is written, and a model has no XML. The syntax
/// package satisfies them when it writes, and a document read from elsewhere
/// has to be checked against them before it is read, not after.
const Map<String, String> xrechnungForTheSyntax = {
  'BR-TMP-6': 'A date is written YYYY-MM-DD in UBL.',
  'BR-TMP-7': 'A date is written YYYYMMDD under format="102" in CII.',
};

// --- What an invoice has to carry ------------------------------------------

Iterable<RuleViolation> _de1(Invoice invoice, RuleDescriptor rule) sync* {
  if (invoice.paymentInstructions != null) return;
  yield _at(
    rule,
    'The payment instructions (BG-16) are missing. A German invoice says how '
    'it is to be paid, even when the means are not settled yet.',
  );
}

Iterable<RuleViolation> _de2(Invoice invoice, RuleDescriptor rule) sync* {
  if (invoice.seller.contact != null) return;
  yield _at(
    rule,
    'The seller contact (BG-6) is missing. The buyer needs someone to ask '
    'about the invoice.',
  );
}

Iterable<RuleViolation> _de3(Invoice invoice, RuleDescriptor rule) sync* {
  if (!_blank(invoice.seller.address.city)) return;
  yield _at(rule, 'The seller city (BT-37) is missing.');
}

Iterable<RuleViolation> _de4(Invoice invoice, RuleDescriptor rule) sync* {
  if (!_blank(invoice.seller.address.postalCode)) return;
  yield _at(rule, 'The seller post code (BT-38) is missing.');
}

Iterable<RuleViolation> _de5(Invoice invoice, RuleDescriptor rule) sync* {
  final contact = invoice.seller.contact;
  if (contact == null || !_blank(contact.name)) return;
  yield _at(rule, 'The seller contact point (BT-41) is missing.');
}

Iterable<RuleViolation> _de6(Invoice invoice, RuleDescriptor rule) sync* {
  final contact = invoice.seller.contact;
  if (contact == null || !_blank(contact.telephone)) return;
  yield _at(rule, 'The seller contact telephone number (BT-42) is missing.');
}

Iterable<RuleViolation> _de7(Invoice invoice, RuleDescriptor rule) sync* {
  final contact = invoice.seller.contact;
  if (contact == null || !_blank(contact.email)) return;
  yield _at(rule, 'The seller contact email address (BT-43) is missing.');
}

Iterable<RuleViolation> _de8(Invoice invoice, RuleDescriptor rule) sync* {
  if (!_blank(invoice.buyer.address.city)) return;
  yield _at(rule, 'The buyer city (BT-52) is missing.');
}

Iterable<RuleViolation> _de9(Invoice invoice, RuleDescriptor rule) sync* {
  if (!_blank(invoice.buyer.address.postalCode)) return;
  yield _at(rule, 'The buyer post code (BT-53) is missing.');
}

Iterable<RuleViolation> _de10(Invoice invoice, RuleDescriptor rule) sync* {
  final address = invoice.delivery?.address;
  if (address == null || !_blank(address.city)) return;
  yield _at(
    rule,
    'The invoice gives a delivery address (BG-15), so the deliver to city '
    '(BT-77) is required.',
  );
}

Iterable<RuleViolation> _de11(Invoice invoice, RuleDescriptor rule) sync* {
  final address = invoice.delivery?.address;
  if (address == null || !_blank(address.postalCode)) return;
  yield _at(
    rule,
    'The invoice gives a delivery address (BG-15), so the deliver to post '
    'code (BT-78) is required.',
  );
}

Iterable<RuleViolation> _de14(Invoice invoice, RuleDescriptor rule) sync* {
  for (final (index, entry) in invoice.vatBreakdown.indexed) {
    if (entry.rate != null) continue;
    yield _at(
      rule,
      'The VAT category rate (BT-119) is missing. XRechnung asks for it on '
          'every breakdown entry, including the ones the standard lets go '
          'without a rate.',
      'VAT breakdown $index',
    );
  }
}

Iterable<RuleViolation> _de15(Invoice invoice, RuleDescriptor rule) sync* {
  if (!_blank(invoice.buyerReference)) return;
  yield _at(
    rule,
    'The buyer reference (BT-10) is missing. A public body puts its '
    'Leitweg-ID there, and the invoice is routed by it.',
  );
}

Iterable<RuleViolation> _de16(Invoice invoice, RuleDescriptor rule) sync* {
  final categories = {
    for (final line in invoice.lines) line.vatCategory,
    for (final entry in invoice.allowancesAndCharges) entry.vatCategory,
  };
  if (!categories.any(_taxedCategories.contains)) return;
  final seller = invoice.seller;
  if (!_blank(seller.vatIdentifier)) return;
  if (!_blank(seller.taxRegistrationIdentifier)) return;
  if (invoice.taxRepresentative != null) return;
  yield _at(
    rule,
    'The invoice uses VAT categories that need the seller identified for '
    'tax, so one of the seller VAT identifier (BT-31), the seller tax '
    'registration identifier (BT-32) or the tax representative (BG-11) is '
    'required.',
  );
}

Iterable<RuleViolation> _de17(Invoice invoice, RuleDescriptor rule) sync* {
  final code = invoice.typeCode.value;
  if (xrechnungTypeCodes.contains(code)) return;
  yield _at(
    rule,
    'The invoice type code (BT-3) is "$code", which is outside the eight '
    'codes XRechnung expects.',
  );
}

Iterable<RuleViolation> _de18(Invoice invoice, RuleDescriptor rule) sync* {
  final terms = invoice.paymentTerms;
  if (terms == null) return;
  for (final line in skontoLines(terms)) {
    if (skontoForm.hasMatch(line)) continue;
    yield _at(
      rule,
      'The payment terms (BT-20) carry "$line", which is not the form a '
      'discount for early payment is written in. Build the text with '
      'skontoPaymentTerms.',
    );
  }
  if (skontoLines(terms).isEmpty || skontoIsClosed(terms)) return;
  yield _at(
    rule,
    'The payment terms (BT-20) do not end the last discount with a line '
    'break, which is how a reader tells where it stops.',
  );
}

Iterable<RuleViolation> _de19(Invoice invoice, RuleDescriptor rule) sync* {
  final instructions = invoice.paymentInstructions;
  if (instructions == null) return;
  if (instructions.means.value != '58') return;
  for (final account in instructions.creditTransfers) {
    if (isIban(account.identifier)) continue;
    yield _at(
      rule,
      'Payment is by SEPA credit transfer, so the payment account identifier '
      '(BT-84) is an IBAN. "${account.identifier}" does not close on its '
      'check digits.',
    );
  }
}

Iterable<RuleViolation> _de20(Invoice invoice, RuleDescriptor rule) sync* {
  final instructions = invoice.paymentInstructions;
  if (instructions == null) return;
  if (instructions.means.value != _directDebitMeans) return;
  final account = instructions.directDebit?.debitedAccountIdentifier;
  if (account == null || isIban(account)) return;
  yield _at(
    rule,
    'Payment is by SEPA direct debit, so the debited account identifier '
    '(BT-91) is an IBAN. "$account" does not close on its check digits.',
  );
}

Iterable<RuleViolation> _de21(Invoice invoice, RuleDescriptor rule) sync* {
  if (xrechnungProfileOf(invoice) != null) return;
  yield _at(
    rule,
    'The specification identifier (BT-24) is '
    '"${invoice.specificationIdentifier}", where an XRechnung carries '
    'xrechnungSpecification, or the extension or clean vehicles identifier.',
  );
}

Iterable<RuleViolation> _de22(Invoice invoice, RuleDescriptor rule) sync* {
  final seen = <String>{};
  for (final document in invoice.supportingDocuments) {
    final filename = document.attachment?.filename;
    if (filename == null || seen.add(filename)) continue;
    yield _at(
      rule,
      'Two attachments (BT-125) are both called "$filename". A receiver '
      'saves them side by side, so each filename is used once.',
    );
  }
}

// --- How payment is made ---------------------------------------------------

Iterable<RuleViolation> _de23a(Invoice invoice, RuleDescriptor rule) sync* {
  final instructions = _means(invoice, _transferMeans);
  if (instructions == null || instructions.creditTransfers.isNotEmpty) return;
  yield _at(
    rule,
    'Payment is by transfer, so the credit transfer account (BG-17) is '
    'required.',
  );
}

Iterable<RuleViolation> _de23b(Invoice invoice, RuleDescriptor rule) sync* {
  final instructions = _means(invoice, _transferMeans);
  if (instructions == null) return;
  yield* _mustNotCarry(rule, instructions, transfer: false);
}

Iterable<RuleViolation> _de24a(Invoice invoice, RuleDescriptor rule) sync* {
  final instructions = _means(invoice, _cardMeans);
  if (instructions == null || instructions.card != null) return;
  yield _at(
    rule,
    'Payment is by card, so the payment card information (BG-18) is '
    'required.',
  );
}

Iterable<RuleViolation> _de24b(Invoice invoice, RuleDescriptor rule) sync* {
  final instructions = _means(invoice, _cardMeans);
  if (instructions == null) return;
  yield* _mustNotCarry(rule, instructions, card: false);
}

Iterable<RuleViolation> _de25a(Invoice invoice, RuleDescriptor rule) sync* {
  final instructions = _means(invoice, const {_directDebitMeans});
  if (instructions == null || instructions.directDebit != null) return;
  yield _at(
    rule,
    'Payment is by direct debit, so the direct debit (BG-19) is required.',
  );
}

Iterable<RuleViolation> _de25b(Invoice invoice, RuleDescriptor rule) sync* {
  final instructions = _means(invoice, const {_directDebitMeans});
  if (instructions == null) return;
  yield* _mustNotCarry(rule, instructions, debit: false);
}

Iterable<RuleViolation> _de30(Invoice invoice, RuleDescriptor rule) sync* {
  final debit = invoice.paymentInstructions?.directDebit;
  if (debit == null || !_blank(debit.creditorIdentifier)) return;
  yield _at(
    rule,
    'The invoice carries a direct debit (BG-19), so the bank assigned '
    'creditor identifier (BT-90) is required. It is what the buyer bank '
    'checks the mandate against.',
  );
}

Iterable<RuleViolation> _de31(Invoice invoice, RuleDescriptor rule) sync* {
  final debit = invoice.paymentInstructions?.directDebit;
  if (debit == null || !_blank(debit.debitedAccountIdentifier)) return;
  yield _at(
    rule,
    'The invoice carries a direct debit (BG-19), so the debited account '
    'identifier (BT-91) is required.',
  );
}

// --- What a reader should be told -------------------------------------------

Iterable<RuleViolation> _de26(Invoice invoice, RuleDescriptor rule) sync* {
  if (invoice.typeCode.value != '384') return;
  if (invoice.precedingInvoices.isNotEmpty) return;
  yield _at(
    rule,
    'The invoice type code (BT-3) is 384, a corrected invoice, so it should '
    'name the invoice it corrects (BG-3).',
  );
}

Iterable<RuleViolation> _de27(Invoice invoice, RuleDescriptor rule) sync* {
  final telephone = invoice.seller.contact?.telephone;
  if (telephone == null) return;
  final digits = telephone.replaceAll(RegExp('[^0-9]'), '').length;
  if (digits >= 3) return;
  yield _at(
    rule,
    'The seller contact telephone number (BT-42) is "$telephone", which is '
    'too short to be a number anyone can call.',
  );
}

Iterable<RuleViolation> _de28(Invoice invoice, RuleDescriptor rule) sync* {
  final email = invoice.seller.contact?.email;
  if (email == null) return;
  if (_emailShape.hasMatch(email.trim())) return;
  yield _at(
    rule,
    'The seller contact email address (BT-43) is "$email", which is not '
    'shaped like an address.',
  );
}

/// One at sign, a dotted domain after it, no spaces anywhere.
final RegExp _emailShape = RegExp(r'^[^@\s]+@([^@.\s]+\.)+[^@.\s]+$');

Iterable<RuleViolation> _tmp32(Invoice invoice, RuleDescriptor rule) sync* {
  if (invoice.delivery?.date != null) return;
  if (invoice.invoicingPeriod != null) return;
  if (invoice.lines.every((line) => line.period != null)) return;
  yield _at(
    rule,
    'Nothing says when the goods were delivered or the service rendered. '
    'Give the delivery date (BT-72), the invoicing period (BG-14), or a '
    'period on every line (BG-26).',
  );
}

Iterable<RuleViolation> _tmp2(Invoice invoice, RuleDescriptor rule) sync* {
  for (final document in invoice.supportingDocuments) {
    final uri = document.externalUri;
    if (uri == null || _absoluteUri.hasMatch(uri.toString())) continue;
    yield _at(
      rule,
      'The external document location (BT-124) is "$uri", which is not an '
          'absolute URL. A receiver has nowhere to fetch it from.',
      'supporting document ${document.reference}',
    );
  }
}

/// A scheme of at least two characters, then a colon, then anything.
final RegExp _absoluteUri = RegExp('^[a-zA-Z][a-zA-Z0-9+.-]+:.*');

// --- The extension ----------------------------------------------------------

Iterable<RuleViolation> _dex01(Invoice invoice, RuleDescriptor rule) sync* {
  for (final document in invoice.supportingDocuments) {
    final mimeCode = document.attachment?.mimeCode;
    if (mimeCode == null || _extensionMimeTypes.contains(mimeCode)) continue;
    yield _at(
      rule,
      'The attachment (BT-125) is "$mimeCode", which the extension does not '
          'allow. It allows the six types the standard does, and XML.',
      'supporting document ${document.reference}',
    );
  }
}

Iterable<RuleViolation> _dex04(Invoice invoice, RuleDescriptor rule) sync* {
  for (final (identifier, where) in _partyIdentifiers(invoice)) {
    // SEPA is not an ISO register. UBL puts the creditor identifier (BT-90)
    // in the same element as the party identifier and marks it that way, so
    // the rule lets it through for the two parties that can be paid.
    if (identifier.scheme == 'SEPA' && where != 'buyer') continue;
    yield* _scheme(rule, identifier, where, _iso6523Extended, 'ISO 6523 ICD');
  }
}

Iterable<RuleViolation> _dex05(Invoice invoice, RuleDescriptor rule) sync* {
  for (final (identifier, where) in _legalRegistrations(invoice)) {
    yield* _scheme(rule, identifier, where, _iso6523Extended, 'ISO 6523 ICD');
  }
}

Iterable<RuleViolation> _dex06(Invoice invoice, RuleDescriptor rule) sync* {
  for (final line in invoice.lines) {
    final identifier = line.item.standardIdentifier;
    if (identifier == null) continue;
    yield* _scheme(
      rule,
      identifier,
      'item standard identifier',
      _iso6523Extended,
      'ISO 6523 ICD',
      pathOf(line),
    );
  }
}

Iterable<RuleViolation> _dex07(Invoice invoice, RuleDescriptor rule) sync* {
  for (final (identifier, where) in [
    if (invoice.seller.electronicAddress case final id?) (id, 'seller'),
    if (invoice.buyer.electronicAddress case final id?) (id, 'buyer'),
  ]) {
    yield* _scheme(rule, identifier, where, _easExtended, 'CEF EAS');
  }
}

Iterable<RuleViolation> _dex08(Invoice invoice, RuleDescriptor rule) sync* {
  final identifier = invoice.delivery?.locationIdentifier;
  if (identifier == null) return;
  yield* _scheme(
    rule,
    identifier,
    'delivery location',
    _iso6523Extended,
    'ISO 6523 ICD',
  );
}

/// The ISO 6523 registers plus the three the extension adds.
final Set<String> _iso6523Extended = {
  ...xrechnungIso6523Schemes,
  ...xrechnungDigaSchemes,
};

/// The electronic address registers plus the three the extension adds.
final Set<String> _easExtended = {
  ...xrechnungElectronicAddressSchemes,
  ...xrechnungDigaSchemes,
};

// --- Clean vehicles ---------------------------------------------------------

Iterable<RuleViolation> _cvd01(Invoice invoice, RuleDescriptor rule) sync* {
  if (!_blank(invoice.contractReference)) return;
  yield _at(
    rule,
    'An invoice for a vehicle names the contract it is bought under (BT-12).',
  );
}

Iterable<RuleViolation> _cvd02(Invoice invoice, RuleDescriptor rule) sync* {
  if (!_blank(invoice.tenderReference)) return;
  yield _at(
    rule,
    'An invoice for a vehicle names the tender or lot it answers (BT-17).',
  );
}

Iterable<RuleViolation> _cvd03(Invoice invoice, RuleDescriptor rule) sync* {
  for (final line in invoice.lines) {
    if (_vehicleClassifications(line).isEmpty) continue;
    if (_vehicleAttributes(line).isEmpty) continue;
    return;
  }
  yield _at(
    rule,
    'No line classifies a vehicle. One line at least carries an item '
    'classification (BT-158) under the CVD scheme and an item attribute '
    '(BT-160) called "cva".',
  );
}

Iterable<RuleViolation> _cvd04(Invoice invoice, RuleDescriptor rule) sync* {
  for (final line in invoice.lines) {
    for (final identifier in _vehicleClassifications(line)) {
      if (_vehicleCategories.contains(identifier.value)) continue;
      yield _at(
        rule,
        'The vehicle category (BT-158) is "${identifier.value}", where the '
        'directive knows M1, M2, M3, N1, N2 and N3.',
        pathOf(line),
      );
    }
  }
}

Iterable<RuleViolation> _cvd05(Invoice invoice, RuleDescriptor rule) sync* {
  for (final line in invoice.lines) {
    for (final attribute in _vehicleAttributes(line)) {
      if (_cleanVehicleAttributes.contains(attribute.value)) continue;
      yield _at(
        rule,
        'The clean vehicle attribute (BT-161) is "${attribute.value}", where '
        'the directive knows clean, zero-emission and other.',
        pathOf(line),
      );
    }
  }
}

Iterable<RuleViolation> _cvd06a(Invoice invoice, RuleDescriptor rule) sync* {
  for (final line in invoice.lines) {
    if (_vehicleClassifications(line).isEmpty) continue;
    final attributes = _vehicleAttributes(line).length;
    if (attributes == 1) continue;
    yield _at(
      rule,
      'The line classifies a vehicle, so it carries exactly one item '
      'attribute (BT-160) called "cva". It carries $attributes.',
      pathOf(line),
    );
  }
}

Iterable<RuleViolation> _cvd06b(Invoice invoice, RuleDescriptor rule) sync* {
  for (final line in invoice.lines) {
    if (_vehicleAttributes(line).isEmpty) continue;
    final classifications = _vehicleClassifications(line).length;
    if (classifications == 1) continue;
    yield _at(
      rule,
      'The line says what kind of clean vehicle it is, so it carries exactly '
      'one item classification (BT-158) under the CVD scheme. It carries '
      '$classifications.',
      pathOf(line),
    );
  }
}

Iterable<RuleViolation> _tmpCvd01(Invoice invoice, RuleDescriptor rule) sync* {
  for (final line in invoice.lines) {
    for (final identifier in line.item.classificationIdentifiers) {
      final scheme = identifier.scheme;
      if (scheme == null || scheme == _cleanVehicleScheme) continue;
      if (xrechnungItemClassificationSchemes.contains(scheme)) continue;
      yield _at(
        rule,
        'The item classification scheme (BT-158-1) is "$scheme", which is '
        'neither a UNTDID 7143 code nor CVD.',
        pathOf(line),
      );
    }
  }
}

Iterable<Identifier> _vehicleClassifications(InvoiceLine line) =>
    line.item.classificationIdentifiers
        .where((identifier) => identifier.scheme == _cleanVehicleScheme);

Iterable<ItemAttribute> _vehicleAttributes(InvoiceLine line) =>
    line.item.attributes
        .where((attribute) => attribute.name == _cleanVehicleAttribute);

// --- Helpers ---------------------------------------------------------------

/// The payment instructions when they are of one of [means], else null.
PaymentInstructions? _means(Invoice invoice, Set<String> means) {
  final instructions = invoice.paymentInstructions;
  if (instructions == null) return null;
  return means.contains(instructions.means.value) ? instructions : null;
}

/// Reports the payment groups that do not go with the means.
///
/// The three groups are exclusive: an invoice paid by transfer carries the
/// account and nothing else. Which one is allowed is named by the caller, and
/// the other two are what this reports.
Iterable<RuleViolation> _mustNotCarry(
  RuleDescriptor rule,
  PaymentInstructions instructions, {
  bool transfer = true,
  bool card = true,
  bool debit = true,
}) sync* {
  if (transfer && instructions.creditTransfers.isNotEmpty) {
    yield _at(
        rule, 'The credit transfer account (BG-17) does not belong here.');
  }
  if (card && instructions.card != null) {
    yield _at(
      rule,
      'The payment card information (BG-18) does not belong here.',
    );
  }
  if (debit && instructions.directDebit != null) {
    yield _at(rule, 'The direct debit (BG-19) does not belong here.');
  }
}

/// Reports an identifier issued under a scheme the list does not hold.
Iterable<RuleViolation> _scheme(
  RuleDescriptor rule,
  Identifier identifier,
  String where,
  Set<String> codes,
  String list, [
  String? path,
]) sync* {
  final scheme = identifier.scheme;
  if (scheme == null || codes.contains(scheme)) return;
  yield _at(
    rule,
    'The $where identifier is issued under scheme "$scheme", which is not a '
    '$list code.',
    path,
  );
}

/// Every party identifier an invoice carries, and whose it is.
Iterable<(Identifier, String)> _partyIdentifiers(Invoice invoice) sync* {
  for (final identifier in invoice.seller.identifiers) {
    yield (identifier, 'seller');
  }
  if (invoice.buyer.identifier case final id?) yield (id, 'buyer');
  if (invoice.payee?.identifier case final id?) yield (id, 'payee');
}

/// Every legal registration identifier an invoice carries, and whose it is.
Iterable<(Identifier, String)> _legalRegistrations(Invoice invoice) sync* {
  if (invoice.seller.legalRegistrationIdentifier case final id?) {
    yield (id, 'seller');
  }
  if (invoice.buyer.legalRegistrationIdentifier case final id?) {
    yield (id, 'buyer');
  }
  if (invoice.payee?.legalRegistrationIdentifier case final id?) {
    yield (id, 'payee');
  }
}

bool _blank(String? value) => value == null || value.trim().isEmpty;

String pathOf(InvoiceLine line) => 'line ${line.id}';

RuleViolation _at(RuleDescriptor rule, String message, [String? path]) =>
    RuleViolation(rule: rule, message: message, path: path);
