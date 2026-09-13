/// XRechnung, the profile every German public body invoice is sent under.
///
/// A profile is a narrowing: it says which identifier an invoice is claimed
/// under, and which rules it has to meet on top of EN 16931. The model and
/// the rules of the standard itself are in `en16931`, and writing the invoice
/// out is a syntax package's business.
///
/// Germany also puts an early payment discount into the payment terms, in a
/// fixed form the free text of EN 16931 has no room for. [Skonto] and
/// [skontoPaymentTerms] write it.
library;

export 'src/catalogue.g.dart';
export 'src/iban.dart';
export 'src/profile.dart';
export 'src/rules.dart'
    show
        XrechnungCheck,
        xrechnungCleanVehiclesRules,
        xrechnungExtensionRules,
        xrechnungForTheSyntax,
        xrechnungMetByConstruction,
        xrechnungRules;
export 'src/skonto.dart' show Skonto, readSkonto, skontoPaymentTerms;
export 'src/validator.dart';
