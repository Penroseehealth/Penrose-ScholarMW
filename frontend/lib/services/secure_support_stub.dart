/// Whether the platform store behind `flutter_secure_storage` can be used.
///
/// Every non-web platform ships a working keystore, so this is always true here.
/// The web implementation checks for WebCrypto instead.
bool secureStorageSupported() => true;
