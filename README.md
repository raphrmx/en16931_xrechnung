<a alt="ComApps Logo" href="https://comapps.be" target="_blank" rel="noreferrer"><img src="https://www.comapps.be/wp-content/uploads/2026/09/CompleteLogoHorizontalMini.png" style="margin: 15px"></a>

# EN 16931 XRechnung

![Build](https://img.shields.io/github/actions/workflow/status/raphrmx/en16931_xrechnung/ci.yml?branch=main&label=build)
[![Pub Version](https://img.shields.io/pub/v/en16931_xrechnung?color=blue)](https://pub.dev/packages/en16931_xrechnung)
[![Maintainer](https://img.shields.io/badge/Maintainer-Raphael_Vrient-purple)](https://pub.dev/publishers/comapps.be/packages)
[![License](https://img.shields.io/badge/Licence-MIT-blue)](https://pub.dev/packages/en16931_xrechnung/license)
![Maintenance](https://img.shields.io/badge/Maintained-yes-success)

XRechnung 3.0: the 61 rules Germany adds to EN 16931, and the identifiers an
invoice is claimed under.

Every invoice to a German public body goes under this profile. An invoice can
satisfy the standard and still be refused. This says so before it is sent.

## Install

```yaml
dependencies:
  en16931: ^0.1.2
  en16931_xrechnung: ^0.1.1
```

## Check an invoice

Claim the profile on the invoice, then check it. The standard and the profile
are checked together.

```dart
import 'package:en16931/en16931.dart';
import 'package:en16931_xrechnung/en16931_xrechnung.dart';

final invoice = Invoice.fromLines(
  number: '2026-0042',
  issueDate: DateTime(2026, 9, 13),
  specificationIdentifier: xrechnungSpecification,
  buyerReference: '991-33333TEST-33',
  seller: const Seller(
    name: 'COMAPPS GmbH',
    vatIdentifier: 'DE123456789',
    electronicAddress: Identifier('991-33333TEST-33', scheme: Scheme.germanLeitwegId),
    address: Address(city: 'Berlin', postalCode: '10115', country: 'DE'),
    contact: Contact(
      name: 'Rechnungswesen',
      telephone: '+49 30 123456',
      email: 'rechnung@example.de',
    ),
  ),
  buyer: const Buyer(
    name: 'Bundesamt',
    electronicAddress: Identifier('991-33333TEST-33', scheme: Scheme.germanLeitwegId),
    address: Address(city: 'Bonn', postalCode: '53113', country: 'DE'),
  ),
  delivery: Delivery(date: CalendarDate(2026, 9, 12)),
  paymentInstructions: const PaymentInstructions(
    means: PaymentMeansCode.sepaCreditTransfer,
    creditTransfers: [CreditTransferAccount('DE89370400440532013000')],
  ),
  lines: [...],
);

for (final violation in validateXrechnung(invoice)) {
  print(violation);
}
```

## What XRechnung adds

Four things an invoice that passes EN 16931 still gets refused for.

**The buyer reference.** BT-10 is optional in the standard and required here.
A public body puts its Leitweg-ID there, and the invoice is routed by it.

**A seller anyone can reach.** The contact group, a contact point, a telephone
number with digits in it and an email address that is shaped like one. City
and post code on both sides.

**Payment instructions, and only the ones that go with the means.** A transfer
carries the account and nothing else, a card the card, a direct debit the
mandate with its creditor identifier. An IBAN behind a SEPA payment has to
close on its own check digits.

**A discount for early payment written in one exact form.** The standard
leaves the payment terms as free text. Germany reads that text back, so
`skontoPaymentTerms` writes it and `readSkonto` reads it.

```dart
skontoPaymentTerms(
  [Skonto.of(days: 14, percentage: 2)],
  text: 'Zahlbar innerhalb 30 Tagen.',
);
// Zahlbar innerhalb 30 Tagen.
// #SKONTO#TAGE=14#PROZENT=2.00#
```

## Worth knowing up front

Three profiles sit under one standard. `xrechnungSpecification` is XRechnung
proper, and the extension and clean vehicles identifiers each turn on their
own rules. Which ones run is read from BT-24: an invoice checked as something
it does not claim to be tells you nothing.

A profile that widens a code list also takes the narrower rule of the standard
off. The clean vehicles profile classifies a vehicle under a scheme BR-CL-13
refuses, so an invoice obeying the profile would break the standard.
`xrechnungOverrides` names each pair.

Of the 61 rules, 47 are checked here, 12 cannot be broken by an invoice built
with this model, and 2 are about how the XML is written rather than what the
invoice says. Most of the 12 bear on terms the extension adds and EN 16931
does not have, sub invoice lines and third party payments: an extension
document read from elsewhere loses those terms on the way in.

The rule catalogue is read from the artefacts KoSIT publishes, so it is
complete by construction. A test fails when a rule has no answer.

## What it does not do

It says whether an invoice is ready to send, and nothing else. The model and
the rules of the standard are in
[en16931](https://pub.dev/packages/en16931), and the document is written by
[en16931_cii](https://pub.dev/packages/en16931_cii) or
[en16931_ubl](https://pub.dev/packages/en16931_ubl). How it reaches the public
body, over Peppol or through one of the German portals, does not change the
document.

## License

Released under the [MIT licence](https://pub.dev/packages/en16931_xrechnung/license).

The rule catalogue is generated from the artefacts KoSIT publishes, which are
Apache 2.0. None of their content is redistributed: what is taken from them is
which rules exist, how severe each is and which terms it bears on.
