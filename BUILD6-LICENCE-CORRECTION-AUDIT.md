# Build 6 licence-correction audit

**Product:** Airmonlink Business Manager  
**Version:** 1.1.1+6  
**Audit date:** 2026-07-31  
**Baseline inspected:** uploaded 1.1.0+5 source

## Confirmed baseline defects

1. `LicenseService` stored trial start only in `_trialStartedAt` memory.
2. `registerTrial()` assigned `DateTime.now()` on every press.
3. Restarting without a cached paid licence silently calculated a fresh 14-day period.
4. The shell displayed “Licensed” whenever `business_name` existed.
5. The Licence page contained unconditional 14-day trial copy after paid activation.
6. The paid licence form remained open after activation.
7. The desktop model did not parse `startsAt`, `expiresAt`, `businessName` and `deviceIdentifier` returned by the installed server plugin.
8. Remote revocation or suspension was not persisted for later offline launches.

## Corrective implementation

- Added a shared `LicenseController` for shell and Licence page state.
- Added `/trial/register` client integration.
- Removed the in-memory trial clock.
- Cached server-issued trial and paid licence responses in secure storage.
- Added complete status mapping: activation required, trial, licensed, grace period, expired, suspended, revoked, deactivated and invalid.
- Hid activation inputs after paid activation.
- Added Change licence, Validate now and Deactivate licence controls.
- Added actual server-response alias parsing.
- Persisted remote restricted states to prevent offline reversion.
- Corrected installer, portable and workflow release names to build 6.
- Explicitly assigned the installed EXE icon to new Start Menu and desktop shortcuts.

## Regression tests added

- New installation requires explicit activation or trial.
- Repeated trial requests retain the original expiry.
- Restart retains the original trial expiry.
- Expired trial cannot restart.
- Paid activation replaces trial state immediately.
- Server response aliases retain expiry, device and business information.
- Revocation remains revoked offline.
- Active UI hides licence inputs and trial action.
- Trial UI cannot start another trial.
- Change licence opens inputs only on request.
- Top badge distinguishes Trial from Licensed.

## Validation completed here

- Uploaded ZIP integrity: PASS
- Complete Windows project structure: PASS
- Licence-server 1.0.1 API contract comparison: PASS
- Dart delimiter and comment/string structural scan: PASS
- Relative Dart import resolution: PASS
- YAML parsing: PASS
- Release-name consistency scan: PASS
- Secret-pattern scan: PASS

## Validation not claimed here

The delivery runtime has no Flutter SDK, Dart SDK, Visual Studio, Inno Setup or Windows runner. Therefore these remain mandatory GitHub Actions gates:

- `dart format lib test`
- `flutter analyze`
- `flutter test`
- `flutter build windows --release`
- portable ZIP generation
- installer compilation
- installed-app live activation and trial testing
