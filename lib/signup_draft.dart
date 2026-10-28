/// A signup form kept only in memory while email verification is pending.
/// Never serialize this draft: its password fields must stay off disk.
class SignupDraft {
  const SignupDraft({
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.suffix,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.birthDate,
    required this.barangay,
    required this.acceptedPolicies,
  });

  final String firstName;
  final String middleName;
  final String lastName;
  final String? suffix;
  final String email;
  final String password;
  final String confirmPassword;
  final DateTime? birthDate;
  final String barangay;
  final bool acceptedPolicies;
}

abstract final class SignupDraftStore {
  static SignupDraft? _draft;

  static void remember(SignupDraft draft) => _draft = draft;

  static SignupDraft? forEmail(String? email) {
    final draft = _draft;
    if (draft == null || email == null) return null;
    return draft.email.trim().toLowerCase() == email.trim().toLowerCase()
        ? draft
        : null;
  }

  static void clear() => _draft = null;
}
