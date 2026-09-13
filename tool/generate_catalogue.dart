// Reads the XRechnung rule artefacts and writes the rule catalogue.
//
// The artefacts are published by KoSIT at
// https://github.com/itplr-kosit/xrechnung-schematron, under Apache 2.0. The
// licence would allow their content to be carried here with attribution, but
// nothing of it is: the messages are in German and are written against the
// XML rather than against the model, so they would be wrong in both language
// and subject. What is taken is which rules exist, what each is called, how
// severe it is, and which business terms it bears on. Those are facts. The
// meaning of every rule is implemented by hand against the semantic model, in
// this package's own words.
//
// Usage:
//   dart run tool/generate_catalogue.dart --fetch
//   dart run tool/generate_catalogue.dart [--dump <family>]
import 'dart:io';

import 'package:xml/xml.dart';

const String _base =
    'https://raw.githubusercontent.com/itplr-kosit/xrechnung-schematron/'
    'master/src/validation/schematron';

const Map<String, String> _sources = {
  'artefacts/xrechnung-common.sch': '$_base/common.sch',
  'artefacts/xrechnung-ubl.sch': '$_base/ubl/XRechnung-UBL-validation.sch',
  'artefacts/xrechnung-cii.sch': '$_base/cii/XRechnung-CII-validation.sch',
};

const String _output = 'lib/src/catalogue.g.dart';

/// A rule as the artefacts describe it.
class _Rule {
  _Rule(this.id, this.severity, this.terms);

  final String id;
  final String severity;
  final List<String> terms;
  final Set<String> syntaxes = {};
}

Future<void> main(List<String> arguments) async {
  if (arguments.contains('--fetch')) {
    for (final entry in _sources.entries) {
      await _fetch(entry.value, entry.key);
    }
  }

  final files = {
    'UBL': File('artefacts/xrechnung-ubl.sch'),
    'CII': File('artefacts/xrechnung-cii.sch'),
  };
  final common = File('artefacts/xrechnung-common.sch');
  for (final file in [...files.values, common]) {
    if (file.existsSync()) continue;
    stderr.writeln('Missing ${file.path}. Run with --fetch.');
    exitCode = 1;
    return;
  }

  final dump = arguments.indexOf('--dump');
  if (dump != -1 && dump + 1 < arguments.length) {
    for (final entry in files.entries) {
      _dump(entry.key, entry.value, arguments[dump + 1]);
    }
    return;
  }

  final rules = <String, _Rule>{};
  for (final entry in files.entries) {
    final source = entry.value.readAsStringSync();
    for (final rule in _read(source)) {
      final known = rules.putIfAbsent(rule.id, () => rule);
      known.syntaxes.add(entry.key);
      for (final term in rule.terms) {
        if (!known.terms.contains(term)) known.terms.add(term);
      }
    }
  }

  final catalogue = rules.values.toList()..sort(_byIdentifier);
  final version = _version(common.readAsStringSync());
  final lists = _lists(
    common.readAsStringSync(),
    files['UBL']!.readAsStringSync(),
  );
  File(_output).writeAsStringSync(_emit(catalogue, version, lists));

  final names = lists.keys.toList()..sort();
  for (final name in names) {
    stdout.writeln('  $name: ${lists[name]!.length} codes');
  }
  stdout.writeln('${catalogue.length} rules written to $_output');
  stdout.writeln('  XRechnung ${version ?? 'of unknown version'}');
  final counts = <String, int>{};
  for (final rule in catalogue) {
    counts[_family(rule.id)] = (counts[_family(rule.id)] ?? 0) + 1;
  }
  final families = counts.keys.toList()..sort();
  for (final family in families) {
    stdout.writeln('  $family: ${counts[family]}');
  }
  for (final rule in catalogue.where((r) => r.syntaxes.length == 1)) {
    stdout.writeln('  ${rule.id} is ${rule.syntaxes.single} only');
  }
}

/// Prints what the artefacts say about one family, to read while writing it.
void _dump(String syntax, File file, String family) {
  final document = XmlDocument.parse(file.readAsStringSync());
  final seen = <String>{};
  for (final assertion in document.findAllElements('assert')) {
    final id = assertion.getAttribute('id');
    if (id == null || !id.startsWith(family)) continue;
    if (!seen.add(id)) continue;
    stdout.writeln(
      '$syntax $id [${assertion.getAttribute('flag')}] '
      '${_flat(assertion.innerText)}',
    );
    stdout.writeln('    test: ${_flat(assertion.getAttribute('test')!)}');
  }
  stdout.writeln('${seen.length} rules in $family');
}

String _flat(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

Future<void> _fetch(String url, String target) async {
  Directory('artefacts').createSync(recursive: true);
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('${response.statusCode} for $url');
    }
    await response.pipe(File(target).openWrite());
    stdout.writeln('Fetched $target');
  } finally {
    client.close();
  }
}

/// The release the artefacts are written for.
String? _version(String common) {
  final match = RegExp('name="XR-MAJOR-MINOR-VERSION" value="\'([0-9.]+)\'"')
      .firstMatch(common);
  return match?.group(1);
}

/// Every rule one artefact file asserts.
Iterable<_Rule> _read(String source) sync* {
  final document = XmlDocument.parse(source);
  final seen = <String>{};
  for (final assertion in document.findAllElements('assert')) {
    final id = assertion.getAttribute('id');
    if (id == null || !id.startsWith('BR-')) continue;
    if (!seen.add(id)) continue;
    yield _Rule(
      id,
      _severity(assertion.getAttribute('flag')),
      _terms(assertion.innerText),
    );
  }
}

