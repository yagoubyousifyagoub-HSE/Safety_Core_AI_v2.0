/// Roles enforced both client-side (UI gating) and server-side (Supabase RLS
/// policies in supabase/schema.sql). Never trust the client-side check alone
/// for anything that mutates data — RLS is the real gate.
///
/// Self-service sign-up (any email + OTP, or guest) always lands on
/// [UserRole.contractor] or [UserRole.guest] — see the `handle_new_user`
/// trigger in schema.sql. Elevation to [UserRole.consultant] / [UserRole.admin]
/// is a deliberate, out-of-band action taken by an existing admin; it is
/// never something the client can request for itself, because those roles
/// are what RLS trusts to grant sign-off authority and cross-project
/// visibility.
enum UserRole { consultant, contractor, admin, guest }

extension UserRoleX on UserRole {
  static UserRole fromString(String? value) {
    switch (value) {
      case 'consultant':
        return UserRole.consultant;
      case 'admin':
        return UserRole.admin;
      case 'guest':
        return UserRole.guest;
      case 'contractor':
      default:
        return UserRole.contractor;
    }
  }

  String get asString => switch (this) {
        UserRole.consultant => 'consultant',
        UserRole.contractor => 'contractor',
        UserRole.admin => 'admin',
        UserRole.guest => 'guest',
      };

  /// Consultants are the only role permitted to sign off / close observations.
  bool get canSignOff => this == UserRole.consultant || this == UserRole.admin;

  /// Contractors submit "after" remediation evidence; consultants can too.
  bool get canSubmitCorrectiveAction => true;

  /// Guests are exploring a sandboxed demo: every write they make is
  /// confined server-side to a single demo project (see schema.sql), never
  /// real site data.
  bool get isGuest => this == UserRole.guest;
}
