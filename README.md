# InfoMe

A native iOS/watchOS app for sharing a "digital business card" — your contact
info and social profiles — with **anyone, on any device**, via **QR code**,
**NFC tag**, or **text/AirDrop link**. Recipients see a beautiful Linktree-style
menu where they can save your info to Contacts or jump straight to your
socials — without installing anything.

This repo contains a complete, ready-to-open Xcode project (generated with
[XcodeGen](https://github.com/yonaskolb/XcodeGen)) plus all Swift source for:

- **InfoMe** — the main iOS app (build & manage your card, show your QR, write NFC tags, share links)
- **InfoMeClip** — an **App Clip** that renders the recipient-facing Linktree menu instantly, no install required
- **InfoMe Watch App** — a watchOS companion that shows your QR full-screen for "raise your wrist and scan"
- **InfoMeWidgets** — Lock Screen / Home Screen / **Control Center widgets** (the iOS 18 way to bind a one-tap action to the **Action Button**)
- **InfoMeWatchWidgets** — watch face **complications** for one-tap sharing from the wrist
- **InfoMeKit** — a shared Swift Package with the data model, QR/NFC/vCard/CloudKit code and the shared "Linktree" UI used by both the app and the App Clip
- **web-fallback** — a tiny static page so non-Apple devices that scan your QR/NFC still get a usable card

> ⚠️ This was authored in a Linux container without Xcode/macOS, so it can't be
> compiled or run here. Everything is real, idiomatic Swift/SwiftUI organized
> into a buildable Xcode project structure — open it on a Mac, run
> `xcodegen generate`, fix up signing/team IDs, and it builds & runs. See
> **"Getting it running"** below for the exact steps.

---

## 1. The plan — answers to your questions

### "Would it be best to run this as an App Clip?"

**Yes — but only for the *receiving* side, paired with Universal Links.**

- **You** (the card owner) use the full **InfoMe** app to build your card,
  generate your QR code, and write your NFC tag.
- **Recipients** scan your QR or tap your NFC tag, which opens a Universal
  Link like `https://infome.app/u/<shortCode>`. iOS resolves that link to the
  **InfoMeClip** App Clip — a ~tiny, instant-launch experience (no App Store
  visit, opens in ~1 second) that shows your Linktree menu: avatar, name,
  bio, **"Save to Contacts"** button, and a grid of social buttons that open
  each profile in its native app.
- If the recipient is on Android, an older iPhone, or anywhere App Clips
  can't load, the **same URL** falls back to a small responsive web page
  (`web-fallback/`) that renders the same card and offers a `.vcf` download —
  so "share with anyone, any device" is genuinely true.

This is exactly the architecture products like Popl/Linq/Dot use, and it's
the *only* way to give a stranger your full interactive card without asking
them to install an app first. A normal "share a link to the App Store" flow
adds friction that kills the "quick tap to follow" use case.

### "Can NFC be included alongside QR code display?"

**Yes**, with one important nuance worth understanding up front:

- iOS does **not** expose an API for two iPhones to exchange arbitrary data
  over NFC (no "Android Beam" equivalent for 3rd-party apps — that's reserved
  for system features like AirDrop and iOS 17's NameDrop).
- What **is** available via Core NFC is reading/writing standard NDEF tags.
  So "NFC sharing" here means: **InfoMe writes your share-link to a physical
  NFC tag** (a sticker on your phone case, a metal card, a wristband insert —
  cheap NTAG21x tags cost pennies). Anyone — iPhone or Android — taps their
  phone to the tag, the OS pops up "Open in Safari/InfoMe", and they land on
  the exact same Linktree menu as the QR path. No app, no friction, and it
  works for people who don't want to open a camera.
- The app includes a full **`NFCCardWriter`** (Core NFC `NFCTagReaderSession`)
  that writes a URI NDEF record to a blank tag, plus a reader mode so InfoMe
  can also *read* someone else's tag and show their card.

So QR and NFC are two doors into the *same* Linktree experience — show
whichever is more convenient (QR for screens/printed material, NFC for
physical objects you carry).

### "Can we add Apple Watch support?"

Yes — **InfoMe Watch App** is a true watchOS companion (not just a mirrored
view):

- Full-screen, high-contrast **QR view** sized for a 41/45/49mm display —
  raise your wrist, someone scans it, done.
- A simplified social-link list for "show them your @handle real quick".
- The card is synced from the iPhone via `WatchConnectivity` (and CloudKit,
  see below) so it works even with the phone in your pocket.

### "Quick, easy compilation added to watch faces for one-tap share?"

Yes — **InfoMeWatchWidgets** ships **WidgetKit complications**
(`.accessoryCircular`, `.accessoryRectangular`, `.accessoryCorner`,
`.accessoryInline`). The user adds it to any modern watch face via *"Edit
Watch Face → add complication → InfoMe"*. One tap launches straight into the
full-screen QR view — that's the "one tap share" you asked for.

### "Action Button support for iPhone and Apple Watch?"

There is **no public API to bind directly to the Action Button** — Apple
intentionally routes all of it through user-configurable layers. InfoMe
supports *both* of the layers Apple exposes, so the user can pick whichever
shows up in their Action Button settings:

1. **App Intents + Shortcuts** (`ShowMyCardIntent`, exposed via
   `InfoMeShortcutsProvider`) — works back to iOS 16/watchOS 9. The user goes
   to *Settings → Action Button → Shortcut* (iPhone 15 Pro/16) or *Watch
   Settings → Action Button → Shortcut* (Apple Watch Ultra) and picks **"Show
   My InfoMe Card"**. One press jumps straight to the QR/share screen — no
   unlocking, no navigating.
2. **Control Widgets** (`ShowCardControl`, iOS 18+/watchOS 11+) — the newer,
   even more direct mechanism: *Settings → Action Button → Controls* lets the
   user assign our control directly (same surface as Flashlight/Camera). We
   ship a `ControlWidget` so InfoMe shows up right alongside Apple's own
   controls.

Both are wired to the same `OpenCardIntent`, so whichever the user picks,
press → full-screen QR/share menu, instantly.

---

## 2. Architecture at a glance

```
                         ┌──────────────────────────┐
                         │        InfoMeKit         │  Swift Package — shared by every target
                         │  Models · Sharing · Sync │  (ContactCard, SocialLink, CardTheme,
                         │  Linktree UI components  │   QRCodeGenerator, NFCCardWriter,
                         └────────────┬─────────────┘   VCardExporter, CardCloudStore,
                                      │                  CardLinkCodec, LinktreeMenuView…)
        ┌───────────────┬────────────┼────────────────┬───────────────────┐
        │               │            │                │                   │
 ┌──────▼─────┐  ┌──────▼─────┐ ┌────▼─────┐  ┌────────▼────────┐ ┌────────▼────────┐
 │   InfoMe   │  │ InfoMeClip │ │ InfoMe   │  │  InfoMeWidgets  │ │ InfoMeWatchWidgets│
 │  (iOS app) │  │ (App Clip) │ │ Watch App│  │ (Lock Screen /  │ │  (complications)  │
 │            │  │            │ │(watchOS) │  │  Control Center)│ │                   │
 │ Edit card  │  │ Linktree   │ │ Big QR   │  │ Quick-share     │ │ One-tap → QR view │
 │ Show QR    │  │ menu only  │ │ view     │  │ widget +        │ │                   │
 │ Write NFC  │  │ "Save to   │ │ Socials  │  │ ControlWidget   │ │                   │
 │ Read NFC   │  │  Contacts" │ │ list     │  │ for Action Btn  │ │                   │
 │ Share sheet│  │ Social grid│ │          │  │                 │ │                   │
 └────────────┘  └────────────┘ └──────────┘  └─────────────────┘ └───────────────────┘
```

### Data flow for a "scan"

1. The owner edits their card in **InfoMe** → it's saved locally (App Group
   container, `CardStore`) and published to **CloudKit's public database**
   (`CardCloudStore`) under a short, random share code, e.g. `aB3xQ9`.
2. **InfoMe** renders a QR code of `https://infome.app/u/aB3xQ9` (styled per
   the chosen `CardTheme`) and/or writes that same URL to an NFC tag.
   *(No backend to run — CloudKit's public DB is free, scales, and is fully
   within the Apple ecosystem; this is the "best & easiest" choice. A fully
   offline mode is also included — see `CardLinkCodec` — which packs the
   whole card into the URL itself via zlib + base64url, for users who don't
   want to use iCloud at all.)*
3. A recipient scans/taps → Universal Link opens **InfoMeClip** (or the web
   fallback) → it fetches the card from CloudKit (or decodes it straight from
   the URL in offline mode) and renders `LinktreeMenuView`.
4. They tap **"Save to Contacts"** (`VCardExporter` builds a `CNContact` and
   presents the system `CNContactViewController`) or tap any social button to
   open that profile in its native app via deep link, falling back to the web
   profile URL.

### Why CloudKit instead of a custom server?

- It's **free** at this scale, requires **no infrastructure to run/maintain**,
  and keeps everything inside Apple's trusted ecosystem (good for the App
  Clip's tight size/permission budget).
- It lets the owner **edit their card later** without reprinting a QR code or
  rewriting an NFC tag — the short link stays constant; only the CloudKit
  record changes.
- The offline `CardLinkCodec` mode is kept as a fallback/alternative for users
  who decline iCloud — the card still works, it just can't be edited after
  the code is generated (the link *is* the data).

---

## 3. Project layout

```
InfoMe/
├── project.yml                     # XcodeGen spec — generates InfoMe.xcodeproj
├── Packages/InfoMeKit/             # Local Swift Package, shared by all targets
│   └── Sources/InfoMeKit/
│       ├── Models/                 # ContactCard, SocialLink, SocialPlatform, CardTheme
│       ├── Sharing/                # QRCodeGenerator, NFCCardWriter, VCardExporter, CardLinkCodec
│       ├── CloudSync/              # CardCloudStore (CloudKit), CardSyncCoordinator (WatchConnectivity)
│       ├── Persistence/            # CardStore (App Group–backed local storage)
│       └── Views/                  # LinktreeMenuView, QRCodeView, SocialBadge, ThemedBackground…
├── Sources/
│   ├── App/                        # Main iOS app
│   │   ├── Views/                  # RootView, EditCardView, ShareHubView, NFCExchangeView…
│   │   ├── AppIntents/             # OpenCardIntent, InfoMeShortcutsProvider
│   │   └── NFC/                    # NFCTagReadingCoordinator
│   ├── AppClip/                    # App Clip entry point + invocation-URL handling
│   ├── WatchApp/                   # watchOS companion
│   │   └── Views/                  # WatchQRView, WatchSocialListView
│   ├── Widgets/                    # iOS WidgetKit extension (Lock Screen + ControlWidget)
│   └── WatchWidgets/               # watchOS WidgetKit extension (complications)
├── Resources/                      # Info.plist / entitlements / asset catalogs per target
└── web-fallback/                   # Static page for non-Apple devices (index.html)
```

---

## 4. Getting it running (on a Mac, with Xcode 16+)

1. **Install XcodeGen** (`brew install xcodegen`) and generate the project:
   ```
   cd InfoMe
   xcodegen generate
   open InfoMe.xcodeproj
   ```
2. **Set your team & bundle ID prefix.** `project.yml` uses
   `com.example.infome` as a placeholder bundle ID prefix — change
   `BUNDLE_ID_PREFIX` (top of the file) to something you control, and set
   `DEVELOPMENT_TEAM` to your Apple Developer Team ID. XcodeGen will fan that
   out to all five targets and the App Clip/Widget extensions automatically.
3. **Enable capabilities** for the `InfoMe` target in *Signing & Capabilities*
   (the entitlements files in `Resources/*/*.entitlements` already declare
   these — you mainly need to turn the matching capability on in your
   Developer account / let Xcode manage provisioning):
   - **App Groups** — `group.com.example.infome` (shared between App, Clip,
     Watch App and both widget extensions for `CardStore`)
   - **iCloud → CloudKit** — container `iCloud.com.example.infome`
   - **Near Field Communication Tag Reading** — required for `NFCCardWriter`
     and tag reading; also add `NFCReaderUsageDescription` to `Info.plist`
     (already templated) and the `com.apple.developer.nfc.readersession.formats`
     entitlement (`NDEF`, `TAG`)
   - **Associated Domains** — `applinks:infome.app` and
     `appclips:infome.app` (this is what lets the Universal Link route to the
     App Clip; you'll need to host an `apple-app-site-association` file at
     `https://infome.app/.well-known/apple-app-site-association` — a sample is
     in `web-fallback/.well-known/`)
   - **App Clip** — create the *App Clip Experience* in App Store Connect that
     maps `https://infome.app/u/*` → the `InfoMeClip` target
4. **Wire up a domain.** Replace `infome.app` everywhere (it's centralized in
   `InfoMeKit/Sources/InfoMeKit/Models/CardLinkConfiguration.swift`) with a
   domain you own, and deploy `web-fallback/` (e.g. to Vercel/Netlify/GitHub
   Pages) plus the AASA file.
5. **Run** the `InfoMe` scheme on a device (Core NFC and App Clips need a real
   iPhone — the Simulator can't do either). Run the `InfoMe Watch App` scheme
   on a paired Apple Watch or its simulator for the watch UI; complications
   and the Action Button integration also require a device.
6. **Try the Action Button:** build & run once so the Shortcut/Control are
   registered, then on an iPhone 15 Pro/16/Apple Watch Ultra go to *Settings →
   Action Button* and pick **"Show My InfoMe Card"** under Shortcut, or our
   control under Controls.

---

## 5. Notable implementation details worth reading first

- **`ContactCard` / `SocialLink` / `SocialPlatform`** — the entire data model,
  `Codable` + `Identifiable`, with per-platform brand colors, SF Symbol
  fallbacks, and `profileURL(for:)` / `appDeepLink(for:)` so social buttons
  try the native app first and fall back to the web profile.
- **`CardLinkCodec`** — packs a `ContactCard` into a URL-safe string
  (`JSONEncoder` → zlib via `Compression` → base64url) for the fully-offline
  sharing mode, and unpacks it again. Keeps QR codes scannable (≈ version 8–12
  at typical card sizes) and comfortably under NDEF tag capacity.
- **`QRCodeGenerator` / `QRCodeView`** — `CIFilter.qrCodeGenerator` +
  `CIFilter.falseColor` rendered into a crisp, non-blurry `Image`, themed to
  match the card's gradient.
- **`NFCCardWriter`** — `NFCTagReaderSession` (ISO14443/15693/iso18092),
  queries `NFCNDEFTag` status and writes a `URI` NDEF payload; full
  delegate-based session lifecycle with user-facing alerts at each step
  (bring tag close / writing / success / move tag away).
- **`VCardExporter`** — builds a `CNMutableContact` (name, org, phones,
  emails, urls, social profiles, note, photo) and either serializes it to
  `.vcf` `Data` for sharing, or hands it to `CNContactViewController` so the
  recipient gets the native "Add to Contacts" sheet — no permissions needed on
  their side because *they're* the one adding *you*.
- **`CardCloudStore`** — thin `CKContainer.publicCloudDatabase` wrapper:
  `publish(_:)` upserts a `CKRecord` keyed by share code, `fetch(code:)`
  fetches it (used by both the App Clip and, for "scan someone else's code",
  the main app).
- **`LinktreeMenuView`** — the actual recipient-facing menu UI: animated
  gradient background from `CardTheme`, avatar, name/org, prominent **Save to
  Contacts** button, then a responsive grid of `SocialBadge`s. Lives in
  `InfoMeKit` so the App Clip and the "preview my card" screen in the main app
  render *exactly* the same thing.
- **`OpenCardIntent` / `InfoMeShortcutsProvider`** — `AppIntent` +
  `AppShortcutsProvider` that surface "Show My InfoMe Card" to Siri,
  Spotlight, Shortcuts, and the Action Button's *Shortcut* mode.
- **`ShowCardControl`** — `ControlWidget` (iOS 18/watchOS 11) for the Action
  Button's newer *Controls* mode and Control Center/Lock Screen.
- **watchOS complications** (`InfoMeWatchWidgets`) — `WidgetBundle` exposing
  `.accessoryCircular/.accessoryRectangular/.accessoryCorner/.accessoryInline`
  families, all opening straight to `WatchQRView`.

## 6. Suggested next steps once it's building

- Drop in real social-app URL schemes/brand colors you care about most (the
  `SocialPlatform` enum is intentionally easy to extend).
- Replace the placeholder `infome.app` domain and AASA file with your own.
- Add a proper onboarding flow (CloudKit account check, NFC capability check
  on older devices, contacts permission priming).
- Add analytics on the *App Clip* side only if you disclose it (App Clips
  have stricter privacy expectations — keep it to aggregate "card viewed"
  counters in CloudKit, no PII).
