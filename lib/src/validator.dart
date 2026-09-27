import 'package:en16931/en16931.dart';
import 'package:en16931_xrechnung/src/catalogue.g.dart';
import 'package:en16931_xrechnung/src/profile.dart';
import 'package:en16931_xrechnung/src/rules.dart';

/// The XRechnung catalogue, indexed by identifier.
final Map<String, RuleDescriptor> _byIdentifier = {
  for (final rule in xrechnungCatalogue) rule.id: rule,
};

/// Where each rule sits in the catalogue, so violations come out in its
/// order rather than alphabetically, which puts BR-DE-10 before BR-DE-2.
final Map<String, int> _order = {
  for (final (index, rule) in xrechnungCatalogue.indexed) rule.id: index,
};

/// The rule XRechnung publishes as [id].
RuleDescriptor xrechnungRuleFor(String id) {
  final rule = _byIdentifier[id];
  if (rule == null) {
    throw ArgumentError.value(id, 'id', 'Not a rule of XRechnung');
  }
  return rule;
}

/// The XRechnung rules this package evaluates.
Set<String> get implementedXrechnungRules => {
      ...xrechnungRules.keys,
      ...xrechnungExtensionRules.keys,
      ...xrechnungCleanVehiclesRules.keys,
    };

/// Every XRechnung rule this package has an answer for, whichever the answer
/// is.
Set<String> get accountedXrechnungRules => {
      ...implementedXrechnungRules,
      ...xrechnungMetByConstruction.keys,
      ...xrechnungForTheSyntax.keys,
    };

/// The rules of the standard a profile rewrites, and what rewrites them.
///
/// A profile that widens a code list has to take the narrower rule off, or
/// the invoice breaks the standard for doing what the profile asks of it. The
/// artefacts say so themselves: each of these profile rules is written as
/// overriding the one it is paired with.
const Map<XrechnungProfile, Map<String, String>> xrechnungOverrides = {
  XrechnungProfile.extension: {
    'BR-CL-10': 'BR-DEX-04',
    'BR-CL-11': 'BR-DEX-05',
    'BR-CL-21': 'BR-DEX-06',
    'BR-CL-25': 'BR-DEX-07',
    'BR-CL-26': 'BR-DEX-08',
  },
  XrechnungProfile.cleanVehicles: {'BR-CL-13': 'BR-TMP-CVD-01'},
};

/// What [invoice] breaks, under the standard and under XRechnung.
///
/// The standard comes first, then the profile, because a profile narrows a
/// document that is already an invoice. Which profile rules run is decided by
/// what the invoice claims in BT-24: the extension and the clean vehicles
/// rules bear on terms only an invoice claiming them carries.
///
/// An empty result means the invoice is ready to be sent as far as its
/// content goes. What is left is the document itself, and a syntax package
/// answers for that.
List<RuleViolation> validateXrechnung(Invoice invoice) {
  final profile = xrechnungProfileOf(invoice);
  final overridden = xrechnungOverrides[profile] ?? const {};
  final violations = validate(
    invoice,
  ).where((violation) => !overridden.containsKey(violation.rule.id)).toList();
  final checks = {
    ...xrechnungRules,
    if (profile == XrechnungProfile.extension) ...xrechnungExtensionRules,
    if (profile == XrechnungProfile.cleanVehicles)
      ...xrechnungCleanVehiclesRules,
  };
  final found = <RuleViolation>[];
  for (final entry in checks.entries) {
    found.addAll(entry.value(invoice, xrechnungRuleFor(entry.key)));
  }
  found.sort((a, b) => _order[a.rule.id]!.compareTo(_order[b.rule.id]!));
  return [...violations, ...found];
}
