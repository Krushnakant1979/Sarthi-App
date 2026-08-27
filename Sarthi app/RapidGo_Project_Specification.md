# RapidGo — Flutter Bike Taxi Project Specification

**Android-only • Firebase backend • Official Ola Maps Android SDK 1.8.4**

> Status: implementation specification. Credential values are intentionally blank.

## How to use this document

Antigravity must read the whole document, implement one phase at a time, verify builds/tests after each phase, and ask the user only for the blank manual inputs.

## 1. Document purpose and product scope

### Purpose

This document is the implementation source of truth for Antigravity and the development team. It defines product behavior, UI/UX, architecture, dependencies, backend contracts, data models, security boundaries, tests, and release gates for an Android-only Flutter bike-taxi application.

### Terminology

- User: the customer who searches, books, tracks, pays for, and rates a ride.

- Captain: the verified driver who goes online, receives requests, completes rides, and earns money.

- Admin: authorized operations staff who manage the platform. Never use “Rider” in code, UI copy, database labels, or documentation.

### MVP boundaries

- Android only; Flutter/Dart client applications.

- Separate User App and Captain App. Admin is preferably a responsive web panel; it may be a separate Flutter Web project later.

- Email/password authentication for the MVP. Phone OTP and social login are future options.

- Bike vehicle type and cash payment first. Online payment is a later, webhook-verified module.

- Ola Maps handles map rendering and map APIs. Firebase/backend handles identity, matching, rides, fares, live location, notifications, permissions, and auditability.

- Use the local official Ola Maps Android AAR only: android/app/libs/OlaMapSdk-1.8.4.aar. Do not add classes.jar separately and do not use ola_map_flutter.

### Non-goals for the first milestone

- iOS support, multi-city optimization, advanced surge pricing, automated payouts, and fully autonomous fraud detection.

- Calling the project “production-ready” before security rules, backend enforcement, device testing, observability, privacy review, and store compliance pass.

## 2. Product experience and professional UI/UX

### Design direction

Create a calm, trustworthy, map-first experience inspired by modern mobility products without copying proprietary layouts. The interface should prioritize location, trip state, safety, and a single clear next action. Prefer functional polish over decorative glass effects.

### Design tokens

- Primary/ink: #0B2545; action blue: #1565C0; live/success teal: #00A6A6; warning: #F59E0B; error: #D32F2F.

- Surfaces: #FFFFFF cards on #F5F8FB background; dark mode uses accessible near-black surfaces rather than pure black.

- Typography: use a bundled or system-safe family (Inter or Roboto). Do not make the app depend on a font fetched at runtime.

- Spacing scale: 4, 8, 12, 16, 24, 32; card radius 16; primary button height 52; minimum touch target 48×48 dp.

- Meet WCAG AA contrast where applicable; support text scaling, TalkBack labels, semantic order, and visible focus.

### Map-screen layout

- Full-screen map with a compact top location/search control and a draggable bottom sheet.

- Bottom sheet states: collapsed status, selection/search, ride options, matching, captain assigned, trip progress, and completion.

- Keep primary CTA reachable by thumb and stable between state changes. Do not cover attribution, safety, or essential map controls.

- Markers must have distinct shapes as well as colors: User/pickup, destination, Captain. Animate Captain movement by interpolation; avoid sudden jumps.

- Loading, permission denied, GPS disabled, offline, no results, no Captains, route failure, and retry states must be intentionally designed.

### Reusable components

- AppButton, AppTextField, SearchLocationField, StatusChip, VehicleOptionCard, FareBreakdown, RideStatusSheet, CaptainCard, EmptyState, ErrorState, Skeleton, ConfirmationDialog, SafetyAction, MapControlButton.

- Every component supports disabled/loading/error states and light/dark themes. Use motion sparingly (150–300 ms) and respect reduced-motion preferences.

### Screen inventory

- Shared: splash, onboarding, login, register, forgot password, email verification, profile, settings, notifications, help/support, legal/privacy.

- User: home map, pickup/destination search, vehicle/fare options, confirmation, searching, Captain assigned, trip in progress, completion/payment, rating, history, ride detail.

