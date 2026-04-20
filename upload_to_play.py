#!/usr/bin/env python3
"""
Upload the Flux Home release AAB to Google Play.

Usage:
    python3 upload_to_play.py --key service-account.json [--track internal]

Requirements:
    pip install google-api-python-client

Service account setup (one-time):
    1. Google Play Console → Setup → API access
    2. Link to a Google Cloud project (or create one)
    3. Create a service account → grant it "Release manager" role
    4. Download the JSON key → place next to this script (or pass via --key)
"""

import argparse
import json
import os
import sys

AAB_PATH     = "build/app/outputs/bundle/release/app-release.aab"
PACKAGE_NAME = "com.fluxhome.app"

def main():
    parser = argparse.ArgumentParser(description="Upload AAB to Google Play")
    parser.add_argument("--key",   default="service-account.json",
                        help="Path to service account JSON key (default: service-account.json)")
    parser.add_argument("--track", default="internal",
                        choices=["internal", "alpha", "beta", "production"],
                        help="Release track (default: internal)")
    args = parser.parse_args()

    # ── Validate inputs ──────────────────────────────────────────────────────
    if not os.path.exists(args.key):
        print(f"❌  Service account key not found: {args.key}")
        print("    Download it from Google Play Console → Setup → API access")
        sys.exit(1)

    if not os.path.exists(AAB_PATH):
        print(f"❌  AAB not found: {AAB_PATH}")
        print("    Run: flutter build appbundle --release")
        sys.exit(1)

    # ── Import (deferred so the error message above prints first) ────────────
    try:
        from googleapiclient.discovery import build
        from googleapiclient.http import MediaFileUpload
        from google.oauth2 import service_account
    except ImportError:
        print("❌  Missing dependency. Run:  pip install google-api-python-client google-auth")
        sys.exit(1)

    # ── Authenticate ─────────────────────────────────────────────────────────
    print(f"🔑  Loading credentials from {args.key}…")
    creds = service_account.Credentials.from_service_account_file(
        args.key,
        scopes=["https://www.googleapis.com/auth/androidpublisher"],
    )
    service = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)
    edits   = service.edits()

    # ── Open edit ────────────────────────────────────────────────────────────
    print(f"📦  Opening edit for {PACKAGE_NAME}…")
    edit = edits.insert(packageName=PACKAGE_NAME, body={}).execute()
    edit_id = edit["id"]
    print(f"    Edit ID: {edit_id}")

    # ── Upload AAB ───────────────────────────────────────────────────────────
    aab_size = os.path.getsize(AAB_PATH) / 1_048_576
    print(f"⬆   Uploading {AAB_PATH} ({aab_size:.1f} MB)…")
    media    = MediaFileUpload(AAB_PATH, mimetype="application/octet-stream", resumable=True)
    response = edits.bundles().upload(
        packageName  = PACKAGE_NAME,
        editId       = edit_id,
        media_body   = media,
    ).execute()
    version_code = response["versionCode"]
    print(f"    ✓ Uploaded — versionCode={version_code}")

    # ── Assign to track ──────────────────────────────────────────────────────
    print(f"🎯  Assigning to track: {args.track}…")
    edits.tracks().update(
        packageName = PACKAGE_NAME,
        editId      = edit_id,
        track       = args.track,
        body        = {
            "track": args.track,
            "releases": [{
                "versionCodes": [str(version_code)],
                "status": "completed",
            }],
        },
    ).execute()
    print(f"    ✓ Assigned to {args.track}")

    # ── Commit ───────────────────────────────────────────────────────────────
    print("💾  Committing edit…")
    edits.commit(packageName=PACKAGE_NAME, editId=edit_id).execute()
    print(f"\n✅  Done! v{version_code} is live on the {args.track} track.")


if __name__ == "__main__":
    main()
