// Downloads the XRechnung test suite KoSIT publishes.
//
// The documents come from
// https://github.com/itplr-kosit/xrechnung-testsuite under Apache 2.0. They
// are read by the test suite and never redistributed, so they land in a
// directory git ignores. Both syntaxes are taken: the same business case is
// published as UBL and as CII, and a profile has to say the same thing about
// either.
//
// Usage:
//   dart run tool/fetch_examples.dart
import 'dart:convert';
import 'dart:io';

const String _tree = 'https://api.github.com/repos/itplr-kosit/'
    'xrechnung-testsuite/git/trees/master?recursive=1';

const String _raw = 'https://raw.githubusercontent.com/itplr-kosit/'
    'xrechnung-testsuite/master';

const String _directory = 'examples_from_kosit';

/// The folders that hold documents meant to be valid.
const List<String> _wanted = [
  'src/test/business-cases/',
  'src/test/technical-cases/',
];

Future<void> main() async {
  final client = HttpClient();
  try {
    final listing = jsonDecode(await _text(client, _tree)) as Map;
    final paths = [
      for (final entry in listing['tree'] as List)
        (entry as Map)['path'] as String,
    ].where(_isWanted).toList()
      ..sort();

    Directory(_directory).createSync(recursive: true);
    for (final path in paths) {
      final name = path.split('/').sublist(3).join('_');
      File(
        '$_directory/$name',
      ).writeAsStringSync(await _text(client, '$_raw/$path'));
    }
    stdout.writeln('${paths.length} documents in $_directory');
  } finally {
    client.close();
  }
}

bool _isWanted(String path) =>
    path.toLowerCase().endsWith('.xml') &&
    _wanted.any((folder) => path.startsWith(folder));

Future<String> _text(HttpClient client, String url) async {
  final request = await client.getUrl(Uri.parse(url));
  request.headers.set('User-Agent', 'en16931_xrechnung');
  final token = Platform.environment['GITHUB_TOKEN'];
  if (token != null && token.isNotEmpty) {
    request.headers.set('Authorization', 'Bearer $token');
  }
  final response = await request.close();
  if (response.statusCode != 200) {
    throw HttpException('${response.statusCode} for $url');
  }
  return await response.transform(utf8.decoder).join();
}
