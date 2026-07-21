# Ship checklist

Everything between "it works on my simulator" and "it is on the App Store."

A green CI build proves that the code compiles and the pure logic is correct. It proves nothing
about purchases, entitlements, sync, or whether the app is allowed on the store. Those are the
items below, and most of them can only be checked by hand.

## Before the first submission

### Identity

- [ ] `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` matches the App ID in the developer portal
- [ ] `DEVELOPMENT_TEAM` set
- [ ] `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` set
- [ ] App icon present at 1024pt. A missing icon fails upload, not review, and always later than
      you would like
- [ ] `AccentColor` is your brand colour, not the template's

### The things Apple rejects for

- [ ] **Restore Purchases is visible and works.** Mandatory for non-consumables and a routine
      rejection. It is in Settings and on the paywall by default. Confirm neither got removed
- [ ] **Privacy policy URL is live.** Must return a real page at review time. A 404 is a rejection
- [ ] **Support URL is live**
- [ ] Privacy nutrition labels filled in App Store Connect, and honest about what the app collects
- [ ] No placeholder copy anywhere a reviewer can reach: "Lorem ipsum", "example.com", "TODO"
- [ ] Demo mode cannot be triggered by a user. Confirm nothing sets `DEMO_MODE` in a release build
- [ ] If the app has accounts: a working demo account in App Store Connect review notes
- [ ] Any permission prompt has a usage string that says *why*, in user language. "This app needs
      camera access" is a rejection; "Scan a receipt to add it to your log" is not

### Purchases: device pass required

The simulator's local `.storekit` file is a simulation. It does not exercise Apple's real
purchase flow, and the failures it hides are the expensive ones.

- [ ] Product created in App Store Connect with an id that **exactly** matches `StoreProduct.pro`
      and the `.storekit` file. A mismatch means the paywall shows no price and the buy button
      does nothing, with no error anywhere
- [ ] Paid Applications Agreement signed and banking + tax details complete. Without this, products
      never load, no matter how correct the code is
- [ ] Buy the unlock on a **real device** with a **sandbox Apple ID**
- [ ] Delete and reinstall the app, tap Restore, confirm the unlock comes back
- [ ] Confirm the entitlement appears on a second device signed into the same Apple ID
- [ ] Confirm `RootView` injects `StoreKitEntitlementProvider`, not the mock. Shipping the mock
      gives every user Pro for free and nothing in the build or test process will tell you

### If iCloud sync is enabled

Read ADR-006 in the decision log first. All four of these are manual.

- [ ] Run on a device signed into iCloud and confirm the console shows no fallback to a local store
- [ ] Confirm data propagates device A → device B, and B → A
- [ ] Deploy the CloudKit schema from Development to **Production** in the CloudKit Console
- [ ] Confirm the Release build's entitlements carry `aps-environment: production`

### Quality

- [ ] `swiftlint --strict` clean
- [ ] Test suite green
- [ ] Run the macOS CI job once (`gh workflow run build-test.yml`) so the shipped commit has been
      built somewhere other than your machine
- [ ] Launch on a physical device and use the core flow start to finish
- [ ] Check the largest Dynamic Type size on the main screens. Text that truncates into
      unreadability is a common one-star complaint
- [ ] Check dark mode
- [ ] Airplane mode: does anything that fetches fail gracefully, or does it hang forever with a
      spinner?

## Listing

- [ ] Screenshots regenerated from the current build (`./scripts/screenshots.sh`), not last
      release's
- [ ] Name, subtitle and keyword field written deliberately. The keyword field is invisible to
      users and does most of the discovery work
- [ ] Description leads with what the user gets, not a feature list
- [ ] Age rating answered honestly
- [ ] Export compliance: `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption` is `NO` in `project.yml`,
      which is correct if you use only HTTPS. If you added your own encryption, this changes

The `appstore-listing` skill produces the metadata and framed screenshots.

## Release

- [ ] Version bumped and committed
- [ ] Tag the commit you actually shipped, so you can reproduce a user's bug against their build
- [ ] Archive and upload
- [ ] TestFlight it yourself first. Ad-hoc signing hides entitlement problems that only appear in a
      distribution build
- [ ] Submit
- [ ] After approval: `main` now represents a binary real people are running. Develop on branches

## After

- [ ] Confirm the live listing renders correctly on a device, not just in App Store Connect
- [ ] Buy the product once with a real account to confirm the production purchase path works
      end to end. Sandbox and production are different systems
- [ ] Watch crash reports for the first few days. The first 48 hours surface device and locale
      combinations you do not have
