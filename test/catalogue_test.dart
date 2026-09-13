import 'package:en16931/en16931.dart';
import 'package:en16931_xrechnung/en16931_xrechnung.dart';
import 'package:test/test.dart';

void main() {
  group('the catalogue', () {
    test('is read from the artefacts rather than remembered', () {
      expect(xrechnungCatalogue, hasLength(61));
    });

    test('holds every rule under one identifier', () {
      final identifiers = xrechnungCatalogue.map((rule) => rule.id).toList();
      expect(identifiers.toSet(), hasLength(identifiers.length));
    });

    test('calls every rule a profile rule', () {
      for (final rule in xrechnungCatalogue) {
        expect(rule.family, RuleFamily.profile, reason: rule.id);
      }
    });
  });

  group('the rules', () {
    test('are accounted for, every one of them', () {
      final catalogue = xrechnungCatalogue.map((rule) => rule.id).toSet();
      expect(accountedXrechnungRules, catalogue);
    });

    test('are accounted for once each', () {
      final buckets = [
        xrechnungRules.keys,
        xrechnungExtensionRules.keys,
        xrechnungCleanVehiclesRules.keys,
        xrechnungMetByConstruction.keys,
        xrechnungForTheSyntax.keys,
      ];
      final all = [for (final bucket in buckets) ...bucket];
      expect(all.toSet(), hasLength(all.length));
    });

    test('name rules the catalogue knows', () {
      for (final id in accountedXrechnungRules) {
        expect(xrechnungRuleFor(id).id, id);
      }
    });

    test('leave an unknown identifier unanswered', () {
      expect(() => xrechnungRuleFor('BR-DE-99'), throwsArgumentError);
    });

    test('cover what the profile evaluates', () {
      expect(implementedXrechnungRules, hasLength(47));
      expect(xrechnungMetByConstruction, hasLength(12));
      expect(xrechnungForTheSyntax, hasLength(2));
    });
  });

  group('the code lists', () {
    test('are the ones the artefacts declare', () {
      expect(xrechnungTypeCodes, hasLength(8));
      expect(xrechnungTypeCodes, contains('380'));
      expect(xrechnungTypeCodes, contains('381'));
      expect(xrechnungElectronicAddressSchemes, contains('0204'));
      expect(xrechnungIso6523Schemes, contains('0204'));
      expect(xrechnungDigaSchemes, {'XR01', 'XR02', 'XR03'});
    });

    test('draw the item classification schemes from UNTDID 7143', () {
      expect(xrechnungItemClassificationSchemes, contains('ZZZ'));
      expect(xrechnungItemClassificationSchemes, isNot(contains('CVD')));
    });
  });

  group('the profile identifiers', () {
    test('are read back from what an invoice claims', () {
      expect(
        XrechnungProfile.of(xrechnungSpecification),
        XrechnungProfile.cius,
      );
      expect(
        XrechnungProfile.of(xrechnungExtensionSpecification),
        XrechnungProfile.extension,
      );
      expect(
        XrechnungProfile.of(xrechnungCleanVehiclesSpecification),
        XrechnungProfile.cleanVehicles,
      );
    });

    test('do not claim a plain EN 16931 invoice', () {
      expect(XrechnungProfile.of(en16931Specification), isNull);
      expect(XrechnungProfile.of(null), isNull);
    });

    test('build the extension and clean vehicles ones on the CIUS', () {
      expect(
        xrechnungExtensionSpecification.startsWith(xrechnungSpecification),
        isTrue,
      );
      expect(
        xrechnungCleanVehiclesSpecification.startsWith(xrechnungSpecification),
        isTrue,
      );
    });
  });
}