- Captain: onboarding/KYC, dashboard map, online/offline, incoming request, route to pickup, arrived/OTP, active trip, completion, earnings, history, profile/documents.

- Admin: dashboard, Users, Captains/KYC, vehicles, rides/live monitoring, fare rules, service zones, payments/settlements, support, safety events, notifications, reports, roles/audit logs.

## 3. Complete technology stack

### Client

- Flutter (latest stable compatible with project tooling) and null-safe Dart.

- Riverpod with code generation only if the team accepts build_runner; otherwise use non-generated Riverpod providers.

- go_router for declarative routing and route guards.

- Official Ola Maps Android SDK 1.8.4 bridged through an Android Platform View and Method/Event Channels.

- Kotlin for the native Android bridge; Gradle Kotlin DSL or Groovy must follow the generated Flutter project consistently.

### Firebase and backend

- Firebase Authentication: email/password, verification, password reset, account disablement.

- Cloud Firestore: durable business records and controlled real-time ride state.

- Firebase Realtime Database: high-frequency Captain and active-ride locations with presence/staleness handling.

- Firebase Storage: profile images and Captain KYC documents.

- Firebase Cloud Messaging: ride and account notifications.

- Cloud Functions for Firebase (TypeScript): trusted commands, matching, fare calculation, transitions, OTP verification, notifications, scheduled jobs, and payment webhooks.

- App Check, Crashlytics, Analytics, Performance Monitoring, and Remote Config where appropriate.

### Environments

- Separate Firebase projects and credentials for development, staging, and production.

- Separate Ola credentials and API quotas where the provider permits.

- Never copy production user data into development. Use emulator/synthetic fixtures.

## 4. Repository and application architecture

### Recommended repository

- apps/user_app — Flutter Android User application.

- apps/captain_app — Flutter Android Captain application.

- apps/admin_app — future Flutter Web admin application.

- packages/design_system — shared themes and UI components.

- packages/domain — entities, value objects, failures, and use cases.

- packages/data — repositories, DTOs, Firebase adapters, and API clients.

- packages/ola_maps_bridge — Flutter-facing interface plus Android Platform View implementation.

- functions — Firebase Cloud Functions in TypeScript.

- firebase — Firestore/Storage/Realtime Database rules, indexes, emulator config, and seed fixtures.

- docs — architecture decisions, API contracts, diagrams, privacy and runbooks.

### Flutter feature structure

- lib/app — bootstrap, router, theme, environment configuration.

- lib/core — errors, logging, validation, network state, constants, utilities.

- lib/features/auth/{data,domain,presentation}.

- lib/features/map, places, rides, tracking, payments, notifications, profile, support with the same layered pattern.

- Presentation depends on domain abstractions; data implements repositories. UI must not call Firebase or REST clients directly.

### Architecture rules

- Use immutable domain models. Keep Firestore DTOs separate from UI/domain models.

- All sensitive mutations are command calls to trusted Cloud Functions or HTTPS endpoints.

- Repositories expose Result/Failure-style outcomes and streams where real-time behavior is needed.

- Platform-channel messages use versioned, JSON-compatible contracts and convert native failures into typed Flutter errors.

- Keep map provider interfaces replaceable so Ola-specific implementation does not leak across ride-domain logic.

## 5. Dependencies and purpose

### Flutter packages

- flutter_riverpod — state management and dependency injection.

- go_router — navigation, deep links, and authentication guards.

- firebase_core, firebase_auth — Firebase bootstrap and identity.

- cloud_firestore — durable app data and ride state streams.

- firebase_database — live Captain/ride locations.

- firebase_storage — profile and verification uploads.

- firebase_messaging — push token and foreground notification handling.

- firebase_app_check — abuse resistance for supported Firebase resources.

- firebase_crashlytics, firebase_analytics — diagnostics and product telemetry.

- geolocator — GPS, service status, permissions, and location streams.

- permission_handler — permissions not fully covered by a specialized plugin.

- dio — REST client with cancellation, timeouts, interceptors, and typed error mapping.

