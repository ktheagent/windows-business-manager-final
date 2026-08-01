import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/release_signing_key.dart';
import '../../services/database_service.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.currentBuild,
    required this.availableVersion,
    required this.availableBuild,
    required this.minimumSupportedVersion,
    required this.downloadUrl,
    required this.fileSize,
    required this.sha256,
    required this.fileSignature,
    required this.manifestSignature,
    required this.releaseNotes,
    required this.mandatory,
  });

  final String currentVersion;
  final int currentBuild;
  final String availableVersion;
  final int availableBuild;
  final String minimumSupportedVersion;
  final Uri downloadUrl;
  final int fileSize;
  final String sha256;
  final String fileSignature;
  final String manifestSignature;
  final String releaseNotes;
  final bool mandatory;

  bool get isNewer {
    final versionResult = compareVersions(availableVersion, currentVersion);
    return versionResult > 0 ||
        (versionResult == 0 && availableBuild > currentBuild);
  }

  bool get requiresUpdate =>
      mandatory || compareVersions(currentVersion, minimumSupportedVersion) < 0;

  Map<String, Object?> get signedFields => {
    'build': availableBuild,
    'download_url': downloadUrl.toString(),
    'file_signature': fileSignature,
    'file_size': fileSize,
    'mandatory': mandatory,
    'minimum_supported_version': minimumSupportedVersion,
    'release_notes': releaseNotes,
    'sha256': sha256,
    'version': availableVersion,
  };

  static int compareVersions(String left, String right) {
    final a = _versionParts(left);
    final b = _versionParts(right);
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }

  static List<int> _versionParts(String value) {
    final normalized = value.trim().split(RegExp(r'[-+]')).first;
    final parts = normalized.split('.');
    if (parts.isEmpty || parts.any((part) => int.tryParse(part) == null)) {
      throw FormatException('Invalid semantic version: $value');
    }
    return parts.map(int.parse).toList(growable: false);
  }
}

class UpdateDownloadProgress {
  const UpdateDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
    required this.attempt,
  });

  final int receivedBytes;
  final int totalBytes;
  final int attempt;

  double get fraction =>
      totalBytes <= 0 ? 0 : (receivedBytes / totalBytes).clamp(0, 1);
}

class UpdateCancelledException implements Exception {
  const UpdateCancelledException();

  @override
  String toString() => 'The update download was cancelled.';
}

class UpdateService {
  UpdateService(
    this._database, {
    http.Client? client,
    PackageInfo? packageInfo,
    String trustedPublicKeyBase64 = ReleaseSigningKey.ed25519PublicKeyBase64,
  }) : _client = client ?? http.Client(),
       _packageInfo = packageInfo,
       _trustedPublicKeyBase64 = trustedPublicKeyBase64;

  final DatabaseService _database;
  final http.Client _client;
  final PackageInfo? _packageInfo;
  final String _trustedPublicKeyBase64;

  Future<UpdateInfo> check(Uri manifestUri) async {
    _requireHttps(manifestUri, 'Update manifests');
    final response = await _client
        .get(
          manifestUri,
          headers: const {
            HttpHeaders.acceptHeader: 'application/json',
            HttpHeaders.cacheControlHeader: 'no-cache',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Update check failed with status ${response.statusCode}.',
        uri: manifestUri,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid update manifest.');
    }

    final package = _packageInfo ?? await PackageInfo.fromPlatform();
    final availableVersion = _requiredString(decoded, 'version');
    final availableBuild = _requiredPositiveInt(decoded, 'build');
    final minimumVersion = _requiredString(
      decoded,
      'minimum_supported_version',
    );
    final downloadUrl = Uri.parse(_requiredString(decoded, 'download_url'));
    final fileSize = _requiredPositiveInt(decoded, 'file_size');
    final expectedHash = _requiredString(decoded, 'sha256').toLowerCase();
    final fileSignature = _requiredString(decoded, 'file_signature');
    final manifestSignature = _requiredString(decoded, 'manifest_signature');
    final releaseNotes = decoded['release_notes'] as String? ?? '';
    final mandatory = decoded['mandatory'] as bool? ?? false;

    _requireHttps(downloadUrl, 'Update downloads');
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedHash)) {
      throw const FormatException('The update SHA-256 value is invalid.');
    }
    _validateBase64Signature(fileSignature, 'file_signature');
    _validateBase64Signature(manifestSignature, 'manifest_signature');

