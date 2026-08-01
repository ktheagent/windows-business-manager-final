import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/database_service.dart';

class WhatsAppApiResult {
  const WhatsAppApiResult({
    required this.success,
    required this.statusCode,
    required this.providerMessageId,
    required this.providerStatus,
    required this.responseBody,
  });

  final bool success;
  final int statusCode;
  final String providerMessageId;
  final String providerStatus;
  final String responseBody;
}

class NotificationService {
  const NotificationService(this._database);

  final DatabaseService _database;

  Future<void> openWhatsApp({
    required String phone,
    required String message,
    String documentType = '',
    int? documentId,
    String defaultCountryCode = '233',
  }) async {
    final normalized = normalizeInternationalPhone(
      phone,
      defaultCountryCode: defaultCountryCode,
    );
    if (message.trim().isEmpty) {
      throw ArgumentError('WhatsApp message is required.');
    }
    final uri = Uri.https('wa.me', '/$normalized', {'text': message.trim()});
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    await _log(
      channel: 'whatsapp_web',
      recipient: normalized,
      documentType: documentType,
      documentId: documentId,
      status: opened ? 'opened' : 'failed',
      providerStatus: opened ? 'browser_opened' : 'browser_failed',
      error: opened ? '' : 'WhatsApp could not be opened.',
    );
    if (!opened) throw StateError('WhatsApp could not be opened.');
  }

  String buildDocumentMessage({
    required String customerName,
    required String documentType,
    required String documentNumber,
    required String formattedAmount,
    String dueDate = '',
    String downloadLink = '',
    String businessName = 'Airmonlink Business Manager',
  }) {
    final lines = <String>[
      'Hello ${customerName.trim().isEmpty ? 'Customer' : customerName.trim()},',
      '',
      'Your $documentType $documentNumber from $businessName is ready.',
      'Amount: $formattedAmount',
      if (dueDate.trim().isNotEmpty) 'Due date: ${dueDate.trim()}',
      if (downloadLink.trim().isNotEmpty) 'Document: ${downloadLink.trim()}',
      '',
      'Thank you.',
    ];
    return lines.join('\n');
  }

