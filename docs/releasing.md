# Releasing

Archiving, signing and uploading. None of this needs the Xcode GUI.

## Archive and upload from the command line

```sh
xcodebuild -project Starter.xcodeproj -scheme Starter -configuration Release \
  -destination "generic/platform=iOS" -archivePath /tmp/Starter.xcarchive \
  archive -allowProvisioningUpdates

xcodebuild -exportArchive -archivePath /tmp/Starter.xcarchive \
  -exportOptionsPlist docs/ExportOptions.plist -exportPath /tmp/Starter-export \
  -allowProvisioningUpdates
```

Set `<destination>` in `ExportOptions.plist` to `upload` instead of `export` to push straight to
App Store Connect rather than writing an IPA locally.

## The prerequisites look worse than they are

All three of these read as hard blockers on a first release and none of them is one.

**No API key and no app-specific password are needed.** Authentication comes from Xcode's stored
account session.

**No Apple Distribution certificate needs to exist on the machine.** That same session mints a
cloud-managed one on first use. A cloud-managed certificate **does not appear in
`security find-identity`**, so checking there reports absence when the signing will in fact
succeed. Do not go hunting for a certificate to create.

**The archive signs with Apple Development.** Expected, and not worth debugging: the export step
re-signs with Apple Distribution. Verify on the exported IPA rather than guessing:

```sh
codesign -dvvv Payload/Starter.app 2>&1 | grep Authority
# Authority=Apple Distribution: <Your Org> (<TEAMID>)
```

## Version numbers

Two independent numbers, and both fail at **upload** rather than at review, which is a slow way to
find out.

- **`MARKETING_VERSION`** must match the version record in App Store Connect. The scaffold ships
  `0.1`; an archive whose `CFBundleShortVersionString` disagrees with ASC is rejected on upload.
- **`CURRENT_PROJECT_VERSION`** must increase for every upload, including one that replaces a build
  you just rejected. It is the build number, independent of the marketing version, and it
  increments per upload rather than per release.

## App Store assets, and which one goes where

Three image slots, three different size rules, and they are **not interchangeable**. Uploading the
wrong one to the wrong slot is the mistake this section exists to prevent.

| Image | Where it goes | Size | Error if wrong |
|---|---|---|---|
| **IAP review screenshot** (required) | The in-app purchase's App Review Information | **1242x2688** | "The dimensions of one or more screenshots are wrong." That field validates against an older device size list that does **not** include 6.9-inch, so the 1320x2868 listing capture is rejected |
| **IAP promo image** (optional) | The in-app purchase, shown in offer-code redemption | **exactly 1024x1024** | "Your image must be 1024 x 1024 pixels." Anything non-square is rejected |
| **App screenshots** | The version page, 6.9-inch slot | **1320x2868** | The 6.5-inch and 6.7-inch slots inherit from the 6.9-inch one automatically. Do not generate three sets |

Downscale a 6.9-inch capture for the review screenshot with `sips`. The aspect ratio differs by
0.4%, which is not visible.

Recapture the IAP review screenshot from the build being submitted. It is what App Review looks at
when it inspects the purchase, and a stale one can show perks the build no longer sells.

Do not keep a rejected size next to the correct one "just in case". A folder holding both
`iap-review-screenshot.png` and `iap-review-1242x2688.png` guarantees someone grabs the wrong file
next release.

## Before any of this

Work through `docs/ship-checklist.md`. Archiving is the last step, not the first.
