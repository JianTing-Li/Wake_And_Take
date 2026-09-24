# Wake&Take Architecture

Wake&Take is an iOS marketplace for discounted **surprise bags** of surplus food from cafés, bakeries,
restaurants and markets in Long Island City (LIC). Unlike end-of-day apps, businesses sell throughout the
day, especially breakfast. This build covers the **customer side** only. All data is mock and stays mock
(no backend), but the mock layer behaves like a real marketplace: shared stock, atomic reservations,
pickup windows that open and close, and persistence across launches.

> Status: the refactor is happening in phases on the `app-refactor` branch. The app runs entirely on the
> new stack (`App/`: `AppDependencies` → `AppRoot` → `CustomerTabView` → `CustomerScreens`). The legacy draft
> files in `Wake_And_Take/` still compile but are no longer used; Phase 6 deletes them.

---

## 1. Ground rules

| Area | Rule |
|---|---|
| Platform | iOS only (iPhone and iPad), iOS 26.0 minimum. No API newer than iOS 26. |
| Language | Swift 6 language mode, strict concurrency, zero warnings. |
| Pattern | MVVM. One `@Observable @MainActor` view model per screen. Views render; they never filter data or call stores. |
| Dependencies | Apple frameworks only. |
| Money | `Int` cents end to end. Format as USD only at the UI edge. |
| Time | Everything reads an injected `Clock`. Only `LiveClock` may call `Date.now`. All calendar math uses **America/New_York** via `NYCalendar`, never `Calendar.current`. |
| Persistence | SwiftData for everything. No `UserDefaults`. |
| Formatting | Apple `swift-format` with the repo's `.swift-format` (4 spaces, 120 columns). |

---

## 2. Modules

A thin app target plus one local Swift package, `Packages/WakeAndTakeKit`:

```
App target  ──►  CustomerFeatures, MockData, DesignSystem, Platform, Domain
CustomerFeatures ──►  Domain, DesignSystem, Platform
MockData    ──►  Domain, Platform
DesignSystem ──►  Domain (value types only, never repositories)
Platform    ──►  Domain
Domain      ──►  Foundation only
```

| Module | Holds | Default isolation |
|---|---|---|
| **App** | Composition root (`AppDependencies`), `AppRoot`, splash, rollover triggers, DEBUG tools | MainActor |
| **Domain** | Plain `Sendable` models, pure business rules, repository **protocols** | nonisolated |
| **Platform** | `Clock`, `NYCalendar`, location, notifications, pickup codes, QR codes | nonisolated |
| **MockData** | SwiftData entities, seed JSON + loader, `MarketplaceStore`, `UserDataStore`, repository implementations | nonisolated |
| **DesignSystem** | Colors, type, spacing, category/dietary styles, reusable components | MainActor |
| **CustomerFeatures** | Screens and their view models, tab navigation | MainActor |

Hard rules:

- **`CustomerFeatures` never imports `MockData`.** Features talk to repository protocols from `Domain`.
  Only the app target knows the concrete stores exist.
- **`Domain` has no UI, SwiftData or CoreLocation.** Category colors and SF Symbols live in
  `DesignSystem` (e.g. `FoodCategory+Style.swift`). Coordinates are plain `Double`s.
- **DesignSystem components take primitives** or small display structs, never repositories. DesignSystem may
  import Domain for plain value types (e.g. `FoodCategory`, `Money`) so style extensions live next to components.
- SwiftData `@Model` entities never leave `MockData`; they map to and from Domain structs.

---

## 3. Domain model

- **Restaurant**: id, name, type (`cafe`, `bakery`, `deli`, `restaurant`, `market`), address (street, cross
  street, neighborhood, borough, zip), coordinate, pickup instructions, rating, review count.
- **Offer** (a surprise bag for one day): id = `"<templateID>-<yyyy-MM-dd>"` (New York date), restaurant id,
  name, category (`breakfast`, `bakery`, `coffee`, `meal`, `grocery`), "may include" summary, dietary tags,
  price and estimated value (cents), quantity total/reserved, pickup window. No itemized contents.
