#!/usr/bin/env python3
"""Fill the `jiraAccountId` column in docs/roster.csv.

For every person that has an email but no Jira account ID, this looks the ID up
from the Jira Cloud REST API (`/user/search?query=<email>`) and writes it back
into the CSV.

RUN THIS YOURSELF. It needs your Jira credentials, which are read from your
environment (or the Reviewsson app's Keychain entry on macOS) and are NEVER
printed or committed.

Credentials (first match wins):
  1. Environment variables JIRA_EMAIL and JIRA_TOKEN
  2. The Reviewsson app Keychain item (service `com.reviewsson.secrets`)

Create a Jira API token at: https://id.atlassian.com/manage-profile/security/api-tokens

Usage:
    export JIRA_EMAIL="you@company.com"
    export JIRA_TOKEN="your-api-token"        # never commit this
    python3 scripts/resolve-jira-ids.py

Options:
    --site HOST     Jira site host (default: $JIRA_SITE or betssongroup.atlassian.net)
    --input PATH    CSV path (default: docs/roster.csv next to this script)
    --dry-run       Report what would change without writing the file.
    --overwrite     Re-resolve rows that already have an ID.
"""

from __future__ import annotations

import argparse
import base64
import csv
import json
import os
import ssl
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_SITE = os.environ.get("JIRA_SITE", "betssongroup.atlassian.net")
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_INPUT = os.path.normpath(os.path.join(SCRIPT_DIR, "..", "docs", "roster.csv"))
KEYCHAIN_SERVICE = "com.reviewsson.secrets"
KEYCHAIN_ACCOUNT = "credentials"


def load_credentials() -> tuple[str, str]:
    """Return (email, token) from env vars, falling back to the app Keychain."""
    email = os.environ.get("JIRA_EMAIL")
    token = os.environ.get("JIRA_TOKEN")
    if email and token:
        return email, token

    # macOS: read the Reviewsson credentials blob from the login Keychain.
    try:
        blob = subprocess.check_output(
            ["security", "find-generic-password",
             "-s", KEYCHAIN_SERVICE, "-a", KEYCHAIN_ACCOUNT, "-w"],
            stderr=subprocess.DEVNULL,
        ).decode().strip()
        data = json.loads(blob)
        email = email or data.get("email")
        token = token or data.get("apiToken")
    except Exception:
        pass

    if not email or not token:
        sys.exit(
            "Missing Jira credentials.\n"
            "Set JIRA_EMAIL and JIRA_TOKEN environment variables "
            "(create a token at https://id.atlassian.com/manage-profile/security/api-tokens),\n"
            "or run the Reviewsson app once so its Keychain item exists."
        )
    return email, token


def auth_header(email: str, token: str) -> str:
    raw = f"{email}:{token}".encode("utf-8")
    return "Basic " + base64.b64encode(raw).decode("ascii")


def make_ssl_context() -> ssl.SSLContext:
    """Verified TLS context, using certifi's CA bundle when available."""
    try:
        import certifi
        return ssl.create_default_context(cafile=certifi.where())
    except ModuleNotFoundError:
        return ssl.create_default_context()


SSL_CONTEXT = make_ssl_context()

SSL_HELP = (
    "\nTLS certificate verification failed: this Python has no CA bundle.\n"
    "Fix it once, then re-run this script:\n"
    '  open "/Applications/Python 3.13/Install Certificates.command"\n'
    "  (or: python3 -m pip install --upgrade certifi)\n"
)


def is_cert_error(err: Exception) -> bool:
    reason = getattr(err, "reason", err)
    return isinstance(reason, ssl.SSLError) and "CERTIFICATE_VERIFY_FAILED" in str(reason)


def find_account_id(site: str, header: str, email: str) -> str | None:
    url = f"https://{site}/rest/api/3/user/search?query=" + urllib.parse.quote(email)
    req = urllib.request.Request(
        url, headers={"Authorization": header, "Accept": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=20, context=SSL_CONTEXT) as resp:
        users = json.load(resp)
    if not users:
        return None
    # Prefer an exact email match when emails are visible; else the first hit.
    for user in users:
        if (user.get("emailAddress") or "").lower() == email.lower():
            return user.get("accountId")
    return users[0].get("accountId")


def main() -> None:
    parser = argparse.ArgumentParser(description="Resolve Jira account IDs into roster.csv")
    parser.add_argument("--site", default=DEFAULT_SITE)
    parser.add_argument("--input", default=DEFAULT_INPUT)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--overwrite", action="store_true")
    args = parser.parse_args()

    with open(args.input, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames or []
        rows = list(reader)

    if "jiraAccountId" not in fieldnames:
        sys.exit("roster.csv has no 'jiraAccountId' column.")
    if "email" not in fieldnames:
        sys.exit("roster.csv has no 'email' column.")

    email, token = load_credentials()
    header = auth_header(email, token)
    print(f"Resolving Jira account IDs via {args.site} as {email}\n")

    resolved = skipped = missing_email = not_found = errored = 0
    for row in rows:
        name = (row.get("name") or "").strip()
        current = (row.get("jiraAccountId") or "").strip()
        person_email = (row.get("email") or "").strip()

        if current and not args.overwrite:
            skipped += 1
            continue
        if not person_email:
            missing_email += 1
            print(f"  -  {name}: no email, skipping")
            continue

        try:
            account_id = find_account_id(args.site, header, person_email)
        except urllib.error.HTTPError as e:
            if e.code in (401, 403):
                sys.exit(f"\nJira rejected the request (HTTP {e.code}). "
                         "Check JIRA_EMAIL / JIRA_TOKEN.")
            errored += 1
            print(f"  !  {name} ({person_email}): HTTP {e.code}")
            continue
        except urllib.error.URLError as e:
            if is_cert_error(e):
                sys.exit(SSL_HELP)
            errored += 1
            print(f"  !  {name} ({person_email}): {e}")
            continue
        except Exception as e:  # noqa: BLE001 - report and continue
            errored += 1
            print(f"  !  {name} ({person_email}): {e}")
            continue

        if account_id:
            row["jiraAccountId"] = account_id
            resolved += 1
            print(f"  ✓  {name} -> {account_id}")
        else:
            not_found += 1
            print(f"  ?  {name} ({person_email}): no Jira user found")

        time.sleep(0.1)  # be gentle on the API / avoid rate limits

    print(
        f"\nResolved {resolved}, skipped {skipped} (already set), "
        f"not found {not_found}, no email {missing_email}, errors {errored}."
    )

    if args.dry_run:
        print("Dry run — no file written.")
        return
    if resolved == 0:
        print("Nothing to write.")
        return

    with open(args.input, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print(f"Updated {args.input}. Review, then commit & push to publish.")


if __name__ == "__main__":
    main()
