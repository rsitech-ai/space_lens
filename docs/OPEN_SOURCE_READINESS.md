# Open-Source Readiness

SpaceLens is **released under the Apache License 2.0**. The latest public
release includes a universal Developer ID-signed macOS app, Apple notarization,
a stapled ticket, Gatekeeper acceptance, checksums, and source provenance.

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
- README and release documentation link to the current public release and keep
  source, signing, notarization, and App Store evidence as separate gates.
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

## Release procedure for changed source

Every changed release must be rebuilt from its final clean `main` commit. The
new artifact must independently pass Developer ID signing, Apple notarization,
stapling, Gatekeeper assessment, checksum validation, and anonymous download
verification before it replaces the current public download.

## Explicit exclusions

- A Gitleaks 8.30.1 secret scan of the working tree and full Git history found
  no leaks. Broader static analysis or formal security-audit completeness is not
  claimed.
- A successful direct-download release does not imply App Store Connect upload,
  TestFlight qualification, App Review approval, or Mac App Store publication.
- Historical local artifacts are not promoted as evidence for the current
  source revision.

See the [latest GitHub release](https://github.com/rsitech-ai/space_lens/releases/latest)
for current artifact evidence and [the release runbook](RELEASING.md) for the
exact sequence.