- freezed_annotation/json_annotation (optional) — immutable models and JSON mapping; requires build_runner/freezed/json_serializable as dev dependencies.

- flutter_secure_storage — device-side non-server secrets/session metadata; never for provider client secrets.

- connectivity_plus — connectivity signal (not proof of internet reachability).

- uuid — idempotency keys/client operation IDs.

- intl — locale-aware dates, time, currency, and distance display.

- cached_network_image — controlled image caching.

- shimmer (optional) — restrained skeleton loading.

- flutter_local_notifications — foreground/local notification presentation.

- mocktail, integration_test — unit mocks and end-to-end tests.

### Native and backend dependencies

- OlaMapSdk-1.8.4.aar — official Android SDK, stored once under android/app/libs.

- AndroidX, Kotlin, and any transitive libraries required by the SDK documentation/AAR metadata; do not guess or duplicate packaged classes.

- firebase-admin, firebase-functions — trusted backend access and triggers.

- zod — request validation in Cloud Functions.

- geofire-common or a reviewed geohash implementation — nearby Captain candidate queries.

- pino or structured functions logging — redacted operational logs.

- vitest/jest — backend unit and emulator tests.

### Version policy

Do not paste “latest” into pubspec.yaml. Use `flutter pub add <package>` in the target environment, commit pubspec.lock for applications, review changelogs, and verify compatibility with the chosen Flutter, Android Gradle Plugin, Kotlin, Firebase BoM, and Ola SDK. Pin the AAR at 1.8.4 until an explicit upgrade is tested.

## 6. Android and build configuration

### Required configuration

- Set applicationId/namespace per environment; configure minSdk/compileSdk/targetSdk according to current Flutter, Play, Firebase, and Ola SDK requirements after inspecting the AAR and official docs.

- Place the AAR at android/app/libs/OlaMapSdk-1.8.4.aar and declare exactly one local AAR dependency. Add flatDir only if required by the chosen Gradle setup.

- Read OLA_MAPS_API_KEY from android/local.properties for local builds and inject it through a manifest placeholder or BuildConfig field expected by the native SDK. Never log it.

- Add google-services.json per app/environment outside public distribution and apply the Google Services plugin.

- Keep R8/ProGuard rules supplied by the Ola SDK. Verify release builds; do not globally disable shrinking as a permanent fix.

- Define dev/staging/prod flavors and unique application IDs, app labels, Firebase resources, and endpoints.

### Permissions

- android.permission.INTERNET.

- ACCESS_FINE_LOCATION and ACCESS_COARSE_LOCATION for both apps, requested contextually.

- POST_NOTIFICATIONS on supported Android versions.

- ACCESS_BACKGROUND_LOCATION and foreground-service location permissions only for the Captain App when continuous background tracking is truly implemented and policy-compliant.

- Declare foreground service type=location for the Captain tracking service where required. Provide a persistent notification and a clear stop/offline action.

### Build secrets

local.properties is local-only and normally ignored. CI reads secrets from its encrypted secret store. Mobile apps cannot safely contain OAuth client secrets, Firebase service-account keys, payment gateway secrets, or unrestricted provider credentials.

## 7. Ola Maps and API integration plan

### Native bridge responsibilities

- Create OlaMapPlatformViewFactory and a lifecycle-aware native map view.

- Register view type `rapidgo/ola_map` in MainActivity or the Flutter plugin.

- MethodChannel commands: initialize, moveCamera, fitBounds, add/update/removeMarker, setPolyline, clearRoute, setStyle, setMyLocationEnabled.

- EventChannel events: mapReady, cameraIdle, mapTap/longPress, markerTap, nativeError.

- Dispose listeners and native resources correctly; queue commands until mapReady.

### REST services

- Autocomplete for typed search; debounce 400–500 ms, cancel stale calls, add location bias, and do not fire on every keystroke.

- Place Details to resolve the selected provider place ID into coordinates and a normalized address.

- Reverse Geocoding to label current/pin coordinates.

- Directions to obtain route geometry, road distance, duration, steps, and alternatives if enabled.

- Distance Matrix for ranking Captain pickup ETAs when useful; batch and cache safely.

