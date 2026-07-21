# CLAUDE.md

Instructions for Claude Code working in this repository.

<!-- ─────────────────────────────────────────────────────────────────────
     FILL THIS IN when you start a real app. Everything below this block is
     already true of the template and needs no editing.
     ───────────────────────────────────────────────────────────────────── -->

## The app

**What it does:** _One sentence. The user-facing job, not the implementation._

**Who it's for:** _The specific person. "Guitarists who use alternate tunings", not "musicians"._

**Core action:** _The single thing a user opens the app to do. Everything else is secondary and
should be treated that way when scoping._

**Business model:** One-time non-consumable unlock (`StoreProduct.pro`). _Adjust if this changed._

**What's paid vs free:** _List it. Ambiguity here produces gates in the wrong places._

<!-- ───────────────────────── end of per-app section ───────────────────── -->

## Hard rules

**XcodeGen owns the project.** `project.yml` is the source of truth. The `.xcodeproj` is
generated and gitignored. Never hand-edit it — the change vanishes on the next `xcodegen
generate`, usually a day later, in a way that is confusing to diagnose. After changing
`project.yml`, run `xcodegen generate`.

**Never edit `main` directly once the app is live.** When a version is in App Store review or
shipped, `main` is the record of the binary users have. Develop on a branch and merge
deliberately.

**Adding a Swift file requires no project change.** Sources are folder globs. Just create the
file in the right folder.

**Do not add a dependency without being asked.** This app has zero third-party packages and that
is a feature. If one is genuinely needed, pin it with `exactVersion` (never `from:`) and say why
in the ADR log.

## Commands

```bash
xcodegen generate                       # after any project.yml change
swiftlint lint --strict Starter StarterTests    # what CI runs; must be clean
./scripts/screenshots.sh                # regenerate App Store captures
```

Build and test (the destination auto-selects a simulator, same as CI):

```bash
xcodebuild test -project Starter.xcodeproj -scheme Starter \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro"
```

## Architecture

Read `docs/architecture.md` for the reasoning. The operational rules:

- **`Core/` imports no SwiftUI.** Pure logic and models. This is what makes the test suite fast.
- **Dependencies point inward.** `Features/` → `Core`/`DesignSystem`/`Platform`. Never the reverse,
  and never `Features/A` → `Features/B`.
- **Views do not touch `ModelContext`.** Persistence logic goes in a store type (see
  `Core/ItemStore.swift`) so it can be tested against an in-memory container.
- **Shared state is constructed once in `App/`** and injected via `.environment(...)`. If you find
  yourself creating a second instance of something, that is a bug.
- **External services go behind a protocol with a mock.** See `EntitlementProvider`.

## Design

Use the tokens in `DesignSystem/Theme.swift`. Do not write raw numbers or colours in views:
`Spacing.l` not `16`, `.textSecondary` not `.gray`, `AppFont.headline` not `.system(size: 17)`.

Colours resolve to system colours so they adapt to dark mode and accessibility settings for free.
Fonts are built from Dynamic Type styles so the app scales with the user's text size.

New screens should handle empty, loading and error states. `DesignSystem/Components.swift` has all
three; use them rather than inventing per-screen variants.

## Testing

Swift Testing (`@Test`, `@Suite`, `#expect`), not XCTest.

Test pure logic and store types. Do not write tests that need a running simulator UI — they are
slow and flaky, and a suite that is slow stops being run. If something is only verifiable by hand
(audio, camera, a live purchase, iCloud sync), say so explicitly in the docs rather than writing a
test that appears to cover it.

SwiftData tests use an in-memory `ModelContainer` per test. See `StarterTests/ItemStoreTests.swift`.

## Things that will waste your time if you rediscover them

These were paid for once. Do not re-derive them.

- **Never pass code-signing flags to a simulator `xcodebuild test`.** `CODE_SIGNING_ALLOWED=NO`
  strips `_CodeSignature` and the test host crashes before the harness connects, surfacing as
  "Early unexpected exit". Without flags it signs ad-hoc as "Sign to Run Locally" and entitlements
  like iCloud and aps-environment do not break it.
- **`SKTestSession` cannot activate under headless `xcodebuild`** (`SKInternalErrorDomain Code=3`).
  An `.xctestplan` does not fix it. Test the pure entitlement decision in CI and exercise real
  purchase flows in the Xcode GUI or on a device.
- **`Package.resolved` lives in `<App>.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`**, not
  in `derivedDataPath/SourcePackages/`. Since the `.xcodeproj` is gitignored, it is not in the repo
  — which is exactly why dependencies are pinned with `exactVersion` in `project.yml`.
- **`workflow_dispatch` only registers on the repository's default branch.** If you ever freeze
  `main` and develop elsewhere, the Run workflow button silently disappears and the API 404s.
  `build-test.yml` also triggers on pushing a `ci/**` branch for that reason.
- **macOS CI runners bill at 10x on private repos.** That is why lint runs on Linux automatically
  and build+test is manual. Do not "simplify" the lint job onto macOS.
- **`@AppStorage` does not work outside a SwiftUI `View`.** It is a `DynamicProperty`; in a plain
  class it compiles and silently fails to update. Use `UserDefaults` directly (see `ReviewPrompt`).

## Before proposing that something is done

- `swiftlint --strict` clean and the test suite green
- No new compiler warnings
- If it touches purchases, persistence, or anything with an Apple ID behind it: say plainly what
  has been verified on a device and what has not. A green build proves neither.