- **Reservation**: 4-char confirmation code, quantity, an immutable **`OfferSnapshot`** of what the customer
  saw, reserved/collected/cancelled timestamps, cancel reason, optional review. Order screens read the
  snapshot, never the live offer.
- **Review**: overall, quality, value, pickup (1–5), tags, comment.
- **UserPreferences**: name, home area, max distance, dietary. **CommuteProfile**: leave/arrive times,
  commute days, travel mode.

### Rules (pure functions, all take `now`)

| Rule | Summary |
|---|---|
| `OfferAvailability` | upcoming / available / almostGone (≤1 left) / endingSoon (<30 min) / soldOut / ended, plus copy. |
| `OfferVisibility` | Visible if the offer is for today, or for tomorrow **and** it's ≥ 20:00 in New York. One rule for Discover, Map and Favorites. |
| `ReservationPolicy` | Status from the snapshot window; changes allowed until 10 min before pickup ends; max 3 bags; collect only while ready. |
| `ReviewPolicy` | One review per collected order, within 48 h; new rating folded into the restaurant's running average. |
| `ImpactCalculator` | Bags rescued, money saved, CO₂e (2.5 kg/bag) from collected orders. |
| `PreferenceMatcher` | Within max distance of the resolved location; dietary filter when enabled. |
| `CommuteMatcher` | Pickup window overlaps today's commute window on commute days. |
| `PickupDayFormatter` | The single source of day-aware copy ("Today · …", "Tonight · …", "Tomorrow · …"). |

---

## 4. Data flow

```
 SwiftUI View ──renders──► @Observable ViewModel ──calls──► Repository protocol (Domain)
      ▲                          │   ▲                              │
      │ state                    │   └── AsyncStream<Change> ◄──────┤
      └──────────────────────────┘                                  ▼
                                                 MarketplaceStore / UserDataStore
                                                 (ModelActor actors, one shared ModelContainer)
```

- **`MarketplaceStore`** owns restaurants, offers, reservations and reviews. `reserve`, `changeQuantity`,
  `cancel`, `markCollected` and `submitReview` are atomic inside the actor and throw typed errors
  (`.soldOut`, `.windowClosed`, `.notVisibleYet`, `.invalidQuantity`, …).
- **`UserDataStore`** owns favorites (by restaurant id), per-restaurant alert settings, preferences and the
  commute profile.
- The stores *are* the concrete repositories (`MockData/Repositories/StoreRepositories.swift`): their
  actor methods satisfy the Domain protocols directly. `DemoDataResetter` implements `DemoDataResetting`.