- Confirm exact base URLs, authentication headers/query parameters, response fields, quotas, attribution, and allowed mobile-key restrictions from the official Ola documentation for the user’s account. Do not invent endpoint contracts.

### Security boundary

- Map-rendering key may be injected into the Android client only if designed/restricted for mobile use.

- Privileged or billable REST calls should be proxied through Cloud Functions when the provider credentials cannot be safely restricted in an APK.

- Never ship OAuth Client Secret. Add request quotas, App Check, authentication, rate limits, timeout/retry budgets, and redacted logs.

### Fallback behavior

- Cache recent places only when terms allow. Show retry and manual pin selection when search fails.

- If Directions fails, do not calculate fare from straight-line distance; block confirmation or clearly mark an unavailable estimate.

- Show required Ola/provider attribution exactly as required by the applicable SDK/API terms.

## 8. Authentication and authorization

### User flow

- Register with email/password → send verification email → create profile through trusted callable function → accept terms/privacy → enter app.

- Login → backend checks account active/blocked and role → router enters the appropriate application.

- Forgot password uses Firebase reset email. Email changes and destructive account actions require recent authentication.

- Sign-out revokes local state, deactivates device token, and clears sensitive caches.

### Captain flow

- Captain account begins pending. Profile, vehicle, and required documents are uploaded.

- Admin verifies documents and vehicle; backend assigns approved Captain claims/status.

- Only approved, active Captains may go online or receive ride offers.

### Authorization

- Custom Claims provide coarse roles: user, captain, admin/support subroles. Firestore profile fields are not sufficient authorization.

- Rules enforce least privilege. Admin actions require both claims and server-side checks.

- Clients cannot assign Captains, finalize fares, credit wallets, approve documents, or force ride transitions.

## 9. Backend commands and logic

### Core callable/HTTP functions

- createProfile, registerDevice, setCaptainAvailability.

- estimateRide: validate coordinates/zone, request route, load fare rule, return signed/expiring estimate.

- createRideRequest: validate estimate, payment method, user state, idempotency key; create request.

- matchRide: geohash candidate search, freshness/eligibility filter, road ETA ranking, offer batches, expanding radius.

- acceptRide: Firestore transaction verifies open offer/request, assigns exactly one Captain, marks Captain unavailable, creates ride, closes other offers.

- updateRideStatus: validates actor, current state, transition, proximity where required, and timestamp.

- verifyRideOtp: rate-limited hash comparison; starts ride only through an atomic transition.

- cancelRide: stage-aware authorization, reason and fee calculation, Captain release, notifications.

- completeRide: validates active state, computes final distance/fare server-side, creates payment/ledger entries, releases Captain.

- submitRating, createSupportTicket, triggerSafetyEvent, adminApproveCaptain.

- paymentWebhook: verifies gateway signature and idempotently updates payment/ledger state.

- scheduled: expire requests/offers, mark stale Captains offline, document expiry reminders, retention cleanup, reports.

### Idempotency and concurrency

- Every mutation accepts a clientOperationId/idempotencyKey and records the result.

- Use Firestore transactions for assignment, status transition, ledger, coupon consumption, and completion.

- Never rely on “first client write wins.” Backend server timestamps are authoritative.

### Matching strategy

- Candidate eligibility: approved/active, online/available, correct vehicle type, fresh location, inside zone, no active ride.

- Geohash radius sequence: e.g., 2 km → 4 km → 6 km → 10 km, configured per city.

- Rank primarily by pickup ETA, then distance, idle time, rating, acceptance/cancellation signals. Do not use protected characteristics.

- Offer in small batches with expiry; first valid transactional acceptance wins.

## 10. Firestore data model

### Collection conventions

Use server timestamps, explicit schemaVersion, immutable IDs, and money in integer minor units (paise) rather than floating point. Store coordinates as GeoPoint plus geohash where queried. Do not duplicate sensitive KYC data unnecessarily.

### Core collections

- users/{uid}: role, name, email, phone?, photoUrl?, accountStatus, emailVerified, preferredLanguage, createdAt, updatedAt.

