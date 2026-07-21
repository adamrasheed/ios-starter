# ios-starter

A SwiftUI app template that starts at "add my feature" instead of "wire up payments."

Extracted from [Retune](https://apps.apple.com/us/app/id6789782801), a tuner that went from empty
folder to live on the App Store in twelve days. Everything here is the part of that work which
had nothing to do with tuning guitars: the paywall, the CI, the project generation, the
screenshot harness, the decisions that were annoying to get right once and are free to reuse.

## What you get

| | |
|---|---|
| **StoreKit 2 paywall** | One non-consumable unlock, behind a protocol with a mock. Handles refunds, restores, Family Sharing, Ask-to-Buy, cross-device purchases. No RevenueCat. |
| **XcodeGen project** | `project.yml` is the source of truth. The `.xcodeproj` is generated and gitignored, so adding files never causes a merge conflict. |
| **CI that costs almost nothing** | SwiftLint on Linux runners automatically, macOS build+test manually. See the cost math in the workflow comments. |
| **Design tokens** | Spacing, radius, semantic colour, typography, motion. No raw numbers in views. |
| **The states apps forget** | Empty, loading, and error views, plus an app-wide error presenter that makes `try?` unnecessary. |
| **Screenshot harness** | The app poses itself from environment variables. Regenerating every App Store capture is one command. |
| **Analytics + logging** | Both behind protocols, both no-op by default. Swap a vendor in without touching a view. |
| **Review prompting** | Milestone-gated, so you don't burn Apple's three-per-year budget on a user who opened the app once. |
| **Tests that run in milliseconds** | Swift Testing. Pure logic and in-memory SwiftData, no simulator gymnastics. |

Zero third-party dependencies. SwiftUI, SwiftData, StoreKit 2 and `os.Logger` cover all of it.

## Start a new app

Click **Use this template** on GitHub, clone it, then:

```bash
./scripts/rename.sh MyApp com.yourcompany.myapp YOUR_TEAM_ID
open MyApp.xcodeproj
```

That renames the target, folders, scheme, StoreKit config and bundle identifiers, regenerates the
project, and deletes itself. Run it before you write any code.

If you use Claude Code, `/ios-app-kickoff` does all of the above and then interviews you about the
app, seeds `CLAUDE.md`, and plans the build.

## Requirements

- Xcode 26 or newer (Swift Testing and `@Observable`)
- `brew install xcodegen swiftlint`
- iOS 17 minimum deployment target

## Layout

```
project.yml              Source of truth for the Xcode project. Never edit the .xcodeproj.
Starter/
  App/                   @main entry, the tab shell, dependency injection
  Core/                  Pure logic and data. No SwiftUI imports.
  DesignSystem/          Tokens and shared components
  Features/              One folder per feature: Store, Settings, Home, Onboarding
  Platform/              Analytics, logging, haptics, errors, review prompting
  Support/               Demo mode for screenshots
StarterTests/            Swift Testing suites
docs/architecture.md     How it fits together, and why
docs/adr/decision-log.md The decisions, with the reasoning that produced them
docs/ship-checklist.md   Everything between "it works" and "it's on the App Store"
```

## The three rules worth keeping

**Dependencies point inward.** `Features/` may use `Core/`, `DesignSystem/` and `Platform/`.
Nothing may depend on `Features/`. `Core/` imports no SwiftUI. That is what keeps the logic
testable without a simulator.

**Mutation logic lives in stores, not views.** A view calls `store.add(...)`; a view never
touches `ModelContext`. This is the difference between a unit test that runs in three
milliseconds and a UI test you eventually stop running.

**External services sit behind a protocol with a mock.** Payments, analytics, anything with a
network or an Apple ID behind it. It lets you build the paid half of the app before the product
exists in App Store Connect, and it is why the entitlement rules are unit-tested at all.

## Before you ship

Read `docs/ship-checklist.md`. The short version: restore button, live privacy URL, real product
id in three places, and a device pass on a real StoreKit sandbox account. A green CI build proves
none of those.

## Licence

MIT. Use it for anything.
