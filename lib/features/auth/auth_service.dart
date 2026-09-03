import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/user_role.dart';

class AppProfile {
  final String id;
  final String fullName;
  final UserRole role;
  final String? company;

  AppProfile({required this.id, required this.fullName, required this.role, this.company});

  factory AppProfile.fromRow(Map<String, dynamic> row) => AppProfile(
        id: row['id'] as String,
        fullName: row['full_name'] as String? ?? '',
        role: UserRoleX.fromString(row['role'] as String?),
        company: row['company'] as String?,
      );
}

/// Auth is fully passwordless: any email can request a one-time 6-digit
/// verification code ([sendEmailOtp] / [verifyEmailOtp]), or a visitor can
/// explore the app via a sandboxed anonymous "guest" session
/// ([signInAsGuest]) — no signup step required for either.
///
/// New self-service accounts are always created with role = 'contractor'
/// (guests get role = 'guest') via the `handle_new_user` trigger in
/// supabase/schema.sql. This is what keeps "sign in with any email" from
/// being a privilege-escalation hole: role is what RLS trusts to grant
/// sign-off authority and cross-project visibility, so it can never be
/// self-assigned from the client.
class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;
  bool get isSignedIn => currentUser != null;
  bool get isGuestSession => currentUser?.isAnonymous ?? false;

  /// Sends a 6-digit one-time code to [email]. Supabase creates the
  /// `auth.users` row on first request (`shouldCreateUser: true`), but the
  /// session isn't established until the code is verified via
  /// [verifyEmailOtp].
  ///
  /// Requires: Supabase dashboard → Authentication → Email Templates →
  /// "Magic Link" template contains `{{ .Token }}` so the email actually
  /// carries a 6-digit code, not just a clickable link (Supabase's default
  /// template already includes it).
  Future<void> sendEmailOtp({required String email}) async {
    await _client.auth.signInWithOtp(email: email, shouldCreateUser: true);
  }

  /// Verifies the 6-digit code and completes sign-in.
  Future<void> verifyEmailOtp({required String email, required String code}) async {
    await _client.auth.verifyOTP(type: OtpType.email, email: email, token: code);
  }

  /// Anonymous "try the app" session.
  ///
  /// Requires: Supabase dashboard → Authentication → Providers → enable
  /// "Allow anonymous sign-ins". The `handle_new_user` trigger assigns
  /// role = 'guest' automatically (checking `auth.users.is_anonymous`), and
  /// RLS sandboxes every guest-created observation to a single demo project
  /// (see schema.sql).
  Future<void> signInAsGuest() async {
    await _client.auth.signInAnonymously();
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<AppProfile> fetchCurrentProfile() async {
    final uid = currentUser?.id;
    if (uid == null) {
      throw StateError('AuthService.fetchCurrentProfile called with no signed-in user.');
    }
    final row = await _client.from('profiles').select().eq('id', uid).single();
    return AppProfile.fromRow(row);
  }
}
