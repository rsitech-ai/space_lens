## Summary

Describe the user-visible or maintenance outcome.

## Validation

- [ ] `swift test -Xswiftc -warnings-as-errors`
- [ ] `./script/build_and_run.sh --verify`
- [ ] Generated Xcode project is unchanged after `./script/generate_xcode_project.sh`

## Release and safety checks

- [ ] Cleanup behavior remains confirmation-gated and Move-to-Bin only.
- [ ] Privacy, support, packaging, or release documentation was updated if affected.
- [ ] No generated build output, credentials, private paths, or notarization material is included.
