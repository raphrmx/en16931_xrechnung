import 'package:decimal/decimal.dart';
import 'package:en16931/en16931.dart';

/// A discount for paying early, as XRechnung writes it.
///
/// EN 16931 has no term for this: the standard leaves the payment terms
/// (BT-20) as free text. Germany does not, and writes the discount into that
/// same text in a fixed form a machine can read back. Getting that form
/// wrong is what BR-DE-18 rejects, so build the text with
/// [skontoPaymentTerms] rather than by hand.
final class Skonto {
  /// [percentage] off the amount due when it is paid within [days] days.
  const Skonto({
    required this.days,
    required this.percentage,
    this.baseAmount,
  });

  /// The same, from plain numbers.
  factory Skonto.of({
    required int days,
    required num percentage,
    num? baseAmount,
  }) =>
      Skonto(
        days: days,
        percentage: exact(percentage),
        baseAmount: baseAmount == null ? null : exact(baseAmount),
      );

  /// How many days from the invoice date the discount holds for.
  final int days;

  /// How much comes off, as a percentage.
  final Decimal percentage;

  /// What the percentage is taken of, when it is not the whole amount due
  /// (BT-115).
  ///
  /// A discount that only covers part of the invoice, the goods but not the
  /// freight for instance, states that part here.
  final Decimal? baseAmount;

  @override
  bool operator ==(Object other) =>
      other is Skonto &&
      other.days == days &&
      other.percentage == percentage &&
      other.baseAmount == baseAmount;

  @override
  int get hashCode => Object.hash(days, percentage, baseAmount);

  @override
  String toString() => _line(this);
}

/// The payment terms (BT-20) carrying [discounts], under [text].
///
/// The free text comes first and the discounts follow, one to a line, each
/// closed by a line break. That layout is the rule: XRechnung reads the lines
/// that begin with a hash and expects the last of them to be followed by a
/// break.
///
/// Throws [ArgumentError] on a discount that cannot be written: the form
/// carries no sign on the percentage and no fraction on the days.
String skontoPaymentTerms(Iterable<Skonto> discounts, {String? text}) {
  final buffer = StringBuffer();
  if (text != null && text.trim().isNotEmpty) {
    buffer.writeln(text.trim());
  }
  for (final discount in discounts) {
    if (discount.days < 0) {
      throw ArgumentError.value(
        discount.days,
        'days',
        'A discount runs for a number of days that cannot be negative',
      );
    }
    if (discount.percentage < Decimal.zero) {
      throw ArgumentError.value(
        discount.percentage.toString(),
        'percentage',
        'A discount is written without a sign',
      );
    }
    buffer.writeln(_line(discount));
  }
  return buffer.toString();
}

/// The discounts [paymentTerms] carries, in the order they are written.
///
/// A line that begins with a hash and is not a well formed discount is left
/// out rather than guessed at. [xrechnungRules] reports it under BR-DE-18,
/// which is where a malformed line belongs.
List<Skonto> readSkonto(String? paymentTerms) {
  if (paymentTerms == null) return const [];
  final discounts = <Skonto>[];
  for (final line in skontoLines(paymentTerms)) {
    final match = skontoForm.firstMatch(line);
    if (match == null) continue;
    discounts.add(
      Skonto(
        days: int.parse(match.group(1)!),
        percentage: Decimal.parse(match.group(2)!),
        baseAmount:
            match.group(3) == null ? null : Decimal.parse(match.group(3)!),
      ),
    );
  }
  return discounts;
}

/// The lines of [paymentTerms] that mean to be a discount.
///
/// A line beginning with a hash is one, whether or not it is well formed.
/// Anything else is free text and no rule bears on it.
Iterable<String> skontoLines(String paymentTerms) sync* {
  for (final line in paymentTerms.split(RegExp(r'\r?\n'))) {
    final trimmed = line.trim();
    if (trimmed.startsWith('#')) yield trimmed;
  }
}

/// Whether every discount in [paymentTerms] is closed by a line break.
///
/// XRechnung asks for it so that a reader can tell the end of a discount from
/// the start of whatever follows. What has to follow is the break, not the
/// end of the text: free text may come after it.
bool skontoIsClosed(String paymentTerms) {
  // Splitting leaves an empty last element when the text ends with a break,
  // so a discount sitting last is a discount with nothing closing it.
  final lines = paymentTerms.split(RegExp(r'\r?\n'));
  return !lines.last.trim().startsWith('#');
}

/// The form one discount is written in.
///
/// Two decimals on the percentage and on the base amount, no sign on the
/// first and an optional one on the second, and a hash between every part.
final RegExp skontoForm = RegExp(
  r'^#SKONTO#TAGE=([0-9]+)#PROZENT=([0-9]+\.[0-9]{2})'
  r'(?:#BASISBETRAG=(-?[0-9]+\.[0-9]{2}))?#$',
);

String _line(Skonto discount) {
  final buffer = StringBuffer('#SKONTO#TAGE=${discount.days}')
    ..write('#PROZENT=${discount.percentage.toStringAsFixed(2)}');
  if (discount.baseAmount case final base?) {
    buffer.write('#BASISBETRAG=${base.toStringAsFixed(2)}');
  }
  return (buffer..write('#')).toString();
}
