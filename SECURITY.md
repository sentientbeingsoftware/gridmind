# Security Policy

## Supported versions

Only the latest release receives security fixes (currently 1.0.0).

## Reporting a vulnerability

**Please do not open a public issue for a security problem.** Issues in this repository are public.

Report it privately through GitHub:

1. Open the [Security tab](https://github.com/sentientbeingsoftware/gridmind/security) of this repository.
2. Choose **Report a vulnerability**.

If you do not see that option, open a public issue titled `Security contact request` with **no details** about the problem, and a maintainer will arrange a private channel.

Please include:

- the GridMind version and platform (Android, Web, Windows, Linux, ...),
- steps to reproduce,
- what an attacker could do with it.

GridMind is maintained by Sentient Being Software LLC on a best-effort basis. There is no guaranteed response time and no bounty program.

## Scope

In scope: the app source in this repository, its build configuration, and its CI workflow.

The feedback and telemetry backend is operated separately from this repository. If you find a problem with it, report it through the same private channel.

### Known and not treated as vulnerabilities

- **The feedback and telemetry tokens are compiled into every published build** and can be extracted from the app. This is known. If you find that a token allows anything beyond submitting feedback or telemetry, please report that privately.
- **Content of public feedback issues.** Anyone can read issues, and the text in them is written by users.

## Secrets in the repository

Never commit secrets. If you find a credential, key, or token anywhere in this repository, report it privately as described above instead of opening an issue or pull request.
