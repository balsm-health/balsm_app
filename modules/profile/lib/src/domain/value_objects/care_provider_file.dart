/// How a care-team attachment should be read.
enum CareFileKind {
  /// A vault-relative path. The bytes live encrypted in the user file store.
  file,

  /// An absolute `http(s)` URL the patient pasted or typed. Nothing is ever
  /// fetched — it is opened in the browser on tap.
  link;

  String get id => name;

  /// Unknown values fall back to [file]: that is what every row written before
  /// links existed holds, and misreading a link as a file is recoverable
  /// (it fails to decrypt) where the reverse would hand a vault path to a
  /// browser.
  static CareFileKind fromId(String? id) => id == link.name ? link : file;
}

/// One thing attached to a care provider: a file in the vault, or a link.
///
/// [locator] is the only address either kind has — a vault path for
/// [CareFileKind.file], an absolute URL for [CareFileKind.link] — so it is also
/// the identity used to detach one.
class CareProviderFile {
  const CareProviderFile({required this.kind, required this.locator});

  const CareProviderFile.file(this.locator) : kind = CareFileKind.file;

  const CareProviderFile.link(this.locator) : kind = CareFileKind.link;

  final CareFileKind kind;
  final String locator;

  bool get isLink => kind == CareFileKind.link;

  @override
  bool operator ==(Object other) => other is CareProviderFile && other.kind == kind && other.locator == locator;

  @override
  int get hashCode => Object.hash(kind, locator);

  @override
  String toString() => 'CareProviderFile(${kind.id}, $locator)';
}

/// Whether [value] is a link this app is willing to store and open.
///
/// `http(s)` only, and it must have a host: a `file:`, `javascript:` or
/// `data:` URL pasted into an attachment field has no business being opened
/// later, and a scheme-less string is almost always a typo.
bool isStorableLink(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasAuthority) return false;
  return uri.scheme == 'http' || uri.scheme == 'https';
}