- captains/{uid}: verificationStatus, accountStatus, isOnline, isAvailable, currentRideId?, vehicleId, aggregate rating/count, createdAt, updatedAt.

- captains/{uid}/documents/{documentId}: type, storagePath, maskedNumber, expiryDate, status, rejectionReason?, verifiedBy?, verifiedAt?.

- vehicles/{vehicleId}: captainId, type=bike, registrationNumber, make/model/color/year, verificationStatus, active.

- ride_estimates/{estimateId}: userId, pickup/destination, route summary, fare breakdown, ruleVersion, expiresAt, status.

- ride_requests/{requestId}: userId, estimateId, vehicleType, pickup, destination, status, assignedCaptainId?, radiusStage, expiresAt, createdAt.

- ride_requests/{requestId}/offers/{captainId}: status, offeredAt, expiresAt, respondedAt?.

- rides/{rideId}: requestId, userId, captainId, vehicleId, locations, status, estimate/final fare summaries, route summary, payment fields, event timestamps, cancellation?, schemaVersion.

- rides/{rideId}/events/{eventId}: type, actorId, actorRole, fromStatus?, toStatus?, metadata, createdAt.

- fare_rules/{ruleId}: city/zone/vehicle, rates in paise, included distance, waiting rules, multipliers, tax, effective interval, version, active.

- payments/{paymentId}: rideId, amountPaise, currency, method, gateway, status, gatewayReference?, createdAt, completedAt?.

- wallets/{captainId}: availablePaise, pendingPaise, version, updatedAt.

- wallet_transactions/{transactionId}: walletId, rideId?, type, direction, amountPaise, before/after, idempotencyKey, status, createdAt.

- ratings/{ratingId}: rideId, from/to IDs and roles, integer rating 1–5, review?, tags, createdAt.

- notifications/{notificationId}: userId, type, title/body, rideId?, readAt?, createdAt.

- users/{uid}/devices/{deviceId}: fcmToken, platform, appType, active, updatedAt.

- service_zones/{zoneId}: city, polygon/geofence representation, allowedVehicles, hours, active.

- support_tickets/{ticketId}, emergency_events/{eventId}, coupons/{couponId}, audit_logs/{logId}, app_settings/{document}.

### Required indexes (initial)

- ride_requests: status + createdAt; userId + createdAt desc; assignedCaptainId + status.

- rides: userId + createdAt desc; captainId + createdAt desc; status + updatedAt.

- captains: verificationStatus + accountStatus + vehicleId where admin queries require it.

- notifications: userId + createdAt desc; support tickets: status + priority + updatedAt.

- Geohash candidate querying uses the reviewed index/query pattern and is followed by exact distance filtering.

## 11. Realtime Database model

### Structure

Use live/captains/{captainId} and live/rides/{rideId}/captain. Keep high-frequency location separate from Firestore business records.

### Captain location payload

- lat, lng, heading, speedMps, accuracyM, geohash, capturedAtMs, serverReceivedAtMs.

- online, available, vehicleType, currentRideId?, appState?, sequence.

- Use server-side staleness detection. Client timestamps alone are not trusted.

### Update policy

- Offline: remove presence/mark offline using onDisconnect where suitable.

- Online idle: 15–30 seconds or meaningful movement.

- To pickup: 5–10 seconds; active trip: roughly 3–5 seconds, adapted for battery/network and platform rules.

- Validate ranges, monotonic sequence, accuracy, impossible jumps, and user authorization. Retain only what the privacy policy requires.

### Read access

- Nearby public Captain views must expose only the minimum anonymized fields needed before assignment.

- An active ride’s User and Captain can read its location node; writes belong only to the assigned Captain/device path.

- Admin live access is claim-gated and audited.

## 12. Ride lifecycle and state machine

### Request states

- created → searching → broadcasted → accepted → converted_to_ride

- Terminal alternatives: expired or cancelled.

### Ride states

- captain_assigned → captain_arriving → captain_arrived → otp_verified → ride_started → ride_in_progress → ride_completed → payment_pending → paid.

- Cancellation is a terminal branch allowed only according to actor and current stage. Failed payment is a payment substate, not permission to repeat ride completion.

