/// Public index doc in `phoneRegistry/{digits}` so sign-in can read role before OTP
/// without opening all `users` documents.
class PhoneRegistryEntry {
  final String uid;
  final String roleName;
  final String? displayName;

  const PhoneRegistryEntry({
    required this.uid,
    required this.roleName,
    this.displayName,
  });
}
