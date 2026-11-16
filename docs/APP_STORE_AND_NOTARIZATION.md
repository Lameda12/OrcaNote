# Mac App Store & Notarization Deployment Guide

This guide covers preparing, signing, and deploying **OrcaNotes** to both the **Mac App Store (TestFlight)** and direct **Notarized DMG distribution**.

---

## 1. Distribution Strategy: App Store vs Direct DMG

| Feature | Direct DMG (Recommended for v1) | Mac App Store (MAS) |
|---|---|---|
| **System Audio Capture** | Native `ScreenCaptureKit` with zero sandbox friction | Requires user screen recording prompt |
| **Review Time** | **Instant** (Notarization takes ~60 seconds via `notarytool`) | 24–72 hours Apple review |
| **Payment Gate** | Keep 100% of revenue (Stripe / LemonSqueezy $5 checkout) | 15–30% Apple commission |
| **Updates** | Direct download or Sparkle auto-updater | Mac App Store auto-updates |

---

## 2. Option A: Direct Notarized DMG Distribution (Fastest)

To distribute a pristine, double-clickable DMG that opens on any Mac without Gatekeeper warnings:

### Step 1: Create Apple Developer ID Certificate
1. Go to [developer.apple.com/account/resources/certificates](https://developer.apple.com/account/resources/certificates).
2. Create a **Developer ID Application** certificate and download to your Mac Keychain.

### Step 2: Create App-Specific Password for Notarization
1. Go to [appleid.apple.com](https://appleid.apple.com) → **Sign-In and Security** → **App-Specific Passwords**.
2. Generate a password (e.g. named `notarytool-orcanotes`).
3. Store in keychain:
```bash
xcrun notarytool store-credentials "AC_PASSWORD" \
  --apple-id "your-apple-id@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

### Step 3: Sign, Package, and Notarize
```bash
# 1. Sign app with Hardened Runtime & Entitlements
codesign --deep --force --options runtime \
  --entitlements OrcaNotes.entitlements \
  --sign "Developer ID Application: Your Name (TEAMID)" \
  build/OrcaNotes.app

# 2. Package into DMG
make dmg

# 3. Submit DMG to Apple Notary Service
xcrun notarytool submit build/OrcaNotes.dmg --keychain-profile "AC_PASSWORD" --wait

# 4. Staple the notarization ticket onto the DMG
xcrun stapler staple build/OrcaNotes.dmg
```
Now `build/OrcaNotes.dmg` opens on any Mac with zero Gatekeeper warnings!

---

## 3. Option B: Mac App Store & TestFlight Submission

### Step 1: Xcode Project or App Sandbox Archive
1. Open the project in Xcode (`xed .` or generate Xcode project via `swift package generate-xcodeproj`).
2. Set Bundle Identifier to `com.orcanotes.app`.
3. In **Signing & Capabilities**:
   - Select your Apple Developer Team.
   - Enable **App Sandbox**.
   - Under **Hardware**: Check **Audio Input** (Microphone).
   - Under **Network**: Check **Outgoing Connections (Client)**.

### Step 2: Archive & Upload to App Store Connect
1. In Xcode: **Product → Archive**.
2. In the Organizer window: Click **Distribute App → App Store Connect → Upload**.
3. Once uploaded, open [appstoreconnect.apple.com](https://appstoreconnect.apple.com):
   - Go to **TestFlight** tab → Add Internal & External beta testers.
   - Testers receive a TestFlight link to install OrcaNotes on their Mac with 1 click.
