#!/usr/bin/env bash
#
# Turn this template into a real app.
#
#   ./scripts/rename.sh "MyApp" "com.yourcompany.myapp" [TEAM_ID]
#
# Renames the target, folders, scheme, StoreKit config and bundle identifiers, then regenerates
# the Xcode project. Run it once, immediately after generating from the template, before you
# write any code. It is a global find-and-replace, and it is far less pleasant once you have
# your own files using the word "Starter".
#
# It refuses to run twice, and it refuses to run on a dirty tree, so a bad invocation is always
# recoverable with `git checkout .`.
set -euo pipefail

cd "$(dirname "$0")/.."

NEW_NAME="${1:-}"
NEW_BUNDLE="${2:-}"
NEW_TEAM="${3:-}"

if [ -z "$NEW_NAME" ] || [ -z "$NEW_BUNDLE" ]; then
  cat <<'USAGE'
Usage: ./scripts/rename.sh <AppName> <bundle.identifier> [TeamID]

  AppName            Xcode target name. Letters and digits only, no spaces.
                     This is the code-level name; the user-facing display name
                     can differ and is set in App Store Connect.
  bundle.identifier  Reverse-DNS, e.g. com.yourcompany.myapp
  TeamID             Optional 10-character Apple Developer team id. Without it
                     you can build for the simulator but not for a device.

Example:
  ./scripts/rename.sh Pocketlist com.creatix.pocketlist 47SF35MKK7
USAGE
  exit 1
fi

if ! [[ "$NEW_NAME" =~ ^[A-Za-z][A-Za-z0-9]*$ ]]; then
  echo "error: AppName must start with a letter and contain only letters and digits (got '$NEW_NAME')." >&2
  echo "       Xcode target names with spaces or punctuation break the build in non-obvious ways." >&2
  exit 1
fi

if ! [[ "$NEW_BUNDLE" =~ ^[A-Za-z0-9.-]+$ ]] || [[ "$NEW_BUNDLE" != *.* ]]; then
  echo "error: bundle identifier must be reverse-DNS, e.g. com.yourcompany.myapp (got '$NEW_BUNDLE')." >&2
  exit 1
fi

if [ ! -d "Starter" ]; then
  echo "error: no Starter/ directory here. This script has already been run, or you are in the wrong folder." >&2
  exit 1
fi

if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  echo "error: working tree is dirty. Commit or stash first, so this is a single reviewable change" >&2
  echo "       you can undo with 'git checkout .' if it goes wrong." >&2
  exit 1
fi

echo "Renaming template → $NEW_NAME ($NEW_BUNDLE)"

# Move directories and files first, so the content pass below sees final paths.
git mv Starter "$NEW_NAME"
git mv StarterTests "${NEW_NAME}Tests"
git mv "$NEW_NAME/Features/Store/Starter.storekit" "$NEW_NAME/Features/Store/${NEW_NAME}.storekit"
git mv "$NEW_NAME/App/StarterApp.swift" "$NEW_NAME/App/${NEW_NAME}App.swift"

# Content pass. Order matters: replace the specific bundle id BEFORE the bare word "Starter",
# otherwise "com.example.starter" has already been half-rewritten and stops matching.
FILES=$(git ls-files | grep -E '\.(swift|yml|yaml|storekit|md|sh|json)$' || true)

for file in $FILES; do
  # macOS sed needs the empty -i argument; this script assumes macOS, as does Xcode.
  sed -i '' \
    -e "s|com\.example\.starter|${NEW_BUNDLE}|g" \
    -e "s|com\.example|$(echo "$NEW_BUNDLE" | cut -d. -f1-2)|g" \
    -e "s|Starter|${NEW_NAME}|g" \
    -e "s|starter|$(echo "$NEW_NAME" | tr '[:upper:]' '[:lower:]')|g" \
    "$file"
done

if [ -n "$NEW_TEAM" ]; then
  sed -i '' -e "s|DEVELOPMENT_TEAM: \"\"|DEVELOPMENT_TEAM: ${NEW_TEAM}|" project.yml
  sed -i '' -e "s|\"_developerTeamID\" : \"\"|\"_developerTeamID\" : \"${NEW_TEAM}\"|" "$NEW_NAME/Features/Store/${NEW_NAME}.storekit"
  echo "  set DEVELOPMENT_TEAM=$NEW_TEAM"
else
  echo "  note: no team id given. Simulator builds work; device builds and archives will not"
  echo "        until you set DEVELOPMENT_TEAM in project.yml."
fi

# This script renames itself out of relevance, so remove it rather than leave a loaded gun
# in the repo.
git rm -q --cached scripts/rename.sh >/dev/null 2>&1 || true
rm -f scripts/rename.sh

echo "Regenerating Xcode project"
xcodegen generate

cat <<NEXT

Done. ${NEW_NAME}.xcodeproj is ready.

Still to do by hand, in rough order:
  1. project.yml:      MARKETING_VERSION, and DEVELOPMENT_TEAM if you skipped it
  2. Assets.xcassets:  AccentColor (your brand colour) and a 1024pt AppIcon
  3. SettingsView:     the privacy and support URLs. Both must be LIVE before review
  4. PaywallView:      the perks list, in the user's words
  5. OnboardingView:   your three pages, or delete it and ship without onboarding
  6. Delete the example domain: ${NEW_NAME}/Core/ExampleItem.swift, ItemStore.swift,
     Features/Home/, and ${NEW_NAME}Tests/ItemStoreTests.swift
  7. CLAUDE.md:        fill in the app-specific sections at the top

Then:  xcodegen generate && open ${NEW_NAME}.xcodeproj
NEXT
