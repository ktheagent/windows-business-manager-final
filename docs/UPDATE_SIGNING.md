# Secure update signing

Build 8 verifies both the update manifest and the downloaded installer with
Ed25519. The application contains only this public key:

```text
buDIr7eTfU7JZ8dDDQ7jw509WW3OHMyo+RWc5O9M4eI=
```

The matching private key is deliberately excluded from the repository, source
ZIP, Windows package and application.

## Release process

1. Build and validate the Windows installer.
2. Keep the private key on an offline release-signing workstation.
3. Run:

```powershell
python tool/sign_update_release.py `
  --private-key D:\Secure\Airmonlink-Update-Signing-Private-Key.pem `
  --installer dist\Airmonlink-Business-Manager-1.3.0-Build8-Setup.exe `
  --version 1.3.0 `
  --build 8 `
  --minimum-supported-version 1.3.0 `
  --download-url https://updates.example.com/Airmonlink-Business-Manager-1.3.0-Build8-Setup.exe `
  --release-notes "Build 8 premium commercial release" `
  --output dist\update-manifest.json
```

4. Upload the installer and manifest over HTTPS.
5. Never upload the private key to GitHub, cloud storage, the update server or
   the application database.
6. Back up the private key offline. Losing it requires shipping a new
   application build with a new trusted public key.

The updater rejects invalid manifest signatures, invalid installer signatures,
wrong SHA-256 values, incorrect file sizes, incomplete downloads, non-HTTPS
URLs, older versions and unsafe installer filenames.