/// What a receiver does with an invoice that breaks the rule.
///
/// The artefacts flag three levels where the model knows two. A rule flagged
/// information is a remark on an invoice that is otherwise accepted, which is
/// what a warning already is.
String _severity(String? flag) => flag == 'fatal' ? 'fatal' : 'warning';

/// The business terms a rule bears on, read out of the message.
List<String> _terms(String message) {
  final found = <String>[];
  final pattern = RegExp(r'\b(?:BT|BG)-\d+(?:-\d+)?\b');
  for (final match in pattern.allMatches(message)) {
    final term = match.group(0)!;
    if (!found.contains(term)) found.add(term);
  }
  return found;
}

/// BR-DE-2 sorts before BR-DE-10, which a plain string sort gets backwards.
int _byIdentifier(_Rule a, _Rule b) {
  final family = _family(a.id).compareTo(_family(b.id));
  if (family != 0) return family;
  final number = _number(a.id).compareTo(_number(b.id));
  if (number != 0) return number;
  return a.id.compareTo(b.id);
}

int _number(String id) {
  final match = RegExp(r'(\d+)(?:-[ab])?$').firstMatch(id);
  return match == null ? 0 : int.parse(match.group(1)!);
}

String _family(String id) {
  final match = RegExp(r'^(BR-[A-Z-]*?)-?\d').firstMatch(id);
  return match?.group(1) ?? id;
}

String _emit(
  List<_Rule> rules,
  String? version,
  Map<String, Set<String>> lists,
) {
  final buffer = StringBuffer()
    ..writeln('// GENERATED by tool/generate_catalogue.dart. Do not edit.')
    ..writeln('//')
    ..writeln('// Read from the XRechnung rule artefacts, written for')
    ..writeln('// XRechnung ${version ?? 'of unknown version'}. What is taken')
    ..writeln('// from them is which rules exist, how severe each is, and')
    ..writeln('// which business terms it bears on.')
    ..writeln()
    ..writeln("import 'package:en16931/en16931.dart';")
    ..writeln()
    ..writeln('/// Every rule XRechnung adds to EN 16931.')
    ..writeln('///')
    ..writeln('/// The list is read from the published artefacts, so it is')
    ..writeln('/// complete by construction rather than by memory.')
    ..writeln('const List<RuleDescriptor> xrechnungCatalogue = [');
  for (final rule in rules) {
    final terms = rule.terms.map((term) => "'$term'").join(', ');
    buffer
      ..writeln('  RuleDescriptor(')
      ..writeln("    id: '${rule.id}',")
      ..writeln('    family: RuleFamily.profile,')
      ..writeln('    severity: RuleSeverity.${rule.severity},')
      ..writeln('    terms: [$terms],')
      ..writeln('  ),');
  }
  buffer.writeln('];');
  final names = lists.keys.toList()..sort();
  for (final name in names) {
    final codes = lists[name]!.toList()..sort();
    buffer
      ..writeln()
      ..writeln('/// ${_listDoc[name]}')
      ..writeln('///')
      ..writeln('/// ${codes.length} codes.')
      ..writeln('const Set<String> $name = {');
    for (final code in codes) {
      buffer.writeln("  '$code',");
    }
    buffer.writeln('};');
  }
  return buffer.toString();
}

/// What this package calls each code list the artefacts declare.
const Map<String, String> _listNames = {
  'ISO-6523-ICD-CODES': 'xrechnungIso6523Schemes',
  'CEF-EAS-CODES': 'xrechnungElectronicAddressSchemes',
  'DIGA-CODES': 'xrechnungDigaSchemes',
  'UNTDID-7143-CODES': 'xrechnungItemClassificationSchemes',
  'supportedInvAndCNTypeCodes': 'xrechnungTypeCodes',
};

/// What each list is, for the doc comment above it.
const Map<String, String> _listDoc = {
  'xrechnungIso6523Schemes':
      'The registers a party identifier (BT-29, BT-46) may be issued under.',
  'xrechnungElectronicAddressSchemes':
      'The registers an electronic address (BT-34, BT-49) may be issued '
          'under.',
  'xrechnungDigaSchemes':
      'The registers the extension adds for digital health applications.',
  'xrechnungItemClassificationSchemes':
      'The schemes an item classification (BT-158-1) may be given under.',
  'xrechnungTypeCodes': 'The document type codes (BT-3) XRechnung accepts.',
};

/// The code lists the artefacts hold in their Schematron variables.
///
/// Two shapes are used: a single space-separated string for the long lists
/// that come from ISO and the UN, and an XPath sequence for the short ones
/// XRechnung writes itself.
Map<String, Set<String>> _lists(String common, String ubl) {
  final lists = <String, Set<String>>{};
  final string = RegExp('<let name="([A-Za-z0-9_-]+)"\\s+value="\'([^\']*)\'');
  for (final match in string.allMatches(common)) {
    final name = _listNames[match.group(1)];
    if (name == null) continue;
    lists[name] = _codes(match.group(2)!);
  }
  final sequence = RegExp('<let name="([A-Za-z0-9_-]+)" value="\\(([^)]*)\\)');
  for (final match in sequence.allMatches(ubl)) {
    final name = _listNames[match.group(1)];
    if (name == null) continue;
    lists[name] = _codes(match.group(2)!.replaceAll(RegExp('[\'",]'), ' '));
  }
  return lists;
}

Set<String> _codes(String source) => source
    .trim()
    .split(RegExp(r'\s+'))
    .where((code) => code.isNotEmpty)
    .toSet();
