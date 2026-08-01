from pathlib import Path

def patch(path, old, new):
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"pattern not found in {path}: {old!r}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8", newline="\n")
    print(f"updated {path}")

patch(
    "lib/commercial/screens/commercial_suite_screen.dart",
    "pageFormats: const {'A4 landscape': PdfPageFormat.a4.landscape},",
    "pageFormats: {'A4 landscape': PdfPageFormat.a4.landscape},",
)

service = Path("lib/commercial/services/commercial_service.dart")
text = service.read_text(encoding="utf-8")
signature_old = """    required String pin,
    required StaffRole role,
  }) async {"""
signature_new = """    required String pin,
    required StaffRole role,
    bool forcePinChange = true,
  }) async {"""
if signature_old in text:
    text = text.replace(signature_old, signature_new, 1)
elif signature_new not in text:
    raise SystemExit("createStaff signature not found")
service.write_text(text, encoding="utf-8", newline="\n")
print("updated lib/commercial/services/commercial_service.dart")

notification = Path("lib/commercial/services/notification_service.dart")
text = notification.read_text(encoding="utf-8")
old = """        const sent = true;
        await _log(
          channel: 'email',
          recipient: recipient.trim(),
          documentType: documentType,
          documentId: documentId,
          status: sent ? 'sent' : 'failed',
          providerStatus: sent ? 'accepted' : 'empty_response',
          attempts: attempt,
          error: sent ? '' : 'SMTP server returned no delivery result.',
        );
        if (!sent) throw StateError('Email was not accepted by the server.');"""
new = """        await _log(
          channel: 'email',
          recipient: recipient.trim(),
          documentType: documentType,
          documentId: documentId,
          status: 'sent',
          providerStatus: 'accepted',
          attempts: attempt,
          error: '',
        );"""
if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit("SMTP result block not found")
notification.write_text(text, encoding="utf-8", newline="\n")
print("updated lib/commercial/services/notification_service.dart")
