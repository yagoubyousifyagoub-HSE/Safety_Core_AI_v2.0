# Safety Core AI

Enterprise HSE site inspection & audit workflow app.
Standards: OSHA 29 CFR 1926/1910 · ISO 45001:2018 · ANSI Z16.1 (LTIFR/TRIR)
Lead System Designer: HSE Engineer Yagoub Mohamed

## 1. First-time setup

This repo ships only the Dart/`lib` layer plus config — generate native
platform folders once before your first run:

```bash
flutter create --org com.safetycoreai --project-name safety_core_ai .
flutter pub get
```

`pubspec.yaml` has `generate: true`, so `flutter gen-l10n` runs
automatically on `pub get` / `flutter run`, producing
`lib/l10n/gen/app_localizations.dart` from the two ARB files in `lib/l10n/`.
If your IDE flags that import as missing before the first build, run:

```bash
flutter gen-l10n
```

## 2. Supabase

1. Create a project at supabase.com.
2. Run `supabase/schema.sql` in the SQL editor — creates `profiles`,
   `project_boundaries`, `observations`, the `handle_new_user` trigger, and
   all RLS policies (including the guest sandbox, seeded with a demo
   boundary).
3. Create two Storage buckets (public): `observation-photos`, `signatures`.
4. **Authentication → Providers → Email**: make sure "Email OTP" / one-time
   codes are enabled. Then **Authentication → Email Templates → Magic Link**:
   confirm the template includes `{{ .Token }}` (Supabase's default template
   already does) — that's what makes the email contain a 6-digit code
   instead of only a clickable link.
5. **Authentication → Providers → Anonymous Sign-ins**: toggle this on, or
   `signInAnonymously()` (used by the guest login button) will throw.
6. Copy your project's URL and anon key from **Settings → API**, then run:

   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
   ```

   Never commit real keys to source control — always pass them via
   `--dart-define` (locally) or repo secrets (in CI, see §3 below).

### How auth + RLS fit together

- The Flutter app never talks to Postgres directly — every call goes
  through Supabase's REST/Realtime layer, which enforces the RLS policies
  in `schema.sql` on every single row, regardless of what the client thinks
  it's allowed to do. `UserRole` in Dart (`lib/core/models/user_role.dart`)
  is UI gating only — the actual security boundary is entirely server-side.
- **Email OTP** (`AuthService.sendEmailOtp` / `verifyEmailOtp`) lets anyone
  sign in with any email, no pre-registration required. The moment
  Supabase inserts the new `auth.users` row, the `handle_new_user` trigger
  fires and creates a matching `profiles` row with `role = 'contractor'`
  — the least-privileged role. **Role can never be self-assigned from the
  client.** Promoting someone to `consultant` or `admin` (which grants
  sign-off authority and cross-project visibility) is a manual step an
  existing admin runs directly in the SQL editor:
  ```sql
  update public.profiles set role = 'consultant' where id = '<user-uuid>';
  ```
- **Guest login** (`AuthService.signInAsGuest`) creates a real, temporary
  Supabase Auth session (`auth.users.is_anonymous = true`), which the same
  trigger routes to `role = 'guest'`. RLS then confines every guest read/
  write to the single seeded `'Demo Site — Sandbox'` project — a guest can
  never see or write real site data. If you rename the demo project, update
  it in both `AppConstants.demoProjectName` (Dart) and the three
  `"observations: guests ..."` policies in `schema.sql` — they must match
  exactly or guest submissions will be silently rejected by RLS.
- Supabase also offers automatic cleanup of anonymous users that never
  convert to a permanent account after a configurable period — worth
  turning on in **Authentication** settings for a public-facing demo, since
  otherwise abandoned guest sessions accumulate indefinitely.

## 3. Building an APK via GitHub Actions

The repo ships `.github/workflows/build-apk.yml`, which builds a release
APK automatically and makes it downloadable — no local Android SDK setup
needed.

1. **Create a GitHub repo and push this project:**
   ```bash
   cd safety_core_ai
   git init
   git add .
   git commit -m "Initial commit"
   git branch -M main
   git remote add origin https://github.com/<your-username>/safety-core-ai.git
   git push -u origin main
   ```
2. **Add your Supabase credentials as repo secrets** (so the CI build can
   embed them without them ever appearing in the repo itself): on GitHub,
   go to **Settings → Secrets and variables → Actions → New repository
   secret**, and add:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
3. **Trigger the build:** pushing to `main` runs it automatically. You can
   also trigger it manually from the **Actions** tab → "Build Android APK"
   → **Run workflow**.
4. **Download the APK:** once the run finishes (green check), open that
   run in the **Actions** tab and scroll to **Artifacts** →
   `safety-core-ai-release-apk` → download. It's a zip containing
   `app-release.apk` — unzip and install it on an Android device (you may
   need to allow "install from unknown sources" since it isn't signed for
   the Play Store).

This APK is unsigned with a debug-style Gradle default key, which is fine
for internal testing/demoing but not for Play Store distribution — that
requires generating a real upload keystore and wiring it into
`android/app/build.gradle`, which isn't set up here since it's specific to
your own signing identity.

## 4. Architecture

```
lib/
  core/
    constants/app_colors.dart     Dark slate palette (#0F172A base)
    theme/app_theme.dart          Material 3 ThemeData
    models/                       Observation, UserRole
    services/
      geofence_service.dart       Ray-casting point-in-polygon (GeoJSON)
      watermark_service.dart      GPS/date/project stamp burned into pixels
      image_compressor.dart       80%+ size reduction for field photos
      pdf_report_service.dart     1-page HSE non-conformance notice
      offline_sync_service.dart   Local queue -> Supabase sync
      connectivity_service.dart   Online/offline stream
    providers.dart                Riverpod wiring for the sync singleton
  features/
    auth/                         Supabase auth + role resolution
    dashboard/                    LTIFR/TRIR KPIs, category/status charts
    observations/
      screens/new_observation_screen.dart
      screens/observation_closure_screen.dart
      widgets/sync_badge.dart
      widgets/emergency_dialog.dart
      widgets/status_chip.dart
    about/screens/about_app_screen.dart
  main.dart
supabase/schema.sql               Tables + Row Level Security policies
```

## 5. Notes on key design decisions

- **Offline queue** stores `Observation` as a flat `Map<String, dynamic>` in
  a Hive box rather than a generated `TypeAdapter`, so the project compiles
  without a `build_runner` step. Sync is keyed on a client-generated
  `local_id` (unique constraint in the schema), so retries after a partial
  failure never create duplicate rows.
- **Geofencing** implements the even-odd ray-casting rule directly against
  raw GeoJSON `Polygon`/`MultiPolygon` coordinates (remember: GeoJSON order
  is `[lng, lat]`), including hole support for irregular exclusion zones.
- **RLS** is the actual security boundary — `UserRole` client-side checks
  (e.g. `canSignOff`) are for UI gating only.
- **Emergency hotline number** in `dashboard_screen.dart` is a placeholder —
  replace `_emergencyHotline` with the live site HSE contact before deploy.