    final info = UpdateInfo(
      currentVersion: package.version,
      currentBuild: int.tryParse(package.buildNumber) ?? 0,
      availableVersion: availableVersion,
      availableBuild: availableBuild,
      minimumSupportedVersion: minimumVersion,
      downloadUrl: downloadUrl,
      fileSize: fileSize,
      sha256: expectedHash,
      fileSignature: fileSignature,
      manifestSignature: manifestSignature,
      releaseNotes: releaseNotes,
      mandatory: mandatory,
    );

    await _verifyManifestSignature(info);

    final db = await _database.database;
    await db.insert('update_records', {
      'current_version': info.currentVersion,
      'available_version': info.availableVersion,
      'available_build': info.availableBuild,
      'minimum_version': info.minimumSupportedVersion,
      'mandatory': info.requiresUpdate ? 1 : 0,
      'download_url': info.downloadUrl.toString(),
      'file_size': info.fileSize,
      'checksum': info.sha256,
      'file_signature': info.fileSignature,
      'manifest_signature': info.manifestSignature,
      'status': info.isNewer ? 'available' : 'current',
      'checked_at': DateTime.now().toUtc().toIso8601String(),
    });
    return info;
  }

  Future<String> download(
    UpdateInfo info, {
    void Function(UpdateDownloadProgress progress)? onProgress,
    bool Function()? shouldCancel,
    int maxAttempts = 3,
  }) async {
    if (!info.isNewer) {
      throw StateError('The installed version is already current.');
    }
    if (maxAttempts < 1 || maxAttempts > 5) {
      throw ArgumentError.value(maxAttempts, 'maxAttempts', 'Use 1 to 5.');
    }

    final temporary = await getTemporaryDirectory();
    final filename = _safeInstallerFilename(info.downloadUrl);
    final completedPath = p.join(temporary.path, filename);
    final partialPath = '$completedPath.part';
    Object? finalError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        if (shouldCancel?.call() == true) {
          throw const UpdateCancelledException();
        }

        final partialFile = File(partialPath);
        var existingBytes = await partialFile.exists()
            ? await partialFile.length()
            : 0;
        if (existingBytes > info.fileSize) {
          await partialFile.delete();
          existingBytes = 0;
        }

        final request = http.Request('GET', info.downloadUrl);
        request.headers[HttpHeaders.acceptHeader] = 'application/octet-stream';
        request.headers[HttpHeaders.cacheControlHeader] = 'no-cache';
        if (existingBytes > 0) {
          request.headers[HttpHeaders.rangeHeader] = 'bytes=$existingBytes-';
        }

        final response = await _client
            .send(request)
            .timeout(const Duration(seconds: 30));
        final isResume =
            existingBytes > 0 &&
            response.statusCode == HttpStatus.partialContent;
        if (response.statusCode != HttpStatus.ok &&
            response.statusCode != HttpStatus.partialContent) {
          throw HttpException(
            'Update download failed with status ${response.statusCode}.',
            uri: info.downloadUrl,
          );
        }

        if (!isResume && existingBytes > 0) {
          await partialFile.writeAsBytes(const [], flush: true);
          existingBytes = 0;
        }

        final sink = partialFile.openWrite(
          mode: existingBytes > 0 ? FileMode.append : FileMode.write,
        );
        var received = existingBytes;
        try {
          await for (final chunk in response.stream.timeout(
            const Duration(seconds: 45),
          )) {
            if (shouldCancel?.call() == true) {
              throw const UpdateCancelledException();
            }
            received += chunk.length;
            if (received > info.fileSize) {
              throw StateError(
                'The update download exceeded its declared file size.',
              );
            }
            sink.add(chunk);
            onProgress?.call(
              UpdateDownloadProgress(
                receivedBytes: received,
                totalBytes: info.fileSize,
                attempt: attempt,
              ),
            );
          }
        } finally {
          await sink.flush();
          await sink.close();
        }

        if (received != info.fileSize) {
          throw StateError(
            'The update download is incomplete: '
            '$received of ${info.fileSize} bytes.',
          );
        }

        final installerBytes = await partialFile.readAsBytes();
        final actualHash = sha256.convert(installerBytes).toString();
        if (actualHash.toLowerCase() != info.sha256.toLowerCase()) {
          await partialFile.delete();
          throw StateError('Update checksum verification failed.');
        }
        await _verifyFileSignature(installerBytes, info.fileSignature);

        final completedFile = File(completedPath);
        if (await completedFile.exists()) await completedFile.delete();
        await partialFile.rename(completedPath);
        await _recordDownloadStatus(info, 'verified');
        return completedPath;
      } on UpdateCancelledException {
        await _recordDownloadStatus(info, 'cancelled');
        rethrow;
      } catch (error) {
        finalError = error;
        await _recordDownloadStatus(
          info,
          attempt == maxAttempts ? 'failed' : 'retrying',
          error: '$error',
        );
        if (attempt < maxAttempts) {
          await Future<void>.delayed(Duration(seconds: attempt * 2));
        }
      }
    }

    throw StateError('Update download failed: $finalError');
  }

  Future<void> launchInstaller(String installerPath) async {
    final file = File(installerPath);
    if (!await file.exists()) {
      throw StateError('Update installer was not found.');
    }
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'Automatic installation is supported on Windows only.',
      );
    }
    final process = await Process.start(
      installerPath,
      const [],
      mode: ProcessStartMode.detached,
      runInShell: false,
    );
    if (process.pid <= 0) {
      throw StateError('The verified update installer did not start.');
    }
  }

  Future<void> _verifyManifestSignature(UpdateInfo info) async {
    final canonical = jsonEncode(
      SplayTreeMap<String, Object?>.from(info.signedFields),
    );
    await _verifySignature(
      utf8.encode(canonical),
      info.manifestSignature,
      label: 'Update manifest',
    );
  }

  Future<void> _verifyFileSignature(List<int> bytes, String signature) =>
      _verifySignature(bytes, signature, label: 'Update installer');

  Future<void> _verifySignature(
    List<int> message,
    String signatureBase64, {
    required String label,
  }) async {
    late final List<int> publicKeyBytes;
    late final List<int> signatureBytes;
    try {
      publicKeyBytes = base64Decode(_trustedPublicKeyBase64);
      signatureBytes = base64Decode(signatureBase64);
    } on FormatException {
      throw FormatException('$label signature encoding is invalid.');
    }
    if (publicKeyBytes.length != 32 || signatureBytes.length != 64) {
      throw FormatException('$label signature has an invalid length.');
    }
    final publicKey = SimplePublicKey(
      publicKeyBytes,
      type: KeyPairType.ed25519,
    );
    final valid = await Ed25519().verify(
      message,
      signature: Signature(signatureBytes, publicKey: publicKey),
    );
    if (!valid) {
      throw StateError('$label signature verification failed.');
    }
  }

  Future<void> _recordDownloadStatus(
    UpdateInfo info,
    String status, {
    String error = '',
  }) async {
    final db = await _database.database;
    await db.update(
      'update_records',
      {
        'status': status,
        'error_message': error,
        if (status == 'installed')
          'installed_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'available_version = ? AND available_build = ?',
      whereArgs: [info.availableVersion, info.availableBuild],
    );
  }

  static void _requireHttps(Uri uri, String label) {
    if (uri.scheme.toLowerCase() != 'https' || uri.host.trim().isEmpty) {
      throw ArgumentError('$label must use a valid HTTPS URL.');
    }
  }

  static String _requiredString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Update manifest field "$key" is required.');
    }
    return value.trim();
  }

  static int _requiredPositiveInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    final parsed = value is int
        ? value
        : value is num
        ? value.toInt()
        : int.tryParse('$value');
    if (parsed == null || parsed <= 0) {
      throw FormatException(
        'Update manifest field "$key" must be a positive integer.',
      );
    }
    return parsed;
  }

  static void _validateBase64Signature(String value, String key) {
    try {
      if (base64Decode(value).length != 64) {
        throw const FormatException();
      }
    } on FormatException {
      throw FormatException(
        'Update manifest field "$key" is not an Ed25519 signature.',
      );
    }
  }

  static String _safeInstallerFilename(Uri uri) {
    final basename = p.basename(uri.path);
    final candidate = basename.isEmpty
        ? 'Airmonlink-Business-Manager-Update.exe'
        : basename;
    if (!candidate.toLowerCase().endsWith('.exe') ||
        candidate.contains(RegExp(r'[\\/:*?"<>|]'))) {
      throw const FormatException(
        'The update download URL must identify a safe .exe filename.',
      );
    }
    return candidate;
  }
}
