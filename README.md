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
   `project_boundaries`, `observations`, and their RLS policies.
3. Create two Storage buckets (public): `observation-photos`, `signatures`.
4. Run the app with your project credentials — never commit real keys:

   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
   ```

## 3. Architecture

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

## 4. Notes on key design decisions

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
