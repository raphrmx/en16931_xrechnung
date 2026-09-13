## 0.1.0

First release.

- `xrechnungSpecification` carries BT-24 for an invoice claimed under
  XRechnung 3.0, with `xrechnungExtensionSpecification` and
  `xrechnungCleanVehiclesSpecification` for the two profiles beside it. The
  register moved to `xeinkauf.de` with release 3.0, so an invoice still
  claiming the 2.x identifier is claiming a version that is no longer read.
- `validateXrechnung` checks the rules of the standard and the 61 the profile
  adds, in one pass. Which of the three sets of profile rules run is read from
  what the invoice claims in BT-24, so an invoice is never checked as
  something it does not say it is.
- Of the 61, 47 are checked here: the buyer reference is present, the seller
  is reachable, city and post code are given on both sides, the payment
  instructions carry the group that goes with the means and not the other two,
  an IBAN closes on its check digits, every breakdown entry states its rate,
  and the type code is one of the eight XRechnung expects.
- `Skonto`, `skontoPaymentTerms` and `readSkonto` write and read the discount
  for early payment. EN 16931 has no term for it and leaves the payment terms
  as free text; Germany reads that text back in one exact form, which is what
  BR-DE-18 rejects an invoice for getting wrong.
- `xrechnungOverrides` names the rules of the standard a profile rewrites. A
  profile that widens a code list has to take the narrower rule off, or the
  invoice breaks the standard for obeying the profile: the clean vehicles
  profile classifies a vehicle under a scheme BR-CL-13 refuses.
- Twelve rules cannot be broken by an invoice built with this model, and two
  are about how the XML is written. Both are listed with what they ask rather
  than quietly skipped, in `xrechnungMetByConstruction` and
  `xrechnungForTheSyntax`. Most of the twelve bear on terms the extension adds
  and EN 16931 does not have.
- The XRechnung code lists ship with the package: the type codes, the ISO 6523
  registers, the electronic address schemes, the UNTDID 7143 classification
  schemes and the three the extension adds for digital health applications.
- The catalogue is read from the artefacts KoSIT publishes, under Apache 2.0.
  None of their content is reproduced: they are written in German and against
  the XML rather than against the model. What is taken is which rules exist,
  how severe each is and which terms it bears on. Every message and every
  check here is this package's own.
- A test fails when a rule of the catalogue has no answer, so what is covered
  is a fact rather than a claim.
