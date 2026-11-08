# CutSzn — iOS Development Guide

> Source guide: `TR-20260930-格斗减重-操作指南.MD` (2026-09-30)
> Product line: combat-sport weight-cut navigator for the US market (high-school / college wrestling, BJJ, MMA, boxing).

## Executive Summary

CutSzn is a **weight-cut navigator** for combat athletes. It answers one question every morning — *"What should I weigh today, and what exactly do I do about it?"* — and it protects the athlete from unsafe cuts while doing so.

The product vision is deliberately narrow: **open the app → see one number → act**. 95% of sessions last under 30 seconds. Everything else (protocols, refuel timers, coach dashboards, AI) supports that single number.

**Target audience**: US high-school wrestlers (374,278 participants, NFHS 2024-25), NCAA wrestlers, BJJ practitioners (750k–1M), MMA and boxing athletes, plus their coaches.

**Key differentiators vs. every incumbent**:
1. **Safety compliance engine** — USG (urine specific gravity) logging tied to NFHS ≤ 1.025 / NCAA ≤ 1.020 limits. No competitor ships this.
2. **Three-tier traffic light with an emergency mode that refuses unsafe cuts** (>5% acute water cut is a hard no). Refusing the user is the trust anchor.
3. **48-hour post-weigh-in refuel engine** — hourly rehydration + glycogen plan, not a static PDF.
4. **Coach / team dashboard** via CloudKit CKShare (read-only projection for the coach).
5. **Free core** — the full glide path, full fight-week protocol, safety verdict, USG log and refuel timer are free forever. No weekly subscription wall.
6. **Hybrid AI**: Apple on-device Foundation Models (free, offline, unlimited) + GLM-5.3-Flash cloud vision/reasoning (quota-based) + BYO API key (any OpenAI-compatible provider, unlimited).
7. **Brand-native virality** — `#CutSzn` is already an organic community hashtag; the Made Weight share card is a 9:16 story asset.

## Competitive Analysis

| App | Strengths | Weaknesses | Our Advantage |
|-----|-----------|------------|---------------|
| **CutCoach** ($6.99/wk, $59.99 lifetime) | Personalized cut plans, hydration strategy, recipes, weight tracking, $20K/mo revenue proof | No USG monitoring, no post-cut recovery plan, no coach dashboard, weekly-billing complaints | Free full protocol + USG compliance + refuel engine + no weekly wall |
| **Makeweight** (free + Pro) | Morning glide path, fight-week protocol, AI corner coach, photo food logging | No team/coach side, no USG compliance, recovery is static text | Coach CKShare dashboard + dynamic hourly refuel + real safety gating |
| **Fighterr** (free + Pro) | Daily weigh-in projection, water loading, sauna timer, 8% rule | Thin feature set, no AI, no recovery plan | Full AI layer + refuel + team + USG |
| **FightCampWizard** (free + Pro) | Carb taper, water load, sodium manipulation, rehydration guidance | No weigh-in tracking loop, no AI, no team | Closed-loop daily check-in + recalibrating plan + coach view |

## ⚠️ Feature Inventory (MANDATORY)

### Primary Features

