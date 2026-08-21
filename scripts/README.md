# Roster maintenance

## `resolve-jira-ids.py`

Fills the `jiraAccountId` column in [`../docs/roster.csv`](../docs/roster.csv)
by looking each person up from their email via the Jira Cloud REST API.

**You run this locally** — it needs your Jira credentials, which it reads from
your environment (or the Reviewsson app's Keychain item on macOS) and never
prints or commits.

```bash
# 1. Create a Jira API token: https://id.atlassian.com/manage-profile/security/api-tokens
export JIRA_EMAIL="you@company.com"
export JIRA_TOKEN="your-api-token"

# 2. Preview what would change (no writes)
python3 scripts/resolve-jira-ids.py --dry-run

# 3. Fill the IDs
python3 scripts/resolve-jira-ids.py

# 4. Review the diff, then publish
git add docs/roster.csv && git commit -m "Resolve Jira account IDs" && git push
```

On macOS, if you've run the Reviewsson app at least once, you can skip the
`export` steps — the script falls back to the app's Keychain credentials
(you'll get a one-time Keychain access prompt).

Options: `--overwrite` re-resolves rows that already have an ID; `--site HOST`
targets a different Jira site; `--input PATH` points at another CSV.
