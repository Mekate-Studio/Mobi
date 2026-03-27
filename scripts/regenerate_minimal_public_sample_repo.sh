#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

target_dir="${repo_root}/examples/minimal-public-sample-repo"
template="compose-multiplatform"
android_package="com.example.kmpci"
shared_caches_root="${AMPER_SHARED_CACHES_ROOT:-}"
generated_paths=(
  "amper"
  "amper.bat"
  "project.yaml"
  "android-app"
  "ios-app"
  "shared"
  "jvm-app"
)

purge_generated_paths() {
  local base_dir="$1"
  local path

  for path in "${generated_paths[@]}"; do
    rm -rf "${base_dir:?}/${path}"
  done
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [--output <path>] [--template <name>] [--android-package <package>] [--shared-caches-root <path>]

Regenerates the minimal public sample repo from:
  amper init compose-multiplatform

This is the maintenance script for:
  ${repo_root}/examples/minimal-public-sample-repo

Use it when a new Amper release changes the generated project layout and you
want to refresh the companion sample and the blog-post guidance from a clean
template baseline. It deletes and recreates the generated app layer before
syncing the full sample output back into place.

Defaults:
  --output ${target_dir}
  --template ${template}
  --android-package ${android_package}
  --shared-caches-root <default Amper location>
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      target_dir="${2:?Missing value for --output}"
      shift 2
      ;;
    --template)
      template="${2:?Missing value for --template}"
      shift 2
      ;;
    --android-package)
      android_package="${2:?Missing value for --android-package}"
      shift 2
      ;;
    --shared-caches-root)
      shared_caches_root="${2:?Missing value for --shared-caches-root}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/kmp-ci-sample.XXXXXX")"
generated_dir="${work_dir}/generated"

cleanup() {
  rm -rf "${work_dir}"
}

trap cleanup EXIT

mkdir -p "${generated_dir}"

printf 'Generating Amper sample with template %s...\n' "${template}"
(
  cd "${generated_dir}"
  if [[ -n "${shared_caches_root}" ]]; then
    "${repo_root}/amper" --shared-caches-root "${shared_caches_root}" init "${template}"
  else
    "${repo_root}/amper" init "${template}"
  fi
)

printf 'Trimming generated project to mobile-only layout...\n'
rm -rf \
  "${generated_dir}/jvm-app" \
  "${generated_dir}/shared/src@jvm" \
  "${generated_dir}/shared/test@jvm"

cat > "${generated_dir}/project.yaml" <<EOF
modules:
  - android-app
  - ios-app
  - shared
EOF

tmp_file="$(mktemp "${TMPDIR:-/tmp}/shared-module.XXXXXX")"
awk '
  /platforms:/ {
    gsub(/jvm, /, "", $0)
    gsub(/, jvm/, "", $0)
  }
  { print }
' "${generated_dir}/shared/module.yaml" > "${tmp_file}"
mv "${tmp_file}" "${generated_dir}/shared/module.yaml"

tmp_file="$(mktemp "${TMPDIR:-/tmp}/main-activity.XXXXXX")"
sed "s/package hello\\.world/package ${android_package//./\\.}/" \
  "${generated_dir}/android-app/src/MainActivity.kt" > "${tmp_file}"
mv "${tmp_file}" "${generated_dir}/android-app/src/MainActivity.kt"

tmp_file="$(mktemp "${TMPDIR:-/tmp}/android-manifest.XXXXXX")"
sed "s/hello\\.world\\.MainActivity/${android_package//./\\.}.MainActivity/" \
  "${generated_dir}/android-app/src/AndroidManifest.xml" > "${tmp_file}"
mv "${tmp_file}" "${generated_dir}/android-app/src/AndroidManifest.xml"

tmp_file="$(mktemp "${TMPDIR:-/tmp}/android-module.XXXXXX")"
awk -v package_name="${android_package}" '
  { print }
  /^  junit: junit-4$/ && !inserted {
    print "  android:"
    print "    namespace: " package_name
    print "    applicationId: " package_name
    print "    minSdk: 23"
    print "    compileSdk: 36"
    print "    targetSdk: 36"
    print "    # Enable this block when wiring real Android release signing for store"
    print "    # publishing. It is left disabled by default so the sample repo can run its"
    print "    # build/test CI jobs without release secrets."
    print "    # signing:"
    print "    #   enabled: true"
    print "    #   propertiesFile: ./keystore.properties"
    print "    versionCode: 1"
    print "    versionName: \"1.0-local\""
    inserted=1
  }
  END {
    if (!inserted) {
      exit 1
    }
  }
