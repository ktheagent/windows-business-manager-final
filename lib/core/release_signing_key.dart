abstract final class ReleaseSigningKey {
  /// Ed25519 public key used to verify update manifests and installers.
  ///
  /// The matching private key is intentionally excluded from the application
  /// and repository. It must be stored offline by the release owner.
  static const ed25519PublicKeyBase64 =
      'buDIr7eTfU7JZ8dDDQ7jw509WW3OHMyo+RWc5O9M4eI=';
}
