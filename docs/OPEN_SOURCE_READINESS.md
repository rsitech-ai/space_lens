# Open-Source Readiness

SpaceLens is **open-source source-ready under the Apache License 2.0**. A valid
Developer ID Application identity is installed. The notarized direct-download
package remains **blocked:external** until notarization credentials are stored
for `notarytool`.

## Completed in the repository

- Build, test, generated-project, privacy-manifest, signing, source-provenance,
  notarization-finalization, and release-publication procedures are documented.
- CI selects Xcode 26.6 exactly and downloads XcodeGen 2.45.4 from its official
  release with a pinned SHA-256 checksum.
- Contributor guidance, issue forms, pull-request checks, code ownership,
  support, code of conduct, security-reporting policy, Dependabot configuration,
  changelog, editor settings, and line-ending rules are present.
- Test fixtures use fictional paths and project names rather than contributor
  machine paths or unrelated internal project identifiers.
- README and release documents truthfully state that no public tag or release
  asset exists yet.
- The owner approved the Apache License 2.0, matching contribution terms, and
  Apache-2.0 coverage for all inventoried app icons and screenshots on
  2026-07-20.
- Rafal Sikora is the copyright owner. RSI Tech is the public maintainer, with
  `https://rsitech.ai` and `info@rsitech.ai` as the canonical public and
  confidential project contacts.
- The canonical repository is `rsitech-ai/space_lens`; transfer and public
  visibility, including publication of the existing Git author metadata, were
  explicitly approved by the owner.
- GitHub Actions completed successfully on Xcode 26.6 for PR #14.

## Remaining external package gates

1. Build from the final clean commit with the installed Developer ID Application
   identity. Store notarization credentials, then notarize, staple, assess with
   Gatekeeper, and archive the exact evidence.
2. Create and publish `v1.0.0` only after the signed and notarized artifact gate
   passes.

## Explicit exclusions

- A Gitleaks 8.30.1 secret scan of the working tree and full Git history found
  no leaks. Broader static analysis or formal security-audit completeness is not
  claimed.
- No Apple notarization, App Store Connect upload, tag, or release publication
  is implied by the public source repository.
- Historical local artifacts are not promoted as evidence for the current
  source revision.

See [release status](release/1.0/RELEASE_STATUS.md) for the current evidence
matrix and [the release runbook](RELEASING.md) for the exact sequence.
