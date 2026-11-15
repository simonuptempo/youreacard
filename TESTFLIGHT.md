# Getting You're a Card onto your iPhone with TestFlight

You do this from your Mac. The first time takes about an hour (mostly Apple setup);
after that, a new test build takes about 10 minutes.

## One-time setup

1. **Apple Developer Program.** You need a paid membership ($99/year) at
   https://developer.apple.com/programs/. Note your **Team ID**: developer.apple.com → Account →
   Membership details (10 characters, like `AB12CD34EF`).
2. **Xcode.** Install it from the Mac App Store, open it once, and sign in:
   Xcode → Settings → Accounts → **+** → Apple ID.
3. **Godot's iPhone export templates.** In Godot: **Editor → Manage Export Templates →
   Download and Install** (must match Godot 4.7.1).
4. **Create the app in App Store Connect** (https://appstoreconnect.apple.com):
   **Apps → + → New App**
   - Platform: iOS
   - Name: `You're a Card` (if taken, try `You're a Card: Gem Heist`)
   - Bundle ID: `com.simonuptempo.youreacard` (if it isn't in the list, register it first at
     developer.apple.com → Certificates, IDs & Profiles → Identifiers → **+** → App IDs)
   - SKU: `youreacard`
5. **Put your Team ID into the project.** In Godot: **Project → Export… → iOS** (already set up in
   this repo) → **App Store Team ID** → paste it. Everything else is pre-filled: app ID,
   icon, version, and the camera / microphone / photo messages Apple requires.

## Each test build

1. **Bump the build number.** Project → Export… → iOS → **Version** (the build number):
   1, 2, 3… Every upload needs a higher number. (Short Version `0.5.0` can stay the same.)
2. **Export.** Click **Export Project**, keep the path `build/ios/YoureACard.ipa`, untick
   *Export With Debug*, and save. Because *Export Project Only* is on, Godot writes an
   **Xcode project** into `build/ios/` instead of a finished app.
3. **Open it in Xcode.** Double-click `build/ios/YoureACard.xcodeproj`.
4. **Signing.** Click the project in the left sidebar → the target → **Signing & Capabilities**
   → tick **Automatically manage signing** → choose your **Team**.
5. **Archive.** At the top, set the device to **Any iOS Device (arm64)**, then
   **Product → Archive**. When it finishes, the Organizer window opens.
6. **Upload.** **Distribute App → App Store Connect → Upload** → Next through the defaults.
7. **TestFlight.** In App Store Connect → your app → **TestFlight**. After the build finishes
   processing (10–30 minutes, you'll get an email), add yourself under **Internal Testing**.
   Install the **TestFlight** app on your iPhone and tap **Install**.

The export-compliance question is pre-answered (the app only uses standard HTTPS), so builds
go straight to testers.

## Friends and family
Internal testers must be on your App Store Connect team. For anyone else, add an
**External Testing** group with a public link; Apple does a quick beta review (usually under a
day) for the first external build.

## If something goes wrong
- *"No export template found"* → step 3 of setup.
- *"Bundle identifier is not available"* → someone else has it; change it in Godot's export
  settings and App Store Connect to e.g. `com.simonuptempo.youreacard.app`.
- *Signing errors in Xcode* → check you picked your Team in step 4 and that Xcode is signed in
  to your Apple ID.
- *"Redundant binary upload"* → bump the build number (step 1) and export again.
