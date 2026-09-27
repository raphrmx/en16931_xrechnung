import 'dart:io';

import 'package:en16931/en16931.dart';
import 'package:en16931_cii/en16931_cii.dart';
import 'package:en16931_ubl/en16931_ubl.dart';
import 'package:en16931_xrechnung/en16931_xrechnung.dart';
import 'package:test/test.dart';

/// The test suite KoSIT publishes for XRechnung.
///
/// It is not part of this repository. Run
/// `dart run tool/fetch_examples.dart` to pull it in, and these tests wake
/// up. Checking our own invoices proves the rules do what this package thinks
/// they do; checking these proves they do what Germany thinks they do.
///
/// Each business case is published twice, once as UBL and once as CII. A
/// profile bears on the invoice rather than on the document, so both have to
/// come out the same.
const String _directory = 'examples_from_kosit';

/// The documents that carry a term EN 16931 has no room for.
///
/// The extension adds a payment made by somebody else (BT-DEX-002). The model
/// here is the standard's, so that amount is lost on the way in and the total
/// no longer follows from the parts. It is the same gap
/// `xrechnungMetByConstruction` names under BR-DEX-09, seen from the other
/// side.
const Map<String, String> _beyondTheModel = {
  'extension_05.01a-INVOICE_ubl.xml':
      'Carries a third party payment (BT-DEX-002), which EN 16931 cannot '
          'express, so BT-115 cannot reconcile.',
};

void main() {
  final directory = Directory(_directory);
  if (!directory.existsSync()) {
    test('the published examples', () {}, skip: 'Run tool/fetch_examples.dart');
    return;
  }

  final files = directory.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('there are documents to check', () {
    expect(files, hasLength(greaterThan(50)));
  });

  for (final file in files) {
    final name = file.uri.pathSegments.last;
    final isCii = name.contains('uncefact');

    group(name, () {
      late Invoice invoice;

      setUp(() {
        final source = file.readAsStringSync();
        invoice = isCii ? readCii(source) : readUbl(source);
      });

      test('claims an XRechnung profile', () {
        expect(xrechnungProfileOf(invoice), isNotNull);
      });

      test('breaks no rule that would refuse it', () {
        if (_beyondTheModel.containsKey(name)) {
          markTestSkipped(_beyondTheModel[name]!);
          return;
        }
        // These are the documents Germany publishes to test a validator
        // against, so a fatal violation means this package reads or checks
        // something wrong, not that the document is wrong. Warnings are
        // another matter: a document is accepted while breaking one, and
        // KoSIT publishes plenty that do.
        expect(
          validateXrechnung(invoice)
              .where((v) => v.rule.severity == RuleSeverity.fatal)
              .map((violation) => violation.toString()),
          isEmpty,
        );
      });
    });
  }

  test('the two syntaxes of a business case agree', () {
    var compared = 0;
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      if (!name.contains('_ubl.xml')) continue;
      final other = File(
        '$_directory/${name.replaceAll('_ubl.xml', '_uncefact.xml')}',
      );
      if (!other.existsSync()) continue;
      final fromUbl = validateXrechnung(readUbl(file.readAsStringSync()));
      final fromCii = validateXrechnung(readCii(other.readAsStringSync()));
      expect(
        fromCii.map((violation) => violation.rule.id).toSet(),
        fromUbl.map((violation) => violation.rule.id).toSet(),
        reason: name,
      );
      compared++;
    }
    expect(compared, greaterThan(20));
  });
}