### Transition requirements

- Captain arrival may require proximity and fresh GPS.

- OTP is generated server-side, stored hashed, expires, and permits a small number of attempts.

- Start requires assigned Captain, arrived state, verified OTP, and server timestamp.

- Complete requires active ride, destination/proximity or approved exception, final route/fare calculation, and atomic ledger creation.

- Every transition writes an append-only event and sends relevant notifications.

### Fare calculation

- Backend formula: base + billable distance + time + booking/platform/waiting/toll/tax + surge − discount, bounded by minimum fare.

- The estimate stores fare rule version and expiry. Final fare records a full immutable breakdown.

- Do not calculate money with binary floating point; use integer paise/decimal-safe arithmetic.

## 13. State management and client behavior

### Riverpod approach

- Providers for Firebase instances, API clients, repositories, use cases, and feature controllers.

- AsyncNotifier/Notifier for commands and screen state; StreamProvider for auth, ride, and location subscriptions.

- Use sealed states for initial/loading/data/empty/error and explicit ride UI state derived from backend status.

- Dispose searches/subscriptions when screens close; cancel stale autocomplete and directions requests.

- Do not store a second authoritative ride state in local preferences.

### Offline and retry

- Disable sensitive commands when offline; queue only explicitly idempotent safe operations.

- Use exponential backoff with jitter for transient backend failures, never for validation/auth errors.

- Preserve typed form input but never present stale estimates as bookable after expiry.

## 14. Security, privacy, and safety practices

### Security controls

- App Check, authenticated callable functions, strict Firestore/RTDB/Storage rules, least-privilege IAM, secret manager for server secrets.

- Restrict Ola keys by app/package/signing certificate or domain/API where supported; apply quotas and billing alerts.

- Hash ride OTP; rate limit login-adjacent and booking endpoints; verify email; revoke blocked users.

- Validate all request schemas, coordinate ranges, status transitions, amounts, timestamps, IDs, file MIME/type/size, and role claims.

- Use signed download access or rules for KYC documents; never expose public permanent URLs for sensitive files.

- Structured logs must redact tokens, secrets, exact personal addresses where unnecessary, document numbers, and payment data.

- Audit all admin, financial, KYC, safety, and manual override actions.

### Privacy and retention

- Ask for location only when needed; background location is Captain-only and explained before the system prompt.

- Define retention for detailed trip tracks, KYC, support, analytics, and account deletion. Collect the minimum necessary.

- Provide privacy policy, terms, consent, data export/deletion process, emergency disclaimer, and incident response runbook.

- Comply with applicable Indian law, payment rules, Ola/Firebase terms, and Google Play policies after legal review.

### Threat cases to test

- Two Captains accept simultaneously; replayed request; forged role/profile; stale or spoofed location; impossible speed/jump.

- Client attempts direct fare/wallet/status writes; expired estimate/coupon; duplicate webhook; leaked FCM token; unauthorized KYC access.

## 15. API keys and secrets — MANUAL ENTRY ONLY

### Ola Maps API key rule

The user will enter the Ola Maps API key manually. Antigravity must never request the key in chat, invent a value, copy it into Dart/Kotlin source, print it, or commit it. Antigravity must create the configuration placeholder only, then continue with code that reads the value at build time.

### Required local placeholder

Create or preserve this line in android/local.properties: OLA_MAPS_API_KEY=PASTE_YOUR_OLA_MAPS_API_KEY_HERE. The user will replace only the placeholder text on their own computer. Keep android/local.properties out of source control. Antigravity should report “Ola Maps API key must be filled manually” as a manual setup step and must not block other work that can be completed without the real value.

### Instructions

Fill credential values locally. Never commit a completed copy. Values below must remain blank in shared documents. “Client-safe” means extractable from an APK and therefore must be restricted, not treated as secret.

### Credential handling

- Local Android values: android/local.properties or injected CI variables.

- Flutter compile-time non-secret environment labels/endpoints: --dart-define-from-file using an ignored file.

- Backend secrets: Google Cloud Secret Manager / Firebase secret parameters.

