# Secrets Reference

This setup keeps secrets out of version control and materializes them only when
release-oriented jobs run.

## Android secrets

### Google Play

Use one of these:

- `GOOGLE_PLAY_JSON_KEY`: raw JSON content or a file path provided by CI
- `GOOGLE_PLAY_JSON_KEY_FILE`: local path to a materialized JSON key file

In CI, this repository usually stores `GOOGLE_PLAY_JSON_KEY` and converts it to
a file with
[`scripts/ci/write_google_play_key.sh`](../../scripts/ci/write_google_play_key.sh).

### Android signing

Use one of these for the keystore:

- `ANDROID_KEYSTORE_FILE`
- `ANDROID_KEYSTORE_BASE64`

Also set:

- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

These are turned into:

- `android-app/keystore.jks`
- `android-app/keystore.properties`

by
[`scripts/ci/write_android_signing_files.sh`](../../scripts/ci/write_android_signing_files.sh).

Debug-oriented smoke flows do not require these secrets. When
`./scripts/ci/run_job.sh android-build-debug` or
`./scripts/ci/run_job.sh android-test` runs without Android signing inputs, the
repo generates ignored local debug signing files under `android-app/` so a
clean clone can still exercise the Android smoke path. Release-oriented Android
jobs still expect the explicit signing inputs above.

### Optional Android variables

- `ANDROID_PACKAGE_NAME`: override Play package name
- `ANDROID_PLAY_RELEASE_STATUS`: defaults to `draft`

The `draft` default is helpful while a Play app is still in draft state.

## iOS secrets

Set these for archive and TestFlight flows:

- `IOS_BUNDLE_IDENTIFIER`
- `IOS_DEVELOPMENT_TEAM`
- `IOS_PROVISIONING_PROFILE_SPECIFIER`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_FILE` or `APP_STORE_CONNECT_API_KEY_BASE64`

The App Store Connect key is materialized by
[`scripts/ci/write_app_store_connect_api_key.sh`](../../scripts/ci/write_app_store_connect_api_key.sh).

Important: the Apple certificate and provisioning profile are not stored by this
repository. They must already exist on the macOS runner host that performs the
archive.

## GitHub Actions environment layout

Recommended environments:

- `play-internal`
- `play-alpha`
- `play-beta`
- `play-production`
- `ios-release`
- `testflight`

This keeps release secrets scoped to the jobs that actually need them.

Pull-request and unsigned nightly validation workflows do not reference these
environments or secrets. The manual `Mobile Release` workflow maps secrets from
the relevant environment into the existing repo-owned materialization scripts.

The nightly candidate currently uses non-production Android signing and a
code-signing-disabled iOS simulator build. Those artifacts validate release
configuration but are not releasable binaries. Build-once/promote-later nightly
delivery requires protected scheduled signing access, unique build numbers,
explicit retention, Play Internal upload, and TestFlight upload before the
candidate manifest can truthfully mark an artifact as releasable.

## Local development equivalents

You can also provide the same values locally through your shell.

Example Android local setup:

```bash
export GOOGLE_PLAY_JSON_KEY_FILE="$PWD/google_play_api_key.json"
export ANDROID_KEYSTORE_FILE="$PWD/secrets/upload-keystore.jks"
export ANDROID_KEYSTORE_PASSWORD="your-keystore-password"
export ANDROID_KEY_ALIAS="upload"
export ANDROID_KEY_PASSWORD="your-key-password"
```

Example iOS local setup:

```bash
export IOS_BUNDLE_IDENTIFIER="studio.mekate.mobi"
export IOS_DEVELOPMENT_TEAM="YOUR_TEAM_ID"
export IOS_PROVISIONING_PROFILE_SPECIFIER="YOUR_APP_STORE_PROFILE"
export APP_STORE_CONNECT_KEY_ID="YOUR_KEY_ID"
export APP_STORE_CONNECT_ISSUER_ID="YOUR_ISSUER_ID"
export APP_STORE_CONNECT_API_KEY_FILE="$PWD/fastlane/AuthKey.p8"
```

## Good sharing guidance

If you publish this setup for others, document secrets in three buckets:

- what CI stores
- what the scripts materialize at runtime
- what must already exist on the runner host

That distinction removes a lot of confusion for Android signing and iOS
provisioning.
