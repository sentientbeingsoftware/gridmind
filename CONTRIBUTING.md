# Contributing to GridMind

Thanks for your interest in GridMind. Bug reports, feature ideas, and pull requests are welcome.

## Before you start

- Check the [existing issues](https://github.com/sentientbeingsoftware/gridmind/issues) to avoid duplicates.
- For anything larger than a small fix, open an issue first so we can agree on the approach before you spend time on it.
- **Issues and pull requests are public.** Do not include personal information (names, email addresses, passwords, device identifiers) in them, including in screenshots and logs.
- For security problems, do **not** open an issue. Follow the [security policy](SECURITY.md).

## Setting up

1. Fork the repository and clone your fork.
2. Install the tools listed under [Prerequisites in the README](README.md#prerequisites).
3. Run `flutter pub get`.
4. Run the app with `flutter run`.

You do **not** need the feedback or telemetry tokens to contribute. Without them the app builds and runs normally. Only its calls to the feedback and telemetry backend will be rejected by the server.

## Checks that must pass

CI runs these two commands, and a pull request needs both to pass:

```bash
flutter analyze
flutter test
```

Run them locally before you open the pull request.

## Code style

- Lints come from `flutter_lints` (see `analysis_options.yaml`).
- Automatic formatting is not enforced and the existing code is not uniformly `dart format`-ed. Please do not reformat code you are not changing; it makes reviews harder.
- Line endings are LF. `.gitattributes` handles this for you.
- Add or update tests in `test/` when you change behavior.
- `kAppVersion` in `lib/app_info.dart` must match `version` in `pubspec.yaml` (a test checks this). Maintainers handle version bumps, so please leave both alone.

## Pull requests

1. Branch from `main`.
2. Keep each pull request to one topic.
3. Describe what changed and why, and link the related issue.
4. Make sure `flutter analyze` and `flutter test` pass.

## Continuous integration and secrets

The CI workflow builds with two repository secrets, `FEEDBACK_API_KEY` and `TELEMETRY_TOKEN`. GitHub does not give repository secrets to workflows triggered by pull requests from forks, so in a fork pull request those values are empty.

What that means for you:

- Analysis and tests do not use the secrets, so they run normally.
- The build steps still compile with empty values.
- A maintainer may need to approve the workflow run before it starts for a first-time contributor.
- After a pull request is merged, the build on `main` runs with the real secrets.

Never put real tokens in a pull request, a commit, or an issue.

## License

GridMind is licensed under the [Apache License 2.0](LICENSE). By submitting a contribution you agree that it is licensed under the same terms (Section 5 of the license). There is no separate contributor agreement.
