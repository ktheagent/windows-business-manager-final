#!/usr/bin/env python3
"""Create a signed Airmonlink update manifest.

The private Ed25519 key must be stored outside the repository. This tool writes
only the signed manifest and never copies the key into the source tree.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
from pathlib import Path

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--private-key", required=True, type=Path)
    parser.add_argument("--installer", required=True, type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True, type=int)
    parser.add_argument("--minimum-supported-version", required=True)
    parser.add_argument("--download-url", required=True)
    parser.add_argument("--release-notes", default="")
    parser.add_argument("--mandatory", action="store_true")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--public-key-output", type=Path)
    return parser.parse_args()


def canonical_json(value: dict[str, object]) -> bytes:
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")


def main() -> int:
    args = parse_args()
    if not args.installer.is_file():
        raise SystemExit(f"Installer not found: {args.installer}")
    if not args.private_key.is_file():
        raise SystemExit(f"Private key not found: {args.private_key}")
    if not args.download_url.lower().startswith("https://"):
        raise SystemExit("The download URL must use HTTPS.")
    if args.build <= 0:
        raise SystemExit("Build must be a positive integer.")

    private_key = serialization.load_pem_private_key(
        args.private_key.read_bytes(),
        password=None,
    )
    if not isinstance(private_key, Ed25519PrivateKey):
        raise SystemExit("The supplied key is not an Ed25519 private key.")

    installer = args.installer.read_bytes()
    file_signature = private_key.sign(installer)
    signed_fields: dict[str, object] = {
        "build": args.build,
        "download_url": args.download_url,
        "file_signature": base64.b64encode(file_signature).decode("ascii"),
        "file_size": len(installer),
        "mandatory": args.mandatory,
        "minimum_supported_version": args.minimum_supported_version,
        "release_notes": args.release_notes,
        "sha256": hashlib.sha256(installer).hexdigest(),
        "version": args.version,
    }
    manifest_signature = private_key.sign(canonical_json(signed_fields))
    manifest = {
        **signed_fields,
        "manifest_signature": base64.b64encode(manifest_signature).decode("ascii"),
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    if args.public_key_output:
        public_raw = private_key.public_key().public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw,
        )
        args.public_key_output.write_text(
            base64.b64encode(public_raw).decode("ascii") + "\n",
            encoding="ascii",
        )

    print(f"Manifest: {args.output}")
    print(f"Installer SHA-256: {signed_fields['sha256']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
