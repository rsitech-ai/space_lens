# Asset Provenance

Status: **owner confirmation required before public open-source release**

This inventory covers repository binary assets. It records what must be
confirmed without inferring authorship or license rights.

| Asset group | Repository paths | Intended use | Required confirmation |
| --- | --- | --- | --- |
| SpaceLens app icon | `Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-16.png`, `AppIcon-32.png`, `AppIcon-64.png`, `AppIcon-128.png`, `AppIcon-256.png`, `AppIcon-512.png`, `AppIcon-1024.png` | Application icon and product identity | Owner created or controls all rights; redistribution and modification are permitted under the chosen repository license or an explicit asset exception. |
| README screenshot | `docs/screenshots/spacelens-main.png` | Public product documentation | Screenshot contains no private data or third-party content that cannot be redistributed. |
| Release feature screenshot | `docs/release/1.0/screenshots/SpaceLens-macOS-dark-feature-1280x800.jpeg` | Release and store presentation | Screenshot contains no private data or third-party content that cannot be redistributed. |

No third-party Swift package or vendored source dependency is declared in
`Package.swift`, `project.yml`, or the resolved package graph. That fact does not
replace owner confirmation for the binary assets above.

When confirmed, record the date, confirmer, chosen license coverage, and any
asset-specific exception here before publication.