| # | Feature | User Operation Flow | Data Input | Processing | Data Output | Persistence | Acceptance Criteria |
|---|---------|--------------------|------------|------------|-------------|-------------|---------------------|
| 1 | **Onboarding — sport & weight class** | 1. First launch → 2. Tap sport (Wrestling NCAA / Wrestling NFHS / BJJ / MMA / Boxing) → 3. Tap weight class from bundled JSON → 4. Continue | Sport selection, gender, weight class | Resolve class to kg; load org rule set (USG limit, weekly cap, weigh-in format) | Selected class card + org rules badge | `Athlete` model (SwiftData) | All 4+ org class lists render; selection persists across relaunch |
| 2 | **Onboarding — body stats** | 1. Enter current weight → 2. Height, age, sex → 3. "Import from Health" one-tap reads latest weight | lbs or kg, height cm/in, age, sex, HealthKit weight | Convert to kg internally; compute BMI and Mifflin-St Jeor BMR | Prefilled stats + BMR/TDEE estimate | `Athlete` model | Unit toggle works; HealthKit import fills weight within 1 tap; values persist |
| 3 | **Onboarding — weigh-in date** | 1. Calendar picker → 2. Choose weigh-in date → 3. Continue | Date | Days-out calculation via `startOfDay`; weigh-in format (day-before vs 1–2h-before) from org JSON | "14 days to weigh-in" summary | `CutPlan` model | Date math correct across DST and month boundaries; past dates rejected |
| 4 | **Onboarding — traffic-light gate** | 1. App computes verdict → 2. Green: "Start" → 3. Yellow: hard rules list + "I understand" → 4. Red: block + alternatives (move up a class / postpone) | Current weight, target class, days out, org caps | `CutPlanEngine.evaluate()` → green / yellow(rules) / red(reason) | Full-screen verdict with rule list or refusal | `CutPlan.verdict` | Red verdict offers no start button; yellow requires explicit acknowledgment; green proceeds in 1 tap |
| 5 | **Today dashboard** | 1. Open app → 2. See one big number (today's target weight) → 3. See progress ring + one-sentence instruction → 4. See traffic-light banner | Latest morning weigh-in, glide path, date | `CutPlanEngine` recompute → delta vs target → on-track / ahead / behind | 96pt number, ring, one-line coach instruction, banner | Derived from `CutPlan` + `WeighIn` | Number matches glide path for today; instruction is never empty; renders correctly at largest Dynamic Type |
| 6 | **Morning weigh-in** | 1. Tap "Log weight" → 2. Number pad in lbs (kg toggle) → 3. Save → 4. Haptic success + verdict animation | Weight value, timestamp, source (manual/HealthKit) | Same-day dedup (first fasted morning value wins, later entries flagged reference-only); `planRecalibrate()` | "On track ✅ / 0.8 lbs ahead" animation; updated glide path | `WeighIn` + recalibrated `CutPlan` | Recalibration changes remaining-day targets; duplicate same-minute entries deduped |
| 7 | **Plan / glide path** | 1. Open Plan tab → 2. See day-by-day target curve → 3. Tap a day for its target + protocol | Glide path array | Swift Charts rendering; fat-phase linear segment + fight-week acute segment | Chart + selectable day targets | `CutPlan.glidePath` | Curve ends exactly at target weight on weigh-in day; recalibration shifts curve |
| 8 | **Daily protocol card** | 1. Today → 2. See water / sodium / carbs / fiber targets → 3. Tap a ring to check off | Planned targets from `ProtocolCurve`; check-ins | Compare actual vs target; mark complete | Three progress rings + checklist | `ProtocolDay` + check-ins | Targets match phase (water loading → taper → zero); check-ins persist per day |
| 9 | **Safety engine / traffic light** | 1. Continuous → 2. Banner color on Today and Plan → 3. Red blocks plan generation | Weight, target, days out, weekly loss history, USG values | 1.5%/week rule, 5% acute red line, USG > 1.030 forced warning | Green / Yellow / Red banner + rule text | `CutPlan.verdict` (recomputed daily) | Red line never unlockable by purchase; USG breach triggers hydration warning |
| 10 | **Fight week emergency mode** | 1. Enters final 48h → 2. Stage determined by gap → 3. Stage 1 (<2%): micro-adjust list → 4. Stage 2 (2–5%): sauna round timer with daily cap → 5. Stage 3 (>5%): refusal screen | Gap %, hours to weigh-in | Stage classification; sauna cap 30–45 min/day | Stage-specific screen; timer for stage 2; refusal for stage 3 | `CutPlan.emergencyStage` | Stage 3 shows no actionable protocol; sauna timer enforces hard cap |
| 11 | **USG compliance log** | 1. Fight week → 2. Enter test-strip value → 3. See pass/fail vs org limit → 4. History list | USG value (e.g. 1.018), timestamp | Compare to NFHS 1.025 / NCAA 1.020; >1.030 escalation | Pass/fail chip + hydration directive | `USGLog` | Correct color for values each side of the org limit; history sorted by date |
| 12 | **Refuel 48h timer** | 1. After weigh-in → 2. Refuel tab opens automatically → 3. Hourly steps with fluid/carb amounts → 4. Tap "Done" per step → 5. Live countdown to next step | Walk weight, weigh-in weight, weigh-in format | `RefuelEngine.build()` → 150% fluid replacement, 1–1.2 g/kg/h carbs | Hourly step cards + timer + "X% recovered" | `RefuelLog` | Steps differ for day-before vs same-day weigh-ins; timer survives backgrounding |
| 13 | **Corner Coach (AI Q&A)** | 1. Tap coach button → 2. Ask "Can I eat this?" / "I'm 1.1 kg over tonight" → 3. Get answer grounded in today's plan | Free-text question + plan context | `AIRouter`: Apple on-device → BYO key → GLM cloud quota → graceful upsell | Answer text with actionable numbers | Chat history (SwiftData) | Works offline via Apple AI when available; never dead-ends with an error |
| 14 | **Photo meal scan** | 1. Tap camera → 2. Shoot meal → 3. Receive itemized carbs/sodium/fiber/kcal + verdict → 4. "Add to today" | JPEG photo | GLM-5.3-Flash vision (or BYO vision model) → JSON items; USDA FoodData fallback | Item list + eat/avoid/portion verdict + totals | `MealLog` | Items returned within 20s; retry on dropped connection; totals add to protocol card |
| 15 | **Made Weight celebration** | 1. Log weigh-in at or under target → 2. Full-screen confetti + green check → 3. "Share" | Weigh-in value vs target | Detect target met; compose share card | Celebration screen + 9:16 share card PNG | `WeighIn.isMadeWeight` + generated image | Triggers only when at/under target; share sheet exports a correct-aspect image |
| 16 | **Season archive** | 1. Plan tab → 2. Season section → 3. List of past cuts with start/end weights, duration, made-weight result | Historical `CutPlan` + `WeighIn` | Aggregate per season | Archive list + comparison chip ("last cut: 12 lbs in 21 days") | SwiftData | Past cuts survive app restart; next cut prefills from history |
| 17 | **Coach / team dashboard** | 1. Athlete taps "Share with coach" → 2. CKShare invite sheet → 3. Coach opens read-only dashboard: roster, glide status, traffic lights, USG report | CKShare participation | CloudKit share read-only projection | Roster rows + red/yellow flags + compliance report | CloudKit private DB (optional) | Share creation succeeds; coach sees read-only data; revoke works |
| 18 | **Lock-screen / home widget** | 1. Auto after first weigh-in → 2. Lock screen inline widget "Tomorrow: 129.4 lbs" → 3. Tap opens app | App Group shared snapshot | Widget reads snapshot written by app | Inline + rectangular widget | App Group `UserDefaults` / shared container | Snapshot refreshes on every weigh-in; widget never shows stale >24h data unmarked |
| 19 | **Notifications** | 1. Onboarding permission prompt → 2. Daily 21:00 "Tomorrow's number" → 3. USG reminder during fight week | Notification settings | Local notification scheduling | Lock-screen reminder | `UNUserNotificationCenter` | 21:00 reminder includes tomorrow's target; can be disabled in Settings |
| 20 | **Settings** | 1. Tab/gear → 2. Units lbs/kg, iCloud sync, AI provider config, notifications, disclaimers, support | User prefs, BYO provider/baseURL/key/model, vision toggle | Keychain for API key; units affect display only | Toggles + form | `UserDefaults` + Keychain | Unit toggle re-renders all weights; API key never leaves Keychain |
| 21 | **Paywall & purchases** | 1. Trigger from locked feature → 2. See Free / Monthly / Yearly / Single-Cut Pass / BYO Lifetime / Coach | Product selection | StoreKit 2 purchase + entitlement refresh | Entitlement state + unlocked UI | StoreKit transactions (`CutSzn.storekit`) | Restore works; yearly shows 7-day trial; entitlements gate only Pro features |
| 22 | **Contact support** | 1. Settings → 2. Support → 3. Choose topic tile, write message → 4. Send | Topic, message, email | POST to feedback backend | Success / error feedback | Remote backend (no PII stored locally) | Message delivers to `https://msg.calcs.top`; failure shows retry |

### Sub-Features & Detail Interactions

| # | Parent | Sub-Feature | Detail Description | Interaction Pattern |
|---|--------|-------------|--------------------|---------------------|
| 1.1 | Onboarding | Sport segmented picker | 5 sports, weight class list swaps per sport | Tap |
| 1.2 | Onboarding | Gender toggle | NFHS has girls classes; NCAA men/women | Tap |
| 2.1 | Body stats | Unit toggle | lbs default for US market, kg available | Tap |
| 2.2 | Body stats | HealthKit import | One tap pulls latest body mass sample | Tap → permission sheet |
| 3.1 | Weigh-in date | Calendar | Native date picker; disallows past dates | Tap |
| 4.1 | Verdict gate | Yellow acknowledgment | Cannot proceed without checking "I will follow the hard rules" | Toggle |
| 5.1 | Today | One-sentence instruction | Always specific + actionable, never shaming | Static text |
| 6.1 | Weigh-in | Same-day dedup | First fasted morning entry is authoritative; later entries marked "reference" | Automatic |
| 6.2 | Weigh-in | Haptic | `UINotificationFeedbackGenerator.success` on save | Haptic |
| 8.1 | Protocol | Ring tap | Tap ring → sheet with remaining amount + log | Tap |
| 10.1 | Emergency | Sauna timer | 10–15 min round, cooling interval, daily total cap | Start/stop timer |
| 12.1 | Refuel | Background timer | Continues via local notification while app backgrounded | Background |
| 13.1 | Coach | Suggested prompts | "Can I eat this?", "I'm over tonight", "Explain my sodium target" | Tap chips |
| 14.1 | Meal scan | Retry queue | Failed upload auto-retries once, then queue | Automatic |
| 15.1 | Share card | Export | 9:16 PNG for IG Story / TikTok | Share sheet |
| 17.1 | Team | Read-only projection | Coach cannot edit athlete data | CloudKit permission |
| 19.1 | Notifications | Quiet hours | No notification 22:00–07:00 except fight-week USG | Automatic |
| 21.1 | Paywall | Legal links | Privacy + Terms always tappable | Tap |

### Cross-Feature Dependencies

| Dependency | Source | Target | Data Passed | Trigger |
|------------|--------|--------|-------------|---------|
| Weigh-in → Today number | Morning weigh-in | Today dashboard | New weight → recalibrated glide path | Every save |
| Weigh-in → Plan curve | Morning weigh-in | Plan chart | Recalibration anchors curve at actual weight | Every save |
| Protocol targets → Today rings | ProtocolCurve | Today card | Daily water/sodium/carb/fiber values | Daily recompute |
| USG → Safety verdict | USG log | Traffic light | USG > limit escalates warning | Every USG save |
| Weigh-in at target → Celebration | Weigh-in | Made Weight screen | `isMadeWeight` flag + cut stats | Save crossing target |
| Weigh-in → Refuel engine | Weigh-in | Refuel tab | Walk weight + weigh-in weight + format | Weigh-in day |
| Meal scan → Protocol totals | MealLog | Today card | Carbs/sodium/fiber totals | Every meal save |
| Plan → Widget snapshot | CutPlan | Widget | Tomorrow's target + unit | Every recompute |
| Plan → Coach dashboard | CutPlan + WeighIn + USGLog | CKShare projection | Read-only snapshot | Every recompute (debounced) |
| Purchase → Feature gates | StoreKit entitlement | AI quotas, unlimited cuts, team, widget themes | Entitlement level | Purchase / restore |

## Apple Design Guidelines Compliance

- **Navigation**: three tabs only (Today / Plan / Team). No nested tab mazes.
- **Typography**: Dynamic Type fully supported; the hero number uses `rounded`/monospaced digits and scales.
- **Dark-first palette** with light-mode parity; contrast ratios ≥ 4.5:1.
- **Haptics**: success on weigh-in save, warning on red verdict.
- **Accessibility**: VoiceOver labels on every ring, chart summary via `AXChartDescriptor`, no color-only state (traffic light always pairs icon + text).
- **Privacy**: HealthKit read limited to body mass; no health data used for advertising; Privacy Manifest declares HealthKit + camera + photo usage.
- **Safety copy**: "Not medical advice. Cutting weight carries real risks." on onboarding, red verdict, paywall, and Settings.
- **Monetization**: Guideline 3.1.2(c) — paywall shows title, length, price, restore, Privacy and Terms links; no external purchase links.

## Technical Architecture

- **Language**: Swift 5.9+ (Swift 6 language mode ready)
- **UI**: SwiftUI (primary), WidgetKit, Swift Charts
- **Data**: SwiftData (local-first), optional CloudKit private DB (`cloudKitDatabase: .automatic`), App Group for widget snapshot
- **Health**: HealthKit body mass read/write
- **Purchases**: StoreKit 2 + local `.storekit` configuration for simulator; RevenueCat-style entitlement abstraction implemented natively (no third-party SDK required for the MVP)
- **AI**: Apple Foundation Models (`FoundationModels`, iOS 26+, availability-gated) → BYO OpenAI-compatible key (Keychain) → GLM cloud via Cloudflare proxy → deterministic local fallback
- **Networking**: URLSession only
- **Bundle ID**: `com.zzoutuo.CutSzn` (skill preset; any guide-suggested identifier is overridden)
- **Deployment target**: iOS 17.0 (AI features availability-gated)
- **Signing**: `DEVELOPMENT_TEAM` = `JP4TN5PTS3` at project level

## Module Structure

```
CutSzn/
├── App/
│   ├── CutSznApp.swift
│   └── AppEnvironment.swift
├── Models/
│   ├── Athlete.swift
│   ├── CutPlan.swift
│   ├── WeighIn.swift
│   ├── USGLog.swift
│   ├── MealLog.swift
│   ├── ProtocolDay.swift
│   ├── RefuelLog.swift
│   └── WeightClassModels.swift
├── Engines/
│   ├── CutPlanEngine.swift
│   ├── ProtocolCurve.swift
│   ├── SafetyEngine.swift
│   ├── RefuelEngine.swift
│   └── UnitConversion.swift
├── Services/
│   ├── HealthKitService.swift
│   ├── NotificationService.swift
│   ├── PurchaseService.swift
│   ├── CloudShareService.swift
│   ├── WidgetSnapshotService.swift
│   ├── FeedbackService.swift
│   ├── AI/
│   │   ├── AIRouter.swift
│   │   ├── AppleFoundationService.swift
│   │   ├── OpenAICompatClient.swift
│   │   ├── BYOSettings.swift
│   │   └── AITask.swift
│   └── FoodDatabase.swift
├── Views/
│   ├── Onboarding/
│   │   ├── SportClassView.swift
│   │   ├── BodyStatsView.swift
│   │   ├── WeighInDateView.swift
│   │   └── VerdictGateView.swift
│   ├── Today/
│   │   ├── TodayView.swift
│   │   ├── WeighInSheet.swift
│   │   └── ProtocolCardView.swift
│   ├── Plan/
│   │   ├── PlanView.swift
│   │   ├── GlidePathChart.swift
│   │   ├── EmergencyModeView.swift
│   │   ├── USGLogView.swift
│   │   └── SeasonArchiveView.swift
│   ├── Refuel/
│   │   └── RefuelView.swift
│   ├── Coach/
│   │   ├── CoachChatView.swift
│   │   └── MealScanView.swift
│   ├── Team/
│   │   └── TeamDashboardView.swift
│   ├── Share/
│   │   └── MadeWeightShareView.swift
│   ├── Purchase/
│   │   └── PaywallView.swift
│   └── Settings/
│       ├── SettingsView.swift
│       ├── AIProviderSettingsView.swift
│       └── ContactSupportView.swift
├── Resources/
│   ├── WeightClasses.json
│   └── Assets.xcassets
└── CutSznWidget/
    └── CutSznWidget.swift
```

## ⚠️ Data Flow Diagram (MANDATORY)

```
Feature: Morning weigh-in → Today number → Plan recalibration
┌──────────────────────────────────────────────────────────────┐
│  Input                                                       │
│  └── Manual number pad (lbs/kg) or HealthKit body mass       │
│       │                                                      │
│  Processing                                                  │
│  └── UnitConversion → kg (3 decimals)                        │
│      same-day dedup → first fasted value authoritative       │
│      CutPlanEngine.recalibrate(actualWeight)                 │
│       │                                                      │
│  Persistence                                                 │
│  └── WeighIn (SwiftData) + CutPlan.glidePath replaced        │
│       │                                                      │
│  Output                                                      │
│  └── Today: big number / ring / one-line instruction         │
│      Plan: shifted curve                                     │
│      Widget: tomorrow snapshot (App Group)                   │
│      Team: CKShare projection (debounced)                    │
└──────────────────────────────────────────────────────────────┘

Feature: Protocol targets → daily rings → meal scan totals
┌──────────────────────────────────────────────────────────────┐
│  ProtocolCurve.build(daysOut) → water / sodium / carbs / fiber│
│       │                                                      │
│  Today card renders 4 rings; tap ring → log intake           │
│       │                                                      │
│  Meal scan (GLM/BYO vision) → MealLog {carbs, sodium, fiber} │
│       │                                                      │
│  Rings subtract logged amounts → remaining shown             │
└──────────────────────────────────────────────────────────────┘

Feature: USG log → safety state → emergency stage
┌──────────────────────────────────────────────────────────────┐
│  USG value input → compare org limit                         │
│       │                                                      │
│  > limit → hydration directive; > 1.030 → forced warning     │
│       │                                                      │
│  SafetyEngine merges (weight gap %, USG, weekly loss)        │
│       │                                                      │
│  Today banner color + EmergencyModeView stage 1/2/3          │
└──────────────────────────────────────────────────────────────┘

Feature: Weigh-in at target → celebration → share card
┌──────────────────────────────────────────────────────────────┐
│  WeighIn.isMadeWeight = weight ≤ target                      │
│       │                                                      │
│  Full-screen celebration + haptic                            │
│       │                                                      │
│  ShareCardRenderer → 9:16 PNG (cut curve + stats + #CutSzn)  │
│       │                                                      │
│  UIActivityViewController → IG Story / TikTok                │
└──────────────────────────────────────────────────────────────┘

Feature: Corner Coach routing
┌──────────────────────────────────────────────────────────────┐
│  Question + plan context                                     │
│       │                                                      │
│  AIRouter: Apple on-device (quick verdict)                   │
│      → BYO key (unlimited)                                   │
│      → GLM cloud quota                                       │
│      → local deterministic fallback (never dead-end)         │
└──────────────────────────────────────────────────────────────┘
```

## Implementation Flow

1. Create Xcode project via xcodegen (`project.yml`): `CutSzn` app target + `CutSznWidget` extension + App Group `group.com.zzoutuo.CutSzn`.
2. Bundle `WeightClasses.json` with NCAA / NFHS / IBJJF / UWW / UFC / boxing classes and org rules.
3. Implement models with SwiftData-safe defaults (all attributes defaulted, relationships optional, no `#Unique`).
4. Implement the four engines as pure value types with unit tests (CutPlanEngine, ProtocolCurve, SafetyEngine, RefuelEngine).
5. Build Onboarding (4 screens) with verdict gate.
6. Build Today + weigh-in sheet + protocol card.
7. Build Plan (chart, emergency mode, USG log, season archive).
8. Build Refuel timer.
9. Build AI layer (AIRouter, Apple Foundation service, OpenAI-compatible client, BYO settings with Keychain).
10. Build Team dashboard with CKShare service.
11. Build widget + snapshot service + notifications.
12. Build paywall + purchase service + `CutSzn.storekit`.
13. Build Settings + Contact Support.
14. Build verification on iPhone and iPad simulators.

## UI/UX Design Specifications

- **Style**: native SwiftUI, US 2026 mainstream — dark-first, oversized numerals, zero chrome.
- **Colors**: electric green `#00E676` (brand / on-track), near-black `#0A0A0B` background, card `#141416`, amber `#FFB300`, red `#FF3B30`, secondary text `#9A9AA0`.
- **Radii**: 20pt cards, 999pt pills.
- **Typography**: SF Pro Display for the hero number (96pt, `.rounded`, monospaced digit), SF Pro Text elsewhere; Dynamic Type through AX5.
- **Layout**: 20pt horizontal insets; Today = hero block (60%) + protocol card + banner; no more than 3 tabs.
- **Motion**: spring 0.35 for ring fill; confetti burst on Made Weight; subtle scan line on meal scan.
- **Share card**: 1080×1920 (9:16), dark base, big green check, cut curve, event name, `#CutSzn` watermark bottom-right.
- **Disclaimers**: persistent footer microcopy on Today, red verdict, paywall, Settings.

## Code Generation Rules

- One feature per module; high cohesion, low coupling.
- All weights stored in kg (`Double`), formatted at the view layer.
- All dates normalized with `Calendar.startOfDay`.
- Safety red lines are hard-coded and never gated by entitlement.
- No free-generation counters anywhere in the AI layer.
- `canUseCloudAI = entitlement.isPro && quota > 0` — quota only for GLM cloud; Apple on-device and BYO key are unlimited.
- Version read from `Bundle.main.infoDictionary` — never hardcoded.
- No comments unless the logic is non-obvious.
- No third-party SDKs; native frameworks only.

## App Store Compliance Notes

- **Age rating**: 12+ (medical/treatment information, infrequent). The guide's "16+" is a Korea-style tier; App Store uses 12+/17+, so 12+ is the correct mapping — recorded in `capabilities.md`.
- **Health disclaimer** shown in onboarding, red verdict, paywall, Settings.
- **Privacy nutrition label**: Health & Fitness data (weight) collected on-device only; no tracking; no third-party advertising.
- **AI compliance**: Apple on-device AI works out of the box on supported devices; BYO key is optional; paywall leads with app features (not "unlimited AI"); no dead code generation counters.
- **No medical claims**: the app gives protocol guidance, never diagnosis.

## Build & Deployment Checklist

- [ ] `xcodegen generate` succeeds
- [ ] Build green on iPhone (iOS 18.x) and iPad simulator
- [ ] App Group + HealthKit + CloudKit entitlements present in `CutSzn.entitlements`
- [ ] `PrivacyInfo.xcprivacy` declares HealthKit, camera, photo library, file timestamp APIs
- [ ] Widget target builds and shows snapshot
- [ ] StoreKit configuration loads in simulator
- [ ] Contact support posts to `https://msg.calcs.top`
- [ ] GitHub repo pushed (source + `docs/` policies)
- [ ] Policy pages live on GitHub Pages
- [ ] `keytext.md` generated (not pushed)
- [ ] Final audit verdict = READY