' "${generated_dir}/android-app/module.yaml" > "${tmp_file}"
mv "${tmp_file}" "${generated_dir}/android-app/module.yaml"

printf 'Overlaying shared CI files...\n'
mkdir -p \
  "${generated_dir}/.github/workflows" \
  "${generated_dir}/docs" \
  "${generated_dir}/fastlane" \
  "${generated_dir}/scripts/ci/lib" \
  "${generated_dir}/shared/src@android"

cp "${repo_root}/.github/workflows/mobile-ci.yml" "${generated_dir}/.github/workflows/mobile-ci.yml"
cp "${repo_root}/Gemfile" "${repo_root}/Gemfile.lock" "${generated_dir}/"
cp "${repo_root}/fastlane/Fastfile" "${generated_dir}/fastlane/Fastfile"
cp "${repo_root}/scripts/ci/lib.sh" "${generated_dir}/scripts/ci/lib.sh"
cp \
  "${repo_root}/scripts/ci/run_job.sh" \
  "${repo_root}/scripts/ci/apply_android_version.sh" \
  "${repo_root}/scripts/ci/build_android_aab.sh" \
  "${repo_root}/scripts/ci/run_amper_with_logs.sh" \
  "${repo_root}/scripts/ci/run_fastlane_with_amper_logs.sh" \
  "${repo_root}/scripts/ci/run_xcodebuild_with_logs.sh" \
  "${repo_root}/scripts/ci/print_recent_logs.sh" \
  "${repo_root}/scripts/ci/write_android_signing_files.sh" \
  "${repo_root}/scripts/ci/write_app_store_connect_api_key.sh" \
  "${repo_root}/scripts/ci/write_google_play_key.sh" \
  "${generated_dir}/scripts/ci/"
cp \
  "${repo_root}/scripts/ci/lib/common.sh" \
  "${repo_root}/scripts/ci/lib/context.sh" \
  "${repo_root}/scripts/ci/lib/env.sh" \
  "${repo_root}/scripts/ci/lib/android.sh" \
  "${repo_root}/scripts/ci/lib/ios.sh" \
  "${generated_dir}/scripts/ci/lib/"

cat > "${generated_dir}/scripts/regenerate_from_amper.sh" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

template="compose-multiplatform"
android_package="com.example.kmpci"
shared_caches_root="${AMPER_SHARED_CACHES_ROOT:-}"
amper_cli="${AMPER_CLI:-}"
generated_paths=(
  "amper"
  "amper.bat"
  "project.yaml"
  "android-app"
  "ios-app"
  "shared"
  "jvm-app"
)

usage() {
  cat <<EOF2
Usage: $(basename "$0") [--template <name>] [--android-package <package>] [--shared-caches-root <path>] [--amper <path>]

Deletes and regenerates the Amper-generated app layer in place while preserving
the CI overlay files that make this sample repo publishable.

This refreshes:
  amper
  amper.bat
  project.yaml
  android-app/
  ios-app/
  shared/

Defaults:
  --template ${template}
  --android-package ${android_package}
  --shared-caches-root <default Amper location>
  --amper <repo ./amper wrapper or amper from PATH>
EOF2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template)
      template="${2:?Missing value for --template}"
      shift 2
      ;;
    --android-package)
      android_package="${2:?Missing value for --android-package}"
      shift 2
      ;;
    --shared-caches-root)
      shared_caches_root="${2:?Missing value for --shared-caches-root}"
      shift 2
      ;;
    --amper)
      amper_cli="${2:?Missing value for --amper}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

resolve_amper_cli() {
  if [[ -n "${amper_cli}" ]]; then
    printf '%s\n' "${amper_cli}"
    return
  fi

  if [[ -x "${repo_root}/amper" ]]; then
    printf '%s\n' "${repo_root}/amper"
    return
  fi

  if command -v amper >/dev/null 2>&1; then
    command -v amper
    return
  fi

  printf 'Could not find an Amper CLI. Expected ./amper in the repo root or amper on PATH.\n' >&2
  exit 1
}

