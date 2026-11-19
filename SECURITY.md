# Security

Please report vulnerabilities privately through this repository's
[Report a vulnerability](https://github.com/micki-b/Foredeck/security/advisories/new)
page. Do not include credentials, real boat invitation codes, or precise personal
location data in public issues.

Never commit signing keys, API tokens, provisioning profiles, `.env` files, or
`Config/Local.xcconfig`. If a credential is exposed, revoke or rotate it before
attempting to remove it from Git history.

To check a working tree and its Git history using
[Gitleaks](https://github.com/gitleaks/gitleaks):

```sh
gitleaks dir . --redact
gitleaks git . --redact --log-opts=--all
```

Scans help detect accidental credentials but do not guarantee their absence.
Review staged files and commit author information before publishing.
