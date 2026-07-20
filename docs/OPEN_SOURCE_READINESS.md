# Open-Source Readiness

SpaceLens is **repository-ready pending final verification**, but it is not yet
open-source-ready or package-ready.

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

## Required owner and external gates

1. Approve a license, licensor/copyright holder, and contribution terms; add
   `LICENSE` and update the README and contribution guide.
2. Confirm rights and license coverage for every binary asset in
   `docs/ASSET_PROVENANCE.md`.
3. Confirm the canonical GitHub owner and explicitly approve any repository
   transfer or visibility change.
4. Restore GitHub Actions billing/spending health and obtain a green run on the
   final commit.
5. Install an appropriate Developer ID Application identity, build from the
   final clean commit, notarize, staple, assess with Gatekeeper, and archive the
   exact evidence.
6. Create and publish `v1.0.0` only after all earlier gates pass.

## Explicit exclusions

- A formal security scan was not performed, at the owner's direction. This
  repository does not claim scan coverage or security completeness.
- No Apple notarization, App Store Connect upload, GitHub visibility change,
  repository transfer, tag, or release publication is performed by repository
  preparation alone.
- Historical local artifacts are not promoted as evidence for the current
  source revision.

See [release status](release/1.0/RELEASE_STATUS.md) for the current evidence
matrix and [the release runbook](RELEASING.md) for the exact sequence.
