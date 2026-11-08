# CutSzn — Repository Status

| Item | Value |
|---|---|
| GitHub repository | https://github.com/asunnyboy861/CutSzn |
| Default branch | `main` |
| Pages path | `/docs` |
| Landing page | https://asunnyboy861.github.io/CutSzn/ |
| Support page | https://asunnyboy861.github.io/CutSzn/support.html |
| Privacy Policy | https://asunnyboy861.github.io/CutSzn/privacy.html |
| Terms of Use | https://asunnyboy861.github.io/CutSzn/terms.html |
| App Store ID | ⏳ Pending (not yet submitted) |
| Pages status | ✅ Active (all four URLs return 200) |
| Policy pages pushed | ✅ |
| Keytext pushed | ❌ Never pushed (gitignored, confidential ASO) |

## Build status

- iPhone 16 (iOS 26.4) simulator: ✅ BUILD SUCCEEDED / launched
- iPad Pro 13-inch (M5) simulator: ✅ BUILD SUCCEEDED
- Device archive signing: ⏳ DEFERRED — the local provisioning profile does not yet include App Groups / iCloud / HealthKit. After signing into Xcode:
  `xcodebuild -project CutSzn.xcodeproj -scheme CutSzn -destination 'generic/platform=iOS' -allowProvisioningUpdates build`

## Repository layout

```
CutSzn/
├── CutSzn/            # App target (SwiftUI + SwiftData)
├── CutSznWidget/      # WidgetKit extension
├── docs/              # GitHub Pages: landing + support + privacy + terms
├── project.yml        # xcodegen source of truth
├── us.md              # English development guide
├── price.md           # IAP configuration
├── capabilities.md    # capability + manual config reference
└── CutSzn.xcodeproj
```
