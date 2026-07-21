# Architecture

How this app is put together, and why each choice was made. The "why" matters more than the
"what": you will change the what.

## The shape: functional core, imperative shell

Logic lives in plain Swift types with no framework imports. SwiftUI views, SwiftData contexts and
StoreKit calls form a thin shell around that core.

```
Core/          pure logic and models — no SwiftUI, no UIKit
DesignSystem/  tokens and shared components
Platform/      wrappers over system services (analytics, logging, haptics, errors)
Features/      one folder per feature; the SwiftUI layer
App/           @main, the tab shell, and the single place dependencies are constructed
```

**Dependencies point inward.** `Features/` may use `Core`, `DesignSystem` and `Platform`. Nothing
depends on `Features/`, and no feature depends on another feature. `App/` wires them together.

The payoff is concrete: the test suite for this template runs 16 tests in 42 milliseconds with no
simulator UI involved. That is not a vanity metric. A suite that runs in a blink gets run on every
save; a suite that takes two minutes gets run before releases, which is to say after the bug has
already been built on top of.

The corollary is a discipline: when a rule is hard to test, the usual cause is that it is tangled
with a framework type. Extract the decision, pass it plain values, test it, and let the shell do
the plumbing. `StoreKitEntitlementProvider.isProEntitled` is the worked example — only StoreKit can
mint a `Transaction`, so the rule takes a small local struct instead and becomes testable.

## State and injection

`@Observable` classes, `@State` at the root, `.environment(...)` downward. No TCA, no coordinators,
no DI container.

Everything shared is constructed in exactly one place (`StarterApp` and `RootView.init`). That rule
does two jobs: it makes it impossible for two screens to disagree about entitlement state, and it
means swapping any dependency for a mock is a one-line edit in one file.

This is deliberately the least machinery that works. Reach for something heavier when you can name
the specific problem it solves for you — not before.

## The paid boundary

`EntitlementProvider` is a protocol with two implementations: `MockEntitlementProvider` and
`StoreKitEntitlementProvider`. `Entitlements` is the `@Observable` wrapper every feature reads.

The sequencing this enables is the real value. You can build, demo and test every paid feature
against the mock while App Store Connect product setup, the Paid Applications Agreement and banking
details are still pending — none of which are fast, and all of which are outside your control. When
the real product exists, the integration is one line in `RootView.init`.

Three properties of the StoreKit implementation are worth preserving verbatim if you rewrite it:

- **`isPro` is derived from `Transaction.currentEntitlements` every time. There is no stored flag.**
  A local "hasPurchased" boolean is the classic bug here: it drifts from reality on refund,
  reinstall, and device switch, and each patch adds another way to be wrong. Deriving costs
  microseconds and is correct by construction, including for Family Sharing and purchases made on
  other devices.
- **A `Transaction.updates` listener starts at `init`.** Transactions arrive outside your purchase
  call — Ask-to-Buy approvals, refunds, other devices. Starting the listener at construction means
  one posted while the app was still launching is not dropped.
- **`restore()` distinguishes a cancelled auth prompt from a real failure.** Swallowing both means
  an offline owner is told "no purchase found", which tells a paying customer they never paid.

## Persistence

SwiftData, with mutation logic in store types rather than views. See `Core/ItemStore.swift`.

A view calls `store.add(...)`. A view does not touch `ModelContext`. SwiftData makes the second
option very easy, which is precisely the trap: it puts rules like "renumber the remaining items
after a delete" somewhere only a UI test can reach.

Models are written CloudKit-compatible from day one — every property has a default value, and there
are no unique constraints — even though sync is off. Both are hard requirements for CloudKit
mirroring, and adding a default to a shipped model means a migration rather than an edit. This
costs nothing now and buys the option later.

If you do enable sync, read ADR-006 first. The summary: a green build proves nothing about whether
sync works.

## Errors

One `ErrorPresenter` in the environment, one alert installed at the root.

Without it, error handling reliably decays into a mixture of `try?` (silent failure, the worst
outcome, because the user believes it worked), bespoke `@State var errorMessage` per view, and the
occasional `fatalError` that ships. `errors.attempt { }` is as short as `try?` at the call site, so
the honest option is also the convenient one — which is the only way a convention survives contact
with a deadline.

`CancellationError` is swallowed on purpose: a task cancelled because the user navigated away is
not a failure, and alerting on it is a false alarm users learn to dismiss without reading.

## Design system

Tokens in `DesignSystem/Theme.swift`, components in `Components.swift`. No raw numbers or colours
in views.

Colours resolve to **system** colours rather than hex literals. System colours adapt to light and
dark mode, to Increase Contrast and Reduce Transparency, and to whatever Apple changes next, for
free. A hardcoded `#1C1C1E` gives you a dark mode that is subtly wrong the first time a user turns
on an accessibility setting — and you will never see it, because you don't have it on.

Fonts are built from Dynamic Type styles for the same reason: `.system(size: 17)` freezes the app
at one size and makes it unusable for the substantial number of people who raise their text size.

The components cover empty, loading and error states. They exist because these are what apps
forget, and because the empty state is the first thing a brand-new user sees — an empty list that
renders as a blank screen reads as a bug at exactly the moment you can least afford it.

## CI

Two workflows, split on cost.

**`lint.yml`** runs automatically on every PR: SwiftLint, pinned version, in a Linux container.
Linux bills at 1x where macOS bills at 10x, and SwiftLint needs no Xcode, so this is an identical
result for a tenth of the price. `--strict` is safe only because `.swiftlint.yml` is tuned to the
tree; keep them together.

**`build-test.yml`** is manual: Actions button, `gh workflow run`, or pushing a `ci/**` branch. A
measured cold run on a comparable app was 4.8 minutes wall clock and about 50 billed minutes, which
on a Free plan is roughly four runs a month. On a **public** repo Actions minutes are free and you
can safely make this run on every PR.

The simulator destination is resolved at runtime by UDID off the newest installed iOS runtime.
Hardcoding `OS=26.5` breaks the moment an image refresh drops that runtime; a bare device name
leaves the choice to `xcodebuild`.

## Screenshots

The app poses itself from environment variables (`Support/DemoMode.swift`), so each App Store
capture is a repeatable command rather than a sequence of taps: seeded in-memory data, mocked Pro
state, onboarding skipped.

This turns "regenerate every screenshot after a copy change" from an afternoon into one command,
which is what makes it something you will actually redo when the app changes rather than shipping
last release's captures.

Demo mode is inert in production because nothing sets the variables. Confirm that before each
submission anyway: a demo mode a user can trigger is a rejection.

## What is deliberately not here

- **No third-party dependencies.** Every package is a supply-chain surface, a build-time cost and a
  future migration you carry forever. SwiftUI, SwiftData, StoreKit 2 and `os.Logger` cover this
  ground.
- **No networking layer.** Most apps need a different one, and a generic one you have to unpick is
  worse than none.
- **No RevenueCat.** It earns its keep for subscriptions with cross-platform entitlements and price
  experiments. For a single non-consumable, `Transaction.currentEntitlements` is about 120 lines
  with no vendor in the path.
- **No UI tests.** They are slow and flaky enough that they stop being run, and what they cover is
  usually better served by testing the logic underneath plus looking at the app.
- **No localization.** Adding it later is mechanical. Doing it before you have users in another
  language is speculative work.