purge_generated_paths() {
  local base_dir="$1"
  local path

  for path in "${generated_paths[@]}"; do
    rm -rf "${base_dir:?}/${path}"
  done
}

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/kmp-ci-sample-standalone.XXXXXX")"
generated_dir="${work_dir}/generated"
amper_bin="$(resolve_amper_cli)"

cleanup() {
  rm -rf "${work_dir}"
}

trap cleanup EXIT

mkdir -p "${generated_dir}"

printf 'Generating fresh Amper project with template %s...\n' "${template}"
(
  cd "${generated_dir}"
  if [[ -n "${shared_caches_root}" ]]; then
    "${amper_bin}" --shared-caches-root "${shared_caches_root}" init "${template}"
  else
    "${amper_bin}" init "${template}"
  fi
)

printf 'Trimming generated project to mobile-only layout...\n'
rm -rf \
  "${generated_dir}/jvm-app" \
  "${generated_dir}/shared/src@jvm" \
  "${generated_dir}/shared/test@jvm"

cat > "${generated_dir}/project.yaml" <<EOF2
modules:
  - android-app
  - ios-app
  - shared
EOF2

tmp_file="$(mktemp "${TMPDIR:-/tmp}/shared-module.XXXXXX")"
awk '
  /platforms:/ {
    gsub(/jvm, /, "", $0)
    gsub(/, jvm/, "", $0)
  }
  { print }
' "${generated_dir}/shared/module.yaml" > "${tmp_file}"
mv "${tmp_file}" "${generated_dir}/shared/module.yaml"

tmp_file="$(mktemp "${TMPDIR:-/tmp}/main-activity.XXXXXX")"
sed "s/package hello\\.world/package ${android_package//./\\.}/" \
  "${generated_dir}/android-app/src/MainActivity.kt" > "${tmp_file}"
mv "${tmp_file}" "${generated_dir}/android-app/src/MainActivity.kt"

tmp_file="$(mktemp "${TMPDIR:-/tmp}/android-manifest.XXXXXX")"
sed "s/hello\\.world\\.MainActivity/${android_package//./\\.}.MainActivity/" \
  "${generated_dir}/android-app/src/AndroidManifest.xml" > "${tmp_file}"
mv "${tmp_file}" "${generated_dir}/android-app/src/AndroidManifest.xml"

tmp_file="$(mktemp "${TMPDIR:-/tmp}/android-module.XXXXXX")"
awk -v package_name="${android_package}" '
  { print }
  /^  junit: junit-4$/ && !inserted {
    print "  android:"
    print "    namespace: " package_name
    print "    applicationId: " package_name
    print "    minSdk: 23"
    print "    compileSdk: 36"
    print "    targetSdk: 36"
    print "    # Enable this block when wiring real Android release signing for store"
    print "    # publishing. It is left disabled by default so the sample repo can run its"
    print "    # build/test CI jobs without release secrets."
    print "    # signing:"
    print "    #   enabled: true"
    print "    #   propertiesFile: ./keystore.properties"
    print "    versionCode: 1"
    print "    versionName: \"1.0-local\""
    inserted=1
  }
  END {
    if (!inserted) {
      exit 1
    }
  }
' "${generated_dir}/android-app/module.yaml" > "${tmp_file}"
mv "${tmp_file}" "${generated_dir}/android-app/module.yaml"

printf 'Deleting previously generated app files...\n'
purge_generated_paths "${repo_root}"

printf 'Copying regenerated app files into %s...\n' "${repo_root}"
cp "${generated_dir}/amper" "${repo_root}/amper"
cp "${generated_dir}/amper.bat" "${repo_root}/amper.bat"
cp "${generated_dir}/project.yaml" "${repo_root}/project.yaml"
cp -R "${generated_dir}/android-app" "${repo_root}/android-app"
cp -R "${generated_dir}/ios-app" "${repo_root}/ios-app"
cp -R "${generated_dir}/shared" "${repo_root}/shared"
chmod +x "${repo_root}/amper"

cat > "${repo_root}/android-app/keystore.properties.example" <<EOF2
storeFile=./keystore.jks
storePassword=your-keystore-password
keyAlias=upload
keyPassword=your-key-password
EOF2

