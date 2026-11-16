# App Store compliance checklist (iOS)

What to enter in App Store Connect for OrcaNotes, and why. Laws and Apple rules change; re-check before each major release. This is not legal advice.

## Public URLs

| Field | Value |
|---|---|
| Privacy Policy URL (App Privacy, required) | https://github.com/Lameda12/OrcaNote/blob/main/PRIVACY.md |
| Support URL (version page, required) | https://github.com/Lameda12/OrcaNote/issues |
| Marketing URL (optional) | https://github.com/Lameda12/OrcaNote |
| License Agreement | Apple's Standard License Agreement (keep the default). Our [TERMS.md](../TERMS.md) is linked in the app. |

The same links are in the app under **Settings → Legal & support** (iOS) and in the menu bar popover footer (Mac).

## App Privacy ("nutrition label")

Answer **"No, we do not collect data from this app."**

Reasoning, per Apple's definition (data is "collected" when it is sent off the device in a way that the developer or its partners can access beyond serving the request in real time):

- Recordings, transcripts, notes and settings never leave the device by default.
- No analytics, crash SDKs, ads or tracking. `PrivacyInfo.xcprivacy` declares no tracking and no collected data types.
- Hugging Face model downloads send no user content.
- Groq is off by default and uses the user's own API key and account. The developer has no access. The Privacy Policy discloses it.

If you ever add analytics, crash reporting, accounts or a developer-run server, this answer must change before that release ships.

## Age rating

Answer **None** to every content question → rated 4+. Not "Made for Kids" (that would add Kids Category rules).

## EU Digital Services Act: trader status

Required before the app can be offered in the EU.

- **Not a trader**: a free app with no monetization, published as a hobby/open-source project. Nothing extra is shown publicly.
- **Trader**: if you sell it, add in-app purchases, or use it to promote a business. Apple then **publicly shows your address, phone and email** on the EU product page.

Pick what honestly matches your situation (Business → or the app's App Information page). If you later monetize, switch to trader first.

## Export compliance

Already answered in the build: `ITSAppUsesNonExemptEncryption = NO` (the app uses only Apple's standard HTTPS).

## Content rights

Answer **No** to "contains, shows or accesses third-party content" for the app's own content. The app downloads open models under their own licenses; these are shown in the app before download and listed in [TERMS.md](../TERMS.md).

## App Accessibility (accessibility nutrition labels)

Only claim features you have tested on a device with the main flows (record, notes, settings). Likely candidates after a quick check: **Dark Interface**, **Larger Text** (Dynamic Type), **VoiceOver**, **Sufficient Contrast**. Leave anything untested unchecked.

## App Review notes (paste into App Review Information)

> OrcaNotes works fully on-device. No sign-in required. To test: Record tab → tap the mic, speak, tap stop; a transcript and summary appear in Notes. Summaries use Apple Intelligence where available; Settings → Summaries also offers a downloadable open model (about 1 GB, needs a physical device). Groq is optional and needs the user's own key.

## Recording consent

The app reminds users in Meeting mode and in Settings to get consent before recording. TERMS.md makes the user responsible for following local recording laws (e.g. all-party-consent US states, EU/UK).

## Still open

- Governing law / developer country is not stated in TERMS.md. Add it once you decide where you operate.
- A contact email is optional; GitHub Issues is the current contact. Add an email to PRIVACY.md if you want one.
- Have a lawyer review PRIVACY.md and TERMS.md before monetizing or if the app grows large.
