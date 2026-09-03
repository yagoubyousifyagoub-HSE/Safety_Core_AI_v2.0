class AppConstants {
  AppConstants._();

  /// Every guest-authored observation is sandboxed server-side to this
  /// project name (see the "guests sandboxed to demo project" RLS policies
  /// in supabase/schema.sql). Keep this string identical to the SQL — a
  /// mismatch silently breaks guest submissions (RLS rejects the insert).
  static const String demoProjectName = 'Demo Site — Sandbox';
}
