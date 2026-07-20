# Contributing to SpaceLens

Thank you for helping improve SpaceLens. Small, focused changes with clear
tests are easiest to review.

## Development setup

SpaceLens requires macOS 14 or later, Xcode 26.6, Swift 6, and XcodeGen 2.45.4.
There are no third-party Swift package dependencies.

```bash
swift test -Xswiftc -warnings-as-errors
./script/generate_xcode_project.sh
git diff --exit-code -- SpaceLens.xcodeproj
./script/build_and_run.sh --verify
```

## Pull requests

1. Open an issue for a substantial behavior or architecture change.
2. Keep pure logic separate from filesystem and process I/O.
3. Add focused unit coverage, a boundary integration check when applicable,
   and update user-facing documentation when behavior changes.
4. Preserve the cleanup contract: exact paths, explicit confirmation,
   cleanup-ready classifications only, and Move to Bin rather than permanent
   deletion.
5. Do not commit build output, credentials, signing material, notarization
   profiles, private paths, or private file contents.

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
Security reports must follow [SECURITY.md](SECURITY.md), not a public issue.

## Licensing

The repository license is an owner-controlled release gate and is not yet
declared. Contributions cannot be accepted as open-source contributions until
a license and contribution terms are published.