- CI/CD: encrypted environment-specific secret store with least-privilege access and rotation.

| Credential/configuration | Context/file | Manual value | Classification | Notes |
|---|---|---|---|---|
| Environment | development / staging / production |  | Not secret | Select one per copy |
| Android applicationId |  |  | Not secret | Per app/flavor |
| Firebase project ID |  |  | Not secret | Per environment |
| Firebase Android config | google-services.json |  | Config file | Do not paste private service-account JSON |
| Ola Maps API key | android/local.properties → OLA_MAPS_API_KEY | FILLED MANUALLY BY USER | Client-safe only if restricted | Antigravity creates placeholder only; never asks for or inserts the key |
| Ola OAuth Client ID |  |  | Treat as sensitive | Backend only if required |
| Ola OAuth Client Secret |  |  | SECRET | Secret Manager only; never APK |
| Ola API base URL/region |  |  | Not secret | Confirm from official docs |
| Firebase App Check provider |  |  | Config | Record setup, not private key |
| FCM sender/project metadata |  |  | Config | Server credentials stay in Firebase/Secret Manager |
| Payment gateway key ID |  |  | May be client identifier | Future phase |
| Payment gateway secret/webhook secret |  |  | SECRET | Backend Secret Manager only |
| Admin bootstrap UID/email |  |  | Sensitive PII | Assign claims through controlled process |
| Android signing keystore location/alias |  |  | SECRET metadata | Never record passwords here |
| CI secret variable names |  |  | Names only | Do not record values |

## 16. Testing strategy and acceptance checklist

### Automated tests

- Unit: validators, fare arithmetic, state-transition policy, DTO mapping, repository errors, matching ranking.

- Widget/golden: authentication forms, map overlays with mocked bridge, bottom-sheet states, accessibility/text scaling, light/dark themes.

- Integration: Firebase Emulator auth/rules/functions, ride request, race acceptance, OTP, cancellation, completion, notification records.

- Native bridge: map lifecycle, command-before-ready queue, markers/polylines, rotation/background/restore, channel error mapping.

- Backend: idempotency, transaction contention, webhook signature/replay, stale Captain cleanup, rules denial tests.

- Performance: map screen startup, search debounce, location bandwidth/battery, Firestore query/read counts, function latency.

### Manual/device checklist

- Fresh install; denied/limited/permanently denied permission; GPS off; network loss/recovery; low-memory process recreation.

- Map loads with attribution; current location; search/selection; route polyline; camera bounds; distance/ETA.

- Two real devices complete User↔Captain lifecycle; competing Captain acceptance; cancellation at each allowed stage.

- Notifications in foreground/background/terminated; token refresh; Captain background tracking notification and stop behavior.

- TalkBack, 200% font scale, color contrast, touch targets, keyboard, dark mode.

- Debug and minified release builds install and run on supported Android versions.

### Definition of done

- flutter analyze has no unresolved issues; tests pass; emulator/rules tests pass; release build succeeds.

- No secrets in source/history/artifacts/logs; dependency and license review complete.

- All critical errors have user-facing recovery and are observable in Crashlytics/logging.

- Product owner validates copy, terminology (“User”), fares, cancellation, safety, and admin controls.

## 17. Implementation phases

### Phase 0 — foundation

- Create monorepo/apps, flavors, Firebase projects/emulators, design system, routing, error/logging strategy, CI, architecture decision records.

### Phase 1 — map proof

- Integrate the single AAR, Platform View/channel, permissions, map display, current location, recenter, marker. Verify debug and release early.

### Phase 2 — authentication

- User/Captain registration and login, verification, profiles, role routing, Captain KYC upload, initial rules.

### Phase 3 — places and route

- Autocomplete, Place Details, reverse geocode, pickup/destination pins, Directions, polyline, distance/ETA, failure states.

### Phase 4 — booking core

- Fare rules/estimate, ride request, Captain availability, geohash matching, offers, transactional acceptance, notifications.

### Phase 5 — active ride

- Live tracking, arrival, OTP, strict transitions, cancellation, completion, cash payment record, history/rating.

### Phase 6 — operations