  Future<WhatsAppApiResult> sendWhatsAppTemplate({
    required Uri endpoint,
    required String accessToken,
    required String businessPhoneId,
    String accountId = '',
    required String recipient,
    required String templateName,
    String language = 'en',
    List<String> variables = const [],
    String? documentLink,
    String documentFilename = '',
    String documentType = '',
    int? documentId,
    int retries = 2,
    Duration timeout = const Duration(seconds: 45),
    String defaultCountryCode = '233',
  }) async {
    _requireHttps(endpoint, 'WhatsApp API');
    if (accessToken.trim().isEmpty ||
        businessPhoneId.trim().isEmpty ||
        templateName.trim().isEmpty) {
      throw ArgumentError(
        'WhatsApp API token, business phone ID and template are required.',
      );
    }
    final normalized = normalizeInternationalPhone(
      recipient,
      defaultCountryCode: defaultCountryCode,
    );
    final components = <Map<String, Object?>>[];
    if (variables.isNotEmpty) {
      components.add({
        'type': 'body',
        'parameters': variables
            .map((value) => {'type': 'text', 'text': value})
            .toList(growable: false),
      });
    }
    if (documentLink?.trim().isNotEmpty == true) {
      final link = Uri.tryParse(documentLink!.trim());
      if (link == null || link.scheme != 'https') {
        throw ArgumentError('WhatsApp document links must use HTTPS.');
      }
      components.insert(0, {
        'type': 'header',
        'parameters': [
          {
            'type': 'document',
            'document': {
              'link': link.toString(),
              if (documentFilename.trim().isNotEmpty)
                'filename': documentFilename.trim(),
            },
          },
        ],
      });
    }
    final payload = <String, Object?>{
      'messaging_product': 'whatsapp',
      'to': normalized,
      'type': 'template',
      'template': {
        'name': templateName.trim(),
        'language': {'code': language.trim().isEmpty ? 'en' : language.trim()},
        if (components.isNotEmpty) 'components': components,
      },
      'business_phone_id': businessPhoneId.trim(),
      if (accountId.trim().isNotEmpty) 'account_id': accountId.trim(),
    };
    Object? lastError;
    for (var attempt = 1; attempt <= retries + 1; attempt++) {
      try {
        final response = await http
            .post(
              endpoint,
              headers: {
                HttpHeaders.authorizationHeader: 'Bearer ${accessToken.trim()}',
                HttpHeaders.contentTypeHeader: 'application/json',
              },
              body: jsonEncode(payload),
            )
            .timeout(timeout);
        final decoded = _jsonMap(response.body);
        final messageId = _providerMessageId(decoded);
        final providerStatus = _providerStatus(decoded, response.statusCode);
        final success =
            response.statusCode >= 200 &&
            response.statusCode < 300 &&
            messageId.isNotEmpty;
        await _log(
          channel: 'whatsapp_api',
          recipient: normalized,
          documentType: documentType,
          documentId: documentId,
          status: success ? 'sent' : 'failed',
          providerMessageId: messageId,
          providerStatus: providerStatus,
          attempts: attempt,
          responseCode: response.statusCode,
          error: success ? '' : _providerError(decoded, response.body),
        );
        if (!success) {
          throw HttpException(
            'WhatsApp API rejected the message '
            '(${response.statusCode}): ${_providerError(decoded, response.body)}',
          );
        }
        return WhatsAppApiResult(
          success: true,
          statusCode: response.statusCode,
          providerMessageId: messageId,
          providerStatus: providerStatus,
          responseBody: response.body,
        );
      } catch (error) {
        lastError = error;
        if (attempt > retries) break;
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
    }
    throw StateError('WhatsApp delivery failed: $lastError');
  }

  Future<void> testWhatsAppApi({
    required Uri endpoint,
    required String accessToken,
    required int branchId,
    required int userId,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    _requireHttps(endpoint, 'WhatsApp API');
    try {
      final response = await http
          .get(
            endpoint,
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer ${accessToken.trim()}',
              HttpHeaders.acceptHeader: 'application/json',
            },
          )
          .timeout(timeout);
      final success = response.statusCode >= 200 && response.statusCode < 300;
      await _logIntegrationTest(
        branchId: branchId,
        userId: userId,
        type: 'whatsapp_api',
        action: 'test_connection',
        success: success,
        responseCode: response.statusCode,
        message: success ? 'Connection succeeded.' : response.body,
        endpointHost: endpoint.host,
      );
      if (!success) {
        throw HttpException(
          'WhatsApp API connection failed with status '
          '${response.statusCode}.',
        );
      }
    } catch (error) {
      await _logIntegrationTest(
        branchId: branchId,
        userId: userId,
        type: 'whatsapp_api',
        action: 'test_connection',
        success: false,
        message: error.toString(),
        endpointHost: endpoint.host,
      );
      rethrow;
    }
  }

  Future<void> sendEmail({
    required String host,
    required int port,
    required bool ssl,
    required String username,
    required String password,
    required String senderName,
    required String recipient,
    required String subject,
    required String body,
    String? attachmentPath,
    String documentType = '',
    int? documentId,
    int retries = 1,
  }) async {
    if (host.trim().isEmpty ||
        username.trim().isEmpty ||
        password.isEmpty ||
        !_isEmail(recipient)) {
      throw ArgumentError('Valid SMTP and recipient details are required.');
    }
    final server = SmtpServer(
      host.trim(),
      port: port,
      ssl: ssl,
      username: username.trim(),
      password: password,
      allowInsecure: false,
    );
    final message = Message()
      ..from = Address(username.trim(), senderName.trim())
      ..recipients.add(recipient.trim())
      ..subject = subject.trim()
      ..text = body;
    if (attachmentPath != null && attachmentPath.isNotEmpty) {
      final file = File(attachmentPath);
      if (!await file.exists()) {
        throw StateError('Email attachment was not found.');
      }
      message.attachments.add(FileAttachment(file));
    }
    Object? lastError;
    for (var attempt = 1; attempt <= retries + 1; attempt++) {
      try {
        await send(message, server);
        await _log(
          channel: 'email',
          recipient: recipient.trim(),
          documentType: documentType,
          documentId: documentId,
          status: 'sent',
          providerStatus: 'accepted',
          attempts: attempt,
          error: '',
        );
        return;
      } catch (error) {
        lastError = error;
        if (attempt > retries) {
          await _log(
            channel: 'email',
            recipient: recipient.trim(),
            documentType: documentType,
            documentId: documentId,
            status: 'failed',
            providerStatus: 'exception',
            attempts: attempt,
            error: error.toString(),
          );
          break;
        }
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
    }
    throw StateError('Email delivery failed: $lastError');
  }

  Future<void> testSmtp({
    required int branchId,
    required int userId,
    required String host,
    required int port,
    required bool ssl,
    required String username,
    required String password,
    required String senderName,
    required String recipient,
  }) async {
    try {
      await sendEmail(
        host: host,
        port: port,
        ssl: ssl,
        username: username,
        password: password,
        senderName: senderName,
        recipient: recipient,
        subject: 'Airmonlink SMTP connection test',
        body:
            'This message confirms that SMTP delivery is configured '
            'successfully.',
        retries: 0,
      );
      await _logIntegrationTest(
        branchId: branchId,
        userId: userId,
        type: 'smtp',
        action: 'test_email',
        success: true,
        message: 'Test email accepted by the SMTP server.',
        endpointHost: host.trim(),
      );
    } catch (error) {
      await _logIntegrationTest(
        branchId: branchId,
        userId: userId,
        type: 'smtp',
        action: 'test_email',
        success: false,
        message: error.toString(),
        endpointHost: host.trim(),
      );
      rethrow;
    }
  }

  static String normalizeInternationalPhone(
    String phone, {
    String defaultCountryCode = '233',
  }) {
    var normalized = phone.trim();
    if (normalized.startsWith('+')) normalized = normalized.substring(1);
    normalized = normalized.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.startsWith('00')) normalized = normalized.substring(2);
    if (normalized.startsWith('0')) {
      final country = defaultCountryCode.replaceAll(RegExp(r'[^0-9]'), '');
      normalized = '$country${normalized.substring(1)}';
    }
    if (normalized.length < 8 || normalized.length > 15) {
      throw ArgumentError('Enter a valid international phone number.');
    }
    return normalized;
  }

  Future<void> _log({
    required String channel,
    required String recipient,
    required String documentType,
    required int? documentId,
    required String status,
    String providerMessageId = '',
    String providerStatus = '',
    int attempts = 1,
    int? responseCode,
    required String error,
  }) async {
    final db = await _database.database;
    await db.insert('notification_logs', {
      'channel': channel,
      'recipient': recipient,
      'document_type': documentType,
      'document_id': documentId,
      'status': status,
      'provider_message_id': providerMessageId,
      'provider_status': providerStatus,
      'attempts': attempts,
      'response_code': responseCode,
      'error_message': error,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _logIntegrationTest({
    required int branchId,
    required int userId,
    required String type,
    required String action,
    required bool success,
    int? responseCode,
    required String message,
    required String endpointHost,
  }) async {
    final db = await _database.database;
    await db.insert('integration_test_logs', {
      'branch_id': branchId,
      'user_id': userId,
      'integration_type': type,
      'action': action,
      'success': success ? 1 : 0,
      'response_code': responseCode,
      'message': message,
      'endpoint_host': endpointHost,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static void _requireHttps(Uri endpoint, String label) {
    if (endpoint.scheme != 'https' || endpoint.host.isEmpty) {
      throw ArgumentError('$label requires a valid HTTPS endpoint.');
    }
  }

  static bool _isEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

  static Map<String, dynamic> _jsonMap(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static String _providerMessageId(Map<String, dynamic> response) {
    final messages = response['messages'];
    if (messages is List && messages.isNotEmpty && messages.first is Map) {
      return (messages.first as Map)['id']?.toString() ?? '';
    }
    return response['message_id']?.toString() ??
        response['id']?.toString() ??
        '';
  }

  static String _providerStatus(
    Map<String, dynamic> response,
    int statusCode,
  ) =>
      response['status']?.toString() ??
      (statusCode >= 200 && statusCode < 300 ? 'accepted' : 'rejected');

  static String _providerError(Map<String, dynamic> response, String fallback) {
    final error = response['error'];
    if (error is Map) {
      return error['message']?.toString() ?? error.toString();
    }
    return error?.toString() ??
        (fallback.trim().isEmpty ? 'Unknown provider error.' : fallback);
  }
}
