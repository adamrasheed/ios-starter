# Decision log

Architecture decisions, with the reasoning that produced them. Append a new entry rather than
editing an old one — a superseded decision plus the reason it was superseded is more useful than a
decision that appears to have always been the current one.

Format: what was decided, what it rules out, and what would make it wrong.

---

## ADR-001 — SwiftUI only, iOS 17 minimum

**Decided:** SwiftUI for all UI. No UIKit except where there is no SwiftUI equivalent (haptics).
Minimum deployment target iOS 17.

**Why:** iOS 17 is the floor for `@Observable` and the modern SwiftData APIs, both of which remove
real boilerplate. Adoption of a given iOS version is high enough within a year or so of release
that supporting one further back mostly costs you code paths you never test.

**Rules out:** users on iOS 16 and earlier.

**Would be wrong if:** you are targeting a market with unusually old hardware (some enterprise and
education contexts), or you need a UIKit-only API on a screen central to the app.

---

## ADR-002 — XcodeGen, with the .xcodeproj gitignored

**Decided:** `project.yml` is the source of truth. The `.xcodeproj` is generated and not committed.

**Why:** the practical benefit is not tidiness, it is concurrency. Because `sources:` are folder
globs, adding a file never touches a shared project file, so several features can be built at once
in separate worktrees and merged with zero conflicts. On a hand-managed `.xcodeproj` every new file
mutates the same XML blob and that workflow is impossible. Project settings also become reviewable:
a build-setting change shows up as a readable line in a PR instead of a diff nobody can parse.

**Rules out:** hand-editing project settings in Xcode's UI. Anyone who does will lose their change
on the next generate.

**Consequence to know about:** `Package.resolved` lives inside the generated project, so it is not
in the repo. That is why ADR-003 exists.

**Would be wrong if:** you need a project structure XcodeGen cannot express, or you are handing the
repo to people who will not install a tool before opening it.

---

## ADR-003 — Pin dependencies with exactVersion, and prefer having none

**Decided:** zero third-party packages by default. Any package added is pinned with `exactVersion`,
never `from:`.

**Why:** with the `.xcodeproj` gitignored (ADR-002), `Package.resolved` is not committed and there
is nowhere clean to put it. `from: "1.2.0"` therefore resolves transiently on every fresh clone and
every CI run: an upstream release can change what gets built with no commit in this repo, and turn
a green build red for reasons that appear to come from nowhere. `exactVersion` makes taking an
update a deliberate, reviewable commit.

**Rules out:** automatic minor-version updates.

**Known limit:** this pins direct dependencies only. Transitive ones still resolve via their own
manifests, which is why `build-test.yml` logs the full resolved set.

---

## ADR-004 — StoreKit 2 directly, no RevenueCat

**Decided:** one non-consumable unlock, implemented against StoreKit 2. `isPro` derived from
`Transaction.currentEntitlements` with no stored flag.

**Why:** for a single non-consumable the whole implementation is about 120 lines, and
`currentEntitlements` already handles restores, Family Sharing, refunds and cross-device purchases
— the cases a hand-rolled receipt check gets wrong. RevenueCat earns its keep for subscriptions
with cross-platform entitlements, price experiments and churn analytics. None of that applies to a
one-time unlock, and it would put a vendor, an SDK and a monthly bill in the path of the app's
revenue.

**Rules out:** cross-platform entitlement sharing (an Android or web version honouring the iOS
purchase), and subscription analytics out of the box.

**Would be wrong if:** you move to subscriptions, ship on a second platform, or want to run pricing
experiments.

---

## ADR-005 — The paid boundary is a protocol with a mock

**Decided:** every feature gates on `Entitlements.isPro`. The implementation sits behind
`EntitlementProvider`, with a mock as the development default.

**Why:** it decouples building the paid half of the app from App Store Connect setup, the Paid
Applications Agreement and banking details — all slow, and none under your control. It also makes
the entitlement rules unit-testable, which they otherwise are not, since only StoreKit can mint a
`Transaction`.

**Consequence:** there is exactly one line in the app that decides real-vs-mock (`RootView.init`).
Guard it. Shipping with the mock provider gives every user Pro for free, and nothing in the build
or test process will tell you.

---

## ADR-006 — SwiftData local by default, CloudKit-compatible by construction

**Decided:** SwiftData with a local store. Every model property has a default value and no unique
constraints, so CloudKit mirroring can be enabled later without a migration.

**Why:** sync is a large, hard-to-verify feature, and most v1 apps do not need it. But the model
constraints CloudKit imposes are free to honour now and expensive to retrofit once users have data
on disk.

**If you enable it, know this:** a green build and a passing test suite prove nothing about whether
sync works. Specifically —

1. Container creation **silently falls back to a local store** on any entitlement mismatch. The
   `assertionFailure` guard that catches this in development is compiled out in Release, so an App
   Store build can fail to sync with zero visible symptoms.
2. Debug and Release need **different `aps-environment` entitlements** (development vs production).
   Ship the wrong one and sync fails only in the App Store build.
3. The CloudKit schema must be **deployed from Development to Production** in the CloudKit Console.
   This is a separate manual step in a web UI. Sync working in development says nothing about
   production.
4. Only a **real two-device test** confirms any of it.

Do not mark sync "done" on the strength of a build.

---

## ADR-007 — Swift Testing, and no UI tests

**Decided:** Swift Testing (`@Test`, `#expect`). No XCUITest target.

**Why:** new project, so no migration cost, and the ergonomics are better — parameterized tests,
readable names, structured suites. UI tests are excluded because they are slow and flaky enough
that teams stop running them, and a test suite that is not run is worse than none: it provides the
feeling of coverage without the fact.

**Consequence:** anything only verifiable through the UI or on hardware must be verified by hand.
Say so explicitly in the docs rather than writing a test that appears to cover it.

---

## ADR-008 — CI split by cost: lint automatic, build+test manual

**Decided:** SwiftLint runs on every PR in a Linux container. The macOS build+test job runs only
when triggered.

**Why:** on a private repo macOS runners bill at 10x. A measured cold build+test run on a
comparable app was 4.8 minutes wall clock and roughly 50 billed minutes — about four runs a month
on a Free plan. Lint on Linux at 1x catches the majority of mechanical problems for about twenty
seconds.

**Would be wrong if:** the repo is public (Actions minutes are free — make build+test automatic),
or you are on a paid plan where the minutes are not the binding constraint.

---

## ADR-009 — Analytics and logging behind protocols, no-op by default

**Decided:** `AnalyticsClient` protocol with a console implementation. `os.Logger` for logging.
No vendor SDK.

**Why:** an SDK sprinkled through 40 view files takes a week to remove, and vendors do get swapped.
More practically, analytics you never read is worse than none: it costs a dependency, a privacy
manifest entry and an App Store tracking disclosure in exchange for numbers nobody looks at.
Shipping v1 with the console client is a legitimate choice.

Events are a closed enum rather than free-form strings, because `"paywall_shown"` in one file and
`"paywall_show"` in another silently splits a funnel in two and you find out weeks later.

---

## ADR-010 — Review prompts are milestone-gated

**Decided:** ask only after the user has completed the core action several times, at least two days
after install, and at most once per app version.

**Why:** `requestReview` displays at most three times per user per year and the system silently
swallows the rest. Asking a first-session user spends a third of an annual budget on someone with
no opinion. The gate approximates "this person has got value out of the app".

**The rule this cannot enforce:** never ask after something went wrong. `recordMilestone()` must be
called on success paths only — that is a call-site discipline, not something the type can check.
