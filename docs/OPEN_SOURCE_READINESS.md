# Open-Source Readiness

SpaceLens is **open-source source-ready under the MIT License**. A signed,
notarized direct-download package remains **blocked:external** until an Apple
Developer ID Application identity and notarization credentials are available.

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
- The owner approved the MIT License, contribution terms, and MIT coverage for
  all inventoried app icons and screenshots on 2026-07-20.
- The canonical repository is `rsitech-ai/space_lens`; transfer and public
  visibility, including publication of the existing Git author metadata, were
  explicitly approved by the owner.
- GitHub Actions completed successfully on Xcode 26.6 for PR #14.

## Remaining external package gates

1. Install an appropriate Developer ID Application identity, build from the
   final clean commit, notarize, staple, assess with Gatekeeper, and archive the
   exact evidence.
2. Create and publish `v1.0.0` only after the signed and notarized artifact gate
   passes.

## Explicit exclusions

- A formal security scan was not performed, at the owner's direction. This
  repository does not claim scan coverage or security completeness.
- No Apple notarization, App Store Connect upload, tag, or release publication
  is implied by the public source repository.
- Historical local artifacts are not promoted as evidence for the current
  source revision.

See [release status](release/1.0/RELEASE_STATUS.md) for the current evidence
matrix and [the release runbook](RELEASING.md) for the exact sequence.