mkdir -p "${repo_root}/shared/src@android"
cat > "${repo_root}/shared/src@android/AndroidManifest.xml" <<EOF2
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application android:hasCode="false" />
</manifest>
EOF2

cat > "${repo_root}/shared/proguard-rules.pro" <<EOF2
# Shared Android library module currently ships no custom ProGuard rules.
EOF2

if [[ -f "${repo_root}/fastlane/Appfile" ]]; then
  tmp_file="$(mktemp "${TMPDIR:-/tmp}/appfile.XXXXXX")"
  awk -v package_name="${android_package}" '
    /^package_name\(ENV\.fetch\("ANDROID_PACKAGE_NAME", / {
      print "package_name(ENV.fetch(\"ANDROID_PACKAGE_NAME\", \"" package_name "\"))"
      replaced=1
      next
    }
    { print }
    END {
      if (!replaced) {
        exit 0
      }
    }
  ' "${repo_root}/fastlane/Appfile" > "${tmp_file}"
  mv "${tmp_file}" "${repo_root}/fastlane/Appfile"
fi

printf 'Done. Regenerated app layer in %s\n' "${repo_root}"
EOF

chmod +x "${generated_dir}/scripts/regenerate_from_amper.sh"

cat > "${generated_dir}/fastlane/Appfile" <<EOF
json_key_file(ENV.fetch("GOOGLE_PLAY_JSON_KEY_FILE", ""))
package_name(ENV.fetch("ANDROID_PACKAGE_NAME", "${android_package}"))
app_identifier(ENV.fetch("IOS_BUNDLE_IDENTIFIER", ""))
team_id(ENV.fetch("IOS_DEVELOPMENT_TEAM", "")) if ENV["IOS_DEVELOPMENT_TEAM"]
EOF

cat > "${generated_dir}/.gitignore" <<'EOF'
.DS_Store
/.gradle/
/.gradle-user-home/
/.amper/
/.amper-cache/
/build/
/android-app/build/
/ios-app/build/
/shared/build/
/fastlane/AuthKey.p8
/google_play_api_key.json
/local.properties
/.idea/
/android-app/keystore.properties
/android-app/*.jks
/android-app/*.keystore
EOF

cat > "${generated_dir}/android-app/keystore.properties.example" <<'EOF'
storeFile=./keystore.jks
storePassword=your-keystore-password
keyAlias=upload
keyPassword=your-key-password
EOF

cat > "${generated_dir}/shared/src@android/AndroidManifest.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application android:hasCode="false" />
</manifest>
EOF

cat > "${generated_dir}/shared/proguard-rules.pro" <<'EOF'
# Shared Android library module currently ships no custom ProGuard rules.
EOF

cat > "${generated_dir}/README.md" <<'EOF'
# Minimal Public Sample Repo

This repository is a minimal Kotlin Multiplatform sample for a portable mobile
CI setup built with Amper, Fastlane, and GitHub Actions.

It is intentionally small:

- `android-app/`
- `ios-app/`
- `shared/`
- `.github/workflows/mobile-ci.yml`
- `fastlane/`
- `scripts/ci/`
- `scripts/regenerate_from_amper.sh`

The app itself started from:

```bash
amper init compose-multiplatform
```

and was then trimmed down to a mobile-only shape by removing the generated JVM
module.

You can refresh the generated app layer in place with:

```bash
./scripts/regenerate_from_amper.sh
```

That script deletes and recreates the Amper-generated app layer:

- `amper`
- `amper.bat`
- `project.yaml`
- `android-app/`
- `ios-app/`
- `shared/`

while preserving the CI files and release helpers that belong to this sample.

## Purpose

This sample is not trying to show app architecture. It exists to prove that the
CI pattern is reproducible with a minimal Kotlin Multiplatform project.

For the longer explanation of the design, see
[`docs/portable-kmp-ci.md`](docs/portable-kmp-ci.md).

It exercises:

- Android debug and release builds
- Android tests
- iOS debug and release builds
- shared CI job dispatch
- runtime secret materialization for release flows

## Local smoke test

Set a writable Amper cache:

```bash
export AMPER_BOOTSTRAP_CACHE_DIR="$PWD/.amper-cache"
```

Run the shared jobs:

```bash
./scripts/ci/run_job.sh android-build-debug
./scripts/ci/run_job.sh android-test
./scripts/ci/run_job.sh android-build-release
./scripts/ci/run_job.sh ios-build-debug
```

Those jobs run `bundle install` through the shared CI helper layer, so you do
not need a separate manual Bundler step just to smoke-test the sample.

Run those smoke-test commands sequentially when using a single local checkout.
In CI they run in separate jobs, but locally multiple first-run Amper processes
can contend with each other.

`ios-build-release` is part of the sample workflow too, but on local machines it
can still depend on the host having a resolvable iPhone simulator destination.
For a portable local smoke test, `ios-build-debug` is the safer baseline check.

## Shared CI job names

These are the portable job names used by the dispatcher:

- `android-build-debug`
- `android-build-release`
- `android-test`
- `ios-build-debug`
- `ios-build-release`
- `ios-archive-release`
- `ios-testflight`
- `publish-internal`
- `promote-alpha`
- `promote-beta`
- `promote-production`

## Required GitHub secrets for release flows

### Android

- `GOOGLE_PLAY_JSON_KEY`
- `ANDROID_KEYSTORE_FILE` or `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_PACKAGE_NAME` if you change the sample package name

To use real Play publishing, also enable the commented Android `signing` block
in [`android-app/module.yaml`](android-app/module.yaml).

### iOS

- `IOS_BUNDLE_IDENTIFIER`
- `IOS_DEVELOPMENT_TEAM`
- `IOS_PROVISIONING_PROFILE_SPECIFIER`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_FILE` or `APP_STORE_CONNECT_API_KEY_BASE64`

Important: the Apple signing certificate and provisioning profile still need to
exist on the macOS runner host.
EOF

cat > "${generated_dir}/docs/portable-kmp-ci.md" <<'EOF'
# Stop Putting Your Kotlin Multiplatform CI Logic in YAML

This project did not start as an attempt to invent a "portable CI
architecture" for Kotlin Multiplatform.

It started as a practical effort to get a mobile pipeline under control.

The usual pattern showed up quickly: more logic in GitHub Actions, more
conditionals, more environment-specific behavior, more secrets handling, more
release steps, and more moments where the answer to "what does this job
actually do?" was "open the CI UI and start digging."

That works for a while, until it does not.

At some point, the YAML stops being orchestration and starts becoming the
application. Local reproduction gets harder. Migrating between CI providers
gets expensive. Debugging turns into archaeology.

The approach in this sample takes a different route: move the job contract into
the repository, and let the CI adapter stay thin.

That decision produced a Kotlin Multiplatform mobile CI setup that is easier to
run locally, easier to explain, and easier to share with other teams.

## The real problem with mobile CI

Kotlin Multiplatform mobile CI is not hard because any single step is unusual.
It is hard because too many concerns pile up in the same place:

- Android builds
- Android tests
- iOS builds
- archive and upload flows
- versioning
- signing
- store credentials
- runner-specific setup
- CI-provider-specific environment variables

When all of that gets pushed directly into YAML, the pipeline becomes tightly
coupled to the CI product that happens to be running it.

That creates a few predictable problems:

- the workflow becomes harder to read than the codebase it builds
- local debugging stops looking like CI debugging
- secrets handling gets duplicated in too many places
- switching CI providers starts to feel like a rewrite

The issue is not YAML itself. The issue is putting too much meaning into it.

## The shift that made this manageable

This setup is built around one idea:

CI should describe when a job runs, not what the job means.

Once that principle is applied, the architecture gets much simpler:

1. GitHub Actions decides when to run a job.
2. A shared repository script decides what that job means.
3. Helper scripts prepare the environment the same way everywhere.
4. Fastlane provides the build and release command layer.
5. Amper remains the actual build system.

In this sample repository, the layers look like this:

- [`.github/workflows/mobile-ci.yml`](../.github/workflows/mobile-ci.yml)
- [`scripts/ci/run_job.sh`](../scripts/ci/run_job.sh)
- [`scripts/ci/lib/`](../scripts/ci/lib)
- [`fastlane/Fastfile`](../fastlane/Fastfile)
- [`project.yaml`](../project.yaml)

The pipeline now has a stable contract that lives inside the repo.

That contract is a set of portable job names:

- `android-build-debug`
- `android-build-release`
- `android-test`
- `ios-build-debug`
- `ios-build-release`
- `ios-archive-release`
- `ios-testflight`
- `publish-internal`
- `promote-alpha`
- `promote-beta`
- `promote-production`

Those names are more valuable than they look. They give a team a shared
vocabulary. They let local development and CI talk about the same operations.
They make it obvious what belongs in the repo and what belongs in the CI
adapter.

## Start with Amper, not with a handcrafted demo app

One of the strongest parts of this workflow is that it starts from a generated
project instead of a hand-assembled example.

The Amper CLI can scaffold a strong starting point:

```bash
mkdir my-kmp-ci-app
cd my-kmp-ci-app
amper init compose-multiplatform
```

That matters because it gives readers a command they can run, not just a repo
they are supposed to copy blindly.

The generated project already includes:

- `android-app/`
- `ios-app/`
- `shared/`
- `project.yaml`
- checked-in `amper` wrappers

It also includes a `jvm-app/` module. This sample removes that module to keep
the public story focused on Android, iOS, and shared code.

This repository is that trimmed public sample.

## The sample can regenerate itself

This repo also includes a maintenance command:

```bash
./scripts/regenerate_from_amper.sh
```

That script reruns `amper init compose-multiplatform`, trims the generated
project back to Android + iOS + shared, and then reapplies the project-specific
adjustments that this CI setup expects.

It deletes and recreates the generated app layer:

- `amper`
- `amper.bat`
- `project.yaml`
- `android-app/`
- `ios-app/`
- `shared/`

while preserving the CI files and release helpers that belong to this sample.

That gives the project a much better maintenance story. When Amper changes, the
sample can be refreshed from a command instead of being rewritten by hand.

## What "thin CI" actually looks like

Once the real job logic moves into the repo, the GitHub Actions workflow gets
surprisingly boring.

That is a good thing.

A typical job becomes little more than:

```yaml
- uses: actions/checkout@v4
- uses: actions/setup-java@v4
  with:
    distribution: temurin
    java-version: "17"
- uses: ruby/setup-ruby@v1
  with:
    bundler-cache: true
- uses: android-actions/setup-android@v3
- name: Build Android debug
  run: ./scripts/ci/run_job.sh android-build-debug
```

At that point, the YAML is doing exactly what it should do:

- pick a runner
- install prerequisites
- define dependencies
- scope environments
- move artifacts around

And it is not doing a bunch of things it should not do:

- encode build logic
- normalize CI variables
- rewrite secrets into local files
- invent a second command system

That is the difference between orchestration and implementation.

## The dispatcher is where the pipeline becomes understandable

The shared entrypoint is [`scripts/ci/run_job.sh`](../scripts/ci/run_job.sh).

It answers the question every pipeline eventually needs to answer clearly:

"What does this job actually do?"

Here is the shape of it:

```bash
case "${job_name}" in
  android-build-debug)
    ci_prepare_android_job
    ./scripts/ci/run_fastlane_with_amper_logs.sh buildDebug
    ;;
  ios-testflight)
    ci_prepare_ios_testflight_job
    bundle exec fastlane ios uploadTestFlight
    ;;
esac
```

That is dramatically easier to reason about than chasing behavior across a CI
file full of conditionals, environment mappings, and inline shell.

It also means a developer can run the exact same job locally without faking an
entire CI environment.

## The helper scripts do the quiet work that usually clutters pipelines

Most of the portability comes from the helper layer under
[`scripts/ci/lib/`](../scripts/ci/lib).

That layer is responsible for:

- preparing a writable Amper cache
- setting up Java and PATH consistently
- detecting the Android SDK
- running Bundler the same way everywhere
- materializing signing files and API keys only when needed

That gives the rest of the pipeline stable concepts such as:

- `BUILD_NUMBER`
- `BUILD_SHA`
- `BUILD_BRANCH`
- `DEFAULT_BRANCH`
- `VERSION_CODE`
- `VERSION_NAME`
- `IOS_BUILD_NUMBER`

Once those values are normalized, the actual job logic stops caring whether it
is running in GitHub Actions or a local shell session.

## Separating validation from release makes the pipeline calmer

One of the best decisions in this setup is to keep normal CI validation
separate from release delivery.

For Android, that means separate jobs for:

- debug builds
- release builds
- tests
- Play internal publishing
- promotion across tracks

For iOS, it means separating:

- unsigned CI sanity builds
- signed archive generation
- TestFlight upload

That split is not just organizational neatness. It keeps normal pull request
feedback from depending on Apple signing or release credentials. It makes store
delivery something deliberate instead of something every commit has to survive.

## Secrets are materialized at runtime, not stored in the repo

This repository does not commit signing files or API keys.

Instead, release-oriented jobs materialize them at runtime through small helper
scripts:

- [`scripts/ci/write_android_signing_files.sh`](../scripts/ci/write_android_signing_files.sh)
- [`scripts/ci/write_google_play_key.sh`](../scripts/ci/write_google_play_key.sh)
- [`scripts/ci/write_app_store_connect_api_key.sh`](../scripts/ci/write_app_store_connect_api_key.sh)

There is still one unavoidable caveat on the iOS side: Apple certificates and
provisioning profiles have to exist on the macOS runner that performs the
archive. A repository can materialize API keys, but it cannot replace proper
host-level signing setup.

That is not a flaw in the design. It is just the reality of Apple delivery
workflows.

## Fastlane still makes sense here

Fastlane fits well into this arrangement because it sits at a natural boundary.

It is not trying to be the CI orchestrator. It is not trying to replace the
build system. It is simply the command layer between the repository scripts and
the platform-specific delivery steps.

That keeps the responsibilities clean:

- Amper builds the project
- Fastlane wraps build and delivery commands
- shell scripts prepare the environment
- GitHub Actions orchestrates execution

## Local reproduction stopped being an afterthought

Because the job contract lives in the repository, the same jobs can run locally
that CI runs:

```bash
export AMPER_BOOTSTRAP_CACHE_DIR="$PWD/.amper-cache"
./scripts/ci/run_job.sh android-build-debug
./scripts/ci/run_job.sh android-test
./scripts/ci/run_job.sh ios-build-debug
```

That changes debugging completely.

If a shared job works locally, then most remaining failures are usually much
narrower:

- missing secrets
- runner provisioning gaps
- artifact handoff issues
- environment scoping mistakes

That is a much better place to debug from.

## Roll it out slowly

Even with a cleaner architecture, release workflows are still release
workflows. A sensible rollout looks like this:

1. Get Android debug build working locally.
2. Get Android tests working locally.
3. Get iOS debug build working locally.
4. Move those jobs into CI.
5. Add Android release signing.
6. Publish manually to Play internal testing.
7. Add iOS archive signing on the macOS runner.
8. Upload manually to TestFlight.
9. Add promotion flows only after the basics are stable.

That order keeps the learning curve manageable and avoids conflating pipeline
design problems with store-delivery complexity.

## The part worth copying

The most useful thing here is not a specific Actions feature, a specific
Fastlane lane, or a specific Amper command.

It is the decision to stop treating the CI provider as the home of the build
logic.

Once the job contract moved into the repository, a lot of problems got smaller:

- the pipeline became easier to explain
- local reproduction became normal
- provider migration became less scary
- secrets handling became clearer
- documentation became much easier to write

That is the part worth copying.

Not the exact YAML. Not the exact project structure. Not the exact runner
label.

The idea.

Let CI orchestrate. Let the repository define the jobs.

That shift makes a Kotlin Multiplatform CI setup feel less like a collection of
fragile automation and more like an actual system that can be understood,
debugged, and shared.

If the practical reproduction steps are the priority, start with the
[README](../README.md). If the practical maintenance story is the priority,
start with [`./scripts/regenerate_from_amper.sh`](../scripts/regenerate_from_amper.sh).
EOF

printf 'Writing regenerated sample to %s...\n' "${target_dir}"
mkdir -p "${target_dir}"
printf 'Deleting previously generated app files in %s...\n' "${target_dir}"
purge_generated_paths "${target_dir}"
rsync -a --delete --exclude '.git/' "${generated_dir}/" "${target_dir}/"

printf 'Done. Regenerated sample repo at %s\n' "${target_dir}"
