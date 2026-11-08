# Pricing Configuration

## Monetization Model: Subscription (IAP) + One-Time Purchases

Free core forever (glide path, fight-week protocol, safety engine, USG log, refuel timer), auto-renewable Pro subscriptions for cloud AI quotas and unlimited plans, a 30-day Single-Cut Pass for event-driven buyers, and a one-time BYO Lifetime unlock for users who bring their own API key.

## Subscription Group
- **Group Name**: CutSzn Pro
- **Reference Name**: CutSzn Pro
- **Products in group**: `com.zzoutuo.CutSzn.pro.monthly`, `com.zzoutuo.CutSzn.pro.yearly`
- **Second group**: CutSzn Coach — `com.zzoutuo.CutSzn.coach.yearly` (B2B team tier, kept separate so athletes and coaches cannot cross-grade)

## Subscription Tiers (Auto-Renewable)

### 1. Monthly Subscription
- **Reference Name**: CutSzn Pro Monthly
- **Product ID**: `com.zzoutuo.CutSzn.pro.monthly`
- **Type**: Auto-renewable subscription
- **Price**: $9.99 USD per month
- **Display Name**: `Pro Monthly` (11 chars, ≤35 ✅)
- **Description**: `Unlimited plans, cloud AI coach and meal scans.` (48 chars, ≤55 ✅)
- **Localization**: English (US)
- **Subscription Group**: CutSzn Pro
- **Restore Purchases**: ✅ Required

### 2. Yearly Subscription
- **Reference Name**: CutSzn Pro Annual
- **Product ID**: `com.zzoutuo.CutSzn.pro.yearly`
- **Type**: Auto-renewable subscription
- **Price**: $49.99 USD per year (58% savings vs monthly)
- **Display Name**: `Pro Yearly` (10 chars, ≤35 ✅)
- **Description**: `Best value. Full Pro access plus a 7-day free trial.` (54 chars, ≤55 ✅)
- **Localization**: English (US)
- **Subscription Group**: CutSzn Pro (same group as monthly)
- **Restore Purchases**: ✅ Required

### 3. Coach Team Subscription
- **Reference Name**: CutSzn Coach Annual
- **Product ID**: `com.zzoutuo.CutSzn.coach.yearly`
- **Type**: Auto-renewable subscription
- **Price**: $99.99 USD per year
- **Display Name**: `Coach Team Yearly` (17 chars, ≤35 ✅)
- **Description**: `Team dashboard and compliance reports for 30 athletes.` (51 chars, ≤55 ✅)
- **Localization**: English (US)
- **Subscription Group**: CutSzn Coach
- **Restore Purchases**: ✅ Required

## One-Time Purchases (Non-Consumable)

### 1. Pro BYO Lifetime
- **Reference Name**: CutSzn Pro BYO Lifetime
- **Product ID**: `com.zzoutuo.CutSzn.pro.byo.lifetime`
- **Type**: Non-consumable (one-time purchase, permanently unlocked)
- **Price**: $34.99 USD (one-time)
- **Display Name**: `Pro BYO Lifetime` (16 chars, ≤35 ✅)
- **Description**: `Own Pro forever. Your own AI key, unlimited.` (42 chars, ≤55 ✅)
- **Localization**: English (US)
- **Restore Purchases**: ✅ Required
- **Differentiation Note**: One-time unlock of every non-cloud Pro feature, plus unlimited AI through the user's own OpenAI-compatible key. Cloud GLM quota is NOT included — cloud quota requires a subscription or a Single-Cut Pass.

### 2. Single-Cut Pass
- **Reference Name**: CutSzn Single-Cut Pass
- **Product ID**: `com.zzoutuo.CutSzn.singlecut.pass`
- **Type**: Non-renewing subscription (30 days, manual renewal, no auto-charge)
- **Price**: $14.99 USD per 30 days
- **Display Name**: `Single-Cut Pass` (15 chars, ≤35 ✅)
- **Description**: `30 days of Pro: 100 meal scans, 200 coach replies.` (51 chars, ≤55 ✅)
- **Localization**: English (US)
- **Restore Purchases**: ✅ Required (restores the active 30-day window only)
- **Differentiation Note**: Time-boxed event pass. Includes cloud quotas, but expires after 30 days and never auto-renews. Does NOT unlock the permanent BYO Lifetime features after expiry.

## Free Tier (Default)

- **Price**: Free
- **Features**:
  - Full morning glide path and daily target number
  - Full fight-week protocol (water, sodium, carbs, fiber)
  - Morning weigh-in logging (manual + HealthKit)
  - Traffic-light safety verdict and emergency mode stages
  - USG compliance logging (NFHS ≤1.025 / NCAA ≤1.020)
  - 48-hour Refuel hourly timer
  - Apple on-device AI — unlimited, offline, no quota
  - 1 active cut plan
  - 3 cloud meal scans and 5 cloud coach replies per month
- **Conversion hooks**:
  - "You're on the glide path — unlock unlimited cuts and the cloud coach for the rest of the season."
  - "Your coach can watch this live with the Team dashboard."
  - "This cut worked. Keep the full archive and start the next one in one tap."

## Pro Features Unlocked (All Paid Tiers)

| Feature | Free | Pro (Monthly / Yearly / Single-Cut / BYO Lifetime) |
|---------|:----:|:--------------------------------------------------:|
| Glide path, protocol, safety, USG, refuel | ✅ | ✅ |
| Active cut plans | 1 | Unlimited |
| Apple on-device AI | ✅ Unlimited | ✅ Unlimited |
| Cloud meal scans (GLM vision) | 3 / month | 30 / month (Single-Cut Pass: 100 total) |
| Cloud Corner Coach replies | 5 / month | 60 / month (Single-Cut Pass: 200 total) |
| Coach / team dashboard (CKShare) | ❌ | ✅ Single athlete share (Coach tier: 30 athletes) |
| Historical season archive | Last cut only | ✅ Full archive |
| Widget themes | 1 | ✅ All |
| BYO API key, unlimited AI | ❌ | ✅ (permanent with BYO Lifetime) |

## Free Trial
- **Duration**: 7 days
- **Type**: Free trial (auto-converts to paid subscription)
- **Available for**: Pro Yearly only
- **Notes**: Trial applies once per Apple ID. Monthly and Coach tiers have no trial. Single-Cut Pass and BYO Lifetime have no trial.

## Policy Pages Required
- Support Page: ✅ (must include subscription management + cancellation instructions)
- Privacy Policy: ✅
- Terms of Use (EULA): ✅ (REQUIRED — subscription apps must have Terms)
- **Total policy pages**: 3

## Apple IAP Compliance Checklist
- [x] Auto-renewal terms will be included in Terms of Use
- [x] Cancellation instructions will be included in Support Page
- [x] Pricing clearly stated in PaywallView
- [x] Free trial terms included (Pro Yearly 7 days)
- [x] Restore purchases functionality implemented
- [x] No external payment links (Guideline 3.1.1)
- [x] No price references to outside-App-Store options
- [x] All IAP descriptions ≤ 55 characters
- [x] All IAP display names ≤ 35 characters
- [x] BYO key products do not count AI generations — AI is unlimited with the user's own key
