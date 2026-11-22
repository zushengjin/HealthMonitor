# HealthMonitor

A personal, on-device iPhone app that reads heart rate, heart rate
variability, and sleep from Apple Health, compares them with your own
usual range, and lets you know when something stays off for a few days.
Numbers plus general context, never a diagnosis.

## What it does (v1)

- Reads resting heart rate, HRV (SDNN), heart rate, walking heart rate
  average, and sleep from HealthKit — nothing else.
- Builds a rolling 30-day median baseline per metric from the HealthKit
  history already on the phone, so alerts work from day one.
- Morning summary: Clear / Watch / Alert first, then sleep, resting HR,
  and HRV with raw numbers vs. your usual, plus a 30-day trend line per
  metric.
- Tiered alerts: a quiet in-app watch note on day one; a local
  notification if the deviation persists (a real alert needs two signals
  agreeing or one metric far outside its range).
- A log of past Watch/Alert days. Days with no Watch data are skipped
  and shown as "No data".
- Everything is on-device: SwiftData storage, no account, no server, no
  network calls, nothing leaves the phone.

Alert thresholds in `Models/AlertThresholds.swift` are marked DRAFT:
starting points to tune against your own last 3 months of data (see the
spec's build step 5).

## How to open it

Requires a Mac with Xcode 16 or later and an Apple ID.

1. Copy this `HealthMonitor` folder to the Mac.
2. Double-click `HealthMonitor.xcodeproj` to open it in Xcode.
3. In the project editor, select the HealthMonitor target, go to
   **Signing & Capabilities**, and pick your Apple ID team under
   **Team**. (Signing is required to run on a real iPhone; the HealthKit
   capability is already enabled in the entitlements file.)
4. Connect an iPhone (or pick a simulator — but HealthKit data on the
   simulator is empty, so the app is only meaningful on a real device
   with an Apple Watch paired).
5. Press Run (Cmd+R).

On first launch the app explains what it reads and asks for HealthKit
access. Health permissions are managed in the Health app, not in
Settings: Health app → profile picture → Apps → HealthMonitor.

## Running it without a paid developer account

A free Apple ID works: Xcode signs the app for 7 days at a time, then
you plug the phone in and run it again to re-sign. A paid Apple
Developer Program membership ($99/year) removes the 7-day limit.

## Building it without a Mac (Windows PC)

No Mac needed — the build runs free in the cloud and the install happens
from Windows:

1. Create a free GitHub account, make a repo, and upload this whole
   `HealthMonitor` folder as the repo root (it must contain
   `HealthMonitor.xcodeproj` at the top level).
2. The included workflow (`.github/workflows/ios.yml`) builds the app on
   GitHub's free macOS runner on every push to `main` (~10-15 minutes).
   When it finishes, download the `HealthMonitor-unsigned-ipa` artifact
   from the Actions tab — inside is `HealthMonitor-unsigned.ipa`.
3. On the Windows PC, install Sideloadly (free) and iTunes (for the USB
   driver). Plug in the iPhone, open Sideloadly, drag in the `.ipa`,
   enter your Apple ID, and press Start. Sideloadly signs it with your
   free Apple ID and installs it.
4. On the iPhone, trust the app: Settings → General → VPN & Device
   Management → your Apple ID → Trust. On iOS 16 or later, also turn on
   Settings → Privacy & Security → Developer Mode and restart when asked.
5. The app expires after 7 days — run Sideloadly again with the same
   file to renew it.

## Project layout

- `HealthMonitor/HealthMonitorApp.swift` — app entry, model container,
  background refresh registration, re-check on becoming active.
- `HealthMonitor/Models/` — `DailyMetrics` (one day of aggregates),
  `Baseline` (SwiftData: rolling medians), `DayStatusRecord` (SwiftData:
  the daily status log), `AlertThresholds` (DRAFT numbers).
- `HealthMonitor/Services/` — `HealthStore` (HealthKit reads),
  `BaselineEngine` (medians and per-metric deviation rules),
  `AlertEngine` (Watch vs. Alert, wording), `NotificationService`
  (local notifications only), `MorningCheckCoordinator` (the once-a-day
  check, on-open plus a morning background refresh).
- `HealthMonitor/Views/` — `ContentView`, `OnboardingView`,
  `MorningSummaryView`, `MetricRowView`, `TrendChartView`, `HistoryView`.
- `HealthMonitor/Info.plist` — HealthKit usage descriptions, background
  fetch mode, background task identifier.
- `HealthMonitor/HealthMonitor.entitlements` — HealthKit capability.

## What v1 deliberately does not do

No diagnosis, no named condition, no family alerts, no blood pressure /
weight / glucose / labs, no cloud, no trained model. See
`../v1-spec-draft.md` for the full spec and the recorded decisions.

## Note

This project was written on a Linux machine with no Mac or Xcode, so it
has not been compiled. Open it in Xcode on a Mac; the first build will
tell you if anything needs adjusting.