- Admin dashboard, verification, fare/zones, ride monitoring, support/safety, audit logs, basic reports.

### Phase 7 — hardening and release

- Rules penetration tests, App Check, performance/battery, privacy/retention, accessibility, Play policy, monitoring, staged rollout.

## 18. Deployment and operations checklist

### Pre-release

- Use production Firebase/Ola projects, restricted credentials, verified domains/package/signing hashes, quotas, alerts, and budgets.

- Deploy reviewed rules, indexes, functions, secrets, scheduled jobs, Storage CORS if needed, and backups/export plan.

- Generate upload key/app signing configuration securely; build signed AAB; verify R8 mapping and Crashlytics symbol upload.

- Complete Play Console data safety, privacy policy, background location declaration/video if required, content rating, permissions, and test accounts.

- Run internal → closed → staged production tracks. Define rollback, feature flags, minimum supported version, and incident contacts.

### Operations

- Dashboards: request→accept conversion, match time, pickup ETA, completion/cancellation, online Captains, function errors/latency, notification delivery, map API usage.

- Alerts: assignment failures, elevated cancellations, stale location pipeline, payment webhook failures, quota/budget thresholds, security rule denials/anomalies.

- Runbooks: map provider outage, Firebase outage, leaked key rotation, abusive account, safety escalation, payment reconciliation, data deletion request.

## 19. Coding standards and Antigravity execution rules

### Engineering standards

- Dart/Flutter effective style, strict analysis options, sound null safety, small composable widgets, dependency inversion, typed failures.

- No business logic in widgets; no direct database access from presentation; no unbounded listeners or queries.

- Document public APIs and non-obvious invariants. Prefer readable code over speculative abstractions.

- Use conventional commits, small reviewable changes, protected main branch, CI gates, and architecture decision records for important deviations.

### Antigravity instructions

- Read this entire specification before editing. Inspect existing files, AAR metadata, and official Ola documentation first.

- Implement one phase at a time. Do not scaffold fake “complete” features or placeholder production logic.

- Before adding packages, confirm compatibility and explain why each is needed. Never add a second Ola SDK source.

- After each phase run formatting, flutter analyze, targeted tests, emulator tests where applicable, and Android debug/release build.

- List files changed, commands run, tests/build results, manual steps, assumptions, and remaining risks.

- For the Ola Maps API key, create only `OLA_MAPS_API_KEY=PASTE_YOUR_OLA_MAPS_API_KEY_HERE` in the ignored local configuration. The user will replace it manually. Never ask the user to paste the key into chat or source code.

- Stop and request manual input only for credentials, Firebase project files, signing, policy/legal decisions, provider-console restrictions, or genuinely ambiguous business rules.

## Appendix A — Example payloads

### Ride location

```json
{ "address": "Akola Railway Station", "placeId": "provider_place_id", "point": "GeoPoint(20.6879, 77.0197)", "geohash": "..." }
```

### Ride fare summary

```json
{ "currency": "INR", "basePaise": 2000, "distancePaise": 6000, "timePaise": 1650, "feesPaise": 500, "taxPaise": 0, "discountPaise": 0, "totalPaise": 10150, "ruleVersion": 1 }
```

### Realtime location

```json
{ "lat": 20.7001, "lng": 77.0082, "heading": 145.5, "speedMps": 6.5, "accuracyM": 8, "geohash": "...", "sequence": 42, "capturedAtMs": 1784876400000, "serverReceivedAtMs": 1784876400500, "online": true, "available": true, "vehicleType": "bike", "currentRideId": null }
```

## Appendix B — Manual decisions to complete before implementation

### Decision register

- Final app/package names and branding.

- Supported Android versions after SDK compatibility check.

- Cities/service zones and operating hours.

- Fare, cancellation, waiting, commission, tax, and rounding rules.

- Captain KYC documents and review workflow.

- Location update/retention policy and safety escalation process.

- Cash-only MVP confirmation and future payment gateway.

- Ola API quota, pricing, attribution, mobile-key restrictions, and REST authentication method.

- Admin roles and permissions.

- Languages, accessibility target, and privacy/legal approvals.