- Offer templates are read from the bundled JSON on each launch (they're immutable config); restaurants,
  offers, reservations and user data are SwiftData rows.
- Each store emits changes on an `AsyncStream`. View models load in `.task`, observe the stream, and expose
  an explicit `state` (`loading`, `loaded`, `empty`, `failed`).
- `AppDependencies` (the composition root) builds the container, stores, repositories, clock and flags,
  and hands protocols to view models.

### Seed data

`MockData/Resources/` holds the two seed JSON files:

- `lic_restaurants.json`: 21 fictional businesses on real LIC streets.
- `offer_templates.json`: 32 daily templates with `HH:mm` pickup windows (New York time) and a
  `simulatedReservedCount` that stands in for other customers.

`SeedLoader` validates on load (unique ids, known restaurants, sane counts, window rules: start < end,
ends by 23:59, never crosses midnight, ≤ 3.5 h) and fails loudly in DEBUG.

### Daily rollover

The store always holds offers for **today and tomorrow** (New York). `rolloverIfNeeded(at:)`:

1. Computes today/tomorrow keys with `NYCalendar`.
2. Runs if `lastGeneratedDayKey != todayKey` (so a clock moved backwards also triggers it) or the seed
   version changed; otherwise returns.
3. Creates today's and tomorrow's offer for each template **only if that id doesn't exist**. Existing
   offers are never overwritten (tomorrow's may already have reservations).
4. Prunes offers from earlier days whose window has ended. Reservations are never touched.
5. Saves `lastGeneratedDayKey` and emits `.rolledOver`; the app then reschedules favorite alerts.

Triggers: app launch, scene becoming active, `significantTimeChangeNotification`, and DEBUG time travel.
Running it repeatedly is a no-op.

### Reset

Profile → **Reset demo data** (with confirmation) wipes both stores, reseeds, rolls over, cancels pending
notifications and pops every tab to its root.

---

## 5. Platform services

- **Clock**: `protocol Clock: Sendable { var now: Date { get } }` plus a change stream. `LiveClock` in
  production; `AdjustableClock` (DEBUG) applies an offset for time travel.
- **LocationProvider**: returns `ResolvedLocation(latitude, longitude, source: .device | .fallback(reason))`
  using `CLLocationUpdate.liveUpdates` / `CLServiceSession`. Falls back to the LIC center
  (`40.7455, -73.9490`) when permission is denied/restricted, there's no fix within 5 s, the simulator has
  no location, or the device is more than 1.5 mi from the service area. Distances to restaurants are
  computed from the resolved location.
- **NotificationScheduler**: local "bags are open" alerts for favorited restaurants, identifiers
  `drop-<offerID>`, plus a preview alert.
- **PickupCodeGenerator**: 4 chars from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`.
- **QRCodeGenerator**: CoreImage QR of the pickup code.

---

## 6. Feature flags

A compile-time `FeatureFlags` value is created in `AppDependencies` and injected through the SwiftUI
`Environment`. A flag that's off hides the UI entry points; code and data stay.

| Flag | Default | Controls |
|---|---|---|
| `mapBrowse` | on | Discover map mode toggle |
| `favorites` | on | Favorites tab, heart buttons |
| `notifications` | on | Alert toggles, preview alert (requires `favorites`) |
| `dietaryFilters` | on | Dietary section in Profile, dietary filtering |
| `manageOrder` | on | Change quantity / cancel |
| `reviews` | on | Rate order, ratings display |
| `impact` | on | Impact card (Orders + Profile) |
| `commute` | **off** | Profile "Morning commute" section and the "Fits your commute" badge |

---

## 7. Running tests

The package is iOS-only, so run its tests on a simulator (not `swift test`):

```sh
cd Packages/WakeAndTakeKit
xcodebuild test -scheme WakeAndTakeKit-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

In Xcode, open `Packages/WakeAndTakeKit/Package.swift` (or the app project) and run the
`WakeAndTakeKit-Package` scheme's tests. Rule tests use a fixed New York calendar
(`Tests/DomainTests/Fixtures.swift`) with Thu Sep 24, 2026 as "today".

---

## 8. How to add a feature

1. **Model and rules** — add or extend types in `Domain/Models` and pure logic in `Domain/Rules` (taking
   `now` as a parameter). Write Swift Testing tests in `DomainTests` with a fixed New York calendar.
2. **Data access** — if the feature needs new data, add a method to a repository protocol in
   `Domain/Repositories`, implement it in `MockData` (entity + mapping + store method), and test it with
   an in-memory `ModelConfiguration` and a fixed clock.
3. **UI pieces** — put reusable visuals in `DesignSystem/Components` with `#Preview`s (light, dark, large
   Dynamic Type). Components take primitives.
4. **Screen** — add a folder in `CustomerFeatures/` with a `View` and an `@Observable @MainActor` model that
   takes repository protocols and a `Clock`. Test the model with fake repositories.
5. **Flag it** — if it isn't core (P0), add a case to `FeatureFlags`, default it in
   `App/FeatureFlags+Default.swift`, and hide its entry points when off. Add a test for the flag.
6. **Wire it** — construct the model in `AppDependencies` or its parent model. Never import `MockData`
   from a feature.
