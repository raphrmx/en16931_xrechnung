/// Whether [value] is an IBAN that closes on its own check digits.
///
/// XRechnung checks this because a German invoice is paid by transfer or by
/// direct debit and nothing else: an account number that is one digit out is
/// a payment that does not arrive. The check is the ISO 13616 one, taken over
/// the account with its first four characters moved to the end.
///
/// Spaces are ignored, since an IBAN is often written in groups of four. Case
/// is not: an IBAN is written in capitals, and the German validator works the
/// check out in a way that a lowercase letter fails.
bool isIban(String value) {
  final account = value.replaceAll(' ', '');
  if (!_shape.hasMatch(account)) return false;
  final rearranged = account.substring(4) + account.substring(0, 4);
  var remainder = 0;
  for (final unit in rearranged.codeUnits) {
    // A digit is itself; a letter is the two digits 10 to 35, which is why
    // the remainder is carried rather than the number, as the number runs
    // past what an int holds.
    final digits =
        unit >= _a ? (unit - _a + 10).toString() : (unit - _zero).toString();
    for (final digit in digits.codeUnits) {
      remainder = (remainder * 10 + (digit - _zero)) % 97;
    }
  }
  return remainder == 1;
}

final RegExp _shape = RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z0-9]{0,30}$');

const int _zero = 0x30;
const int _a = 0x41;
