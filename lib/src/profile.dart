import 'package:en16931/en16931.dart';

/// BT-24 for an invoice claimed under XRechnung.
///
/// A German public body reads this first: it says which rules the invoice
/// expects to be judged by. An invoice sent to one carrying the bare EN 16931
/// identifier is refused before anything else is looked at.
///
/// The register moved with release 3.0. An invoice claiming the old
/// `urn:xoev-de:kosit:standard:xrechnung_2.x` identifier is claiming a
/// version that is no longer accepted.
const String xrechnungSpecification =
    'urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0';

/// BT-24 for an invoice claimed under the XRechnung extension.
///
/// The extension is conformant rather than compliant: it adds terms the
/// standard does not have, sub invoice lines and third party payments among
/// them. This package reads an invoice claiming it as an XRechnung with a
/// wider set of code lists, and says so when a rule bears on a term the
/// semantic model does not carry.
const String xrechnungExtensionSpecification =
    '$xrechnungSpecification#conformant#'
    'urn:xeinkauf.de:kosit:extension:xrechnung_3.0';

/// BT-24 for an invoice under the clean vehicles profile.
///
/// The Clean Vehicles Directive makes a public body account for what it buys
/// when it buys a vehicle, so an invoice claiming this carries the vehicle
/// category and its clean vehicle attribute on the line.
const String xrechnungCleanVehiclesSpecification =
    '$xrechnungSpecification#compliant#'
    'urn:xeinkauf.de:kosit:xrechnung:cvd_0.9';

/// Which of the three claims an invoice makes.
///
/// The claim is what decides which rules apply, so it is read from BT-24
/// rather than passed in beside the invoice: an invoice that says one thing
/// and is checked as another tells you nothing.
enum XrechnungProfile {
  /// The CIUS, which is XRechnung proper.
  cius(xrechnungSpecification),

  /// The extension, which adds terms on top of the CIUS.
  extension(xrechnungExtensionSpecification),

  /// The clean vehicles profile.
  cleanVehicles(xrechnungCleanVehiclesSpecification);

  const XrechnungProfile(this.specificationIdentifier);

  /// The BT-24 an invoice under this profile carries.
  final String specificationIdentifier;

  /// The profile [identifier] claims, or null when it claims none of them.
  static XrechnungProfile? of(String? identifier) {
    for (final profile in values) {
      if (profile.specificationIdentifier == identifier) return profile;
    }
    return null;
  }
}

/// The profile [invoice] claims, or null when it claims none of them.
///
/// Null is the answer for an invoice that is only EN 16931: it is not an
/// XRechnung, whatever else it satisfies.
XrechnungProfile? xrechnungProfileOf(Invoice invoice) =>
    XrechnungProfile.of(invoice.specificationIdentifier);
