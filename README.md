# Kotlin Multiplatform + Amper

This repository is now an [Amper](https://www.amper.org/) project with a small
Kotlin Multiplatform setup:

- `shared`: common Compose UI and shared Kotlin logic
- `android-app`: Android application target
- `ios-app`: iOS application target

The sample app still renders a simple greeting, but the UI now comes from shared
multiplatform code instead of an Android-only XML layout.

# Project layout

```text
project.yaml
shared/
android-app/
ios-app/
```

- `project.yaml` is the Amper entrypoint for the workspace.
- Each module has its own `module.yaml`.
- The checked-in `amper` and `amper.bat` scripts are the project wrapper.

# Requirements

- JDK 17+
- Android SDK for Android builds
- Xcode for iOS builds

Amper will download additional toolchains on first build if they are missing.
In sandboxed or CI environments, set `AMPER_BOOTSTRAP_CACHE_DIR` to a writable
project-local path such as `.amper-cache`.

# Common commands

Build everything:

```bash
AMPER_BOOTSTRAP_CACHE_DIR=$PWD/.amper-cache ./amper build
```

Build just the Android app:

```bash
AMPER_BOOTSTRAP_CACHE_DIR=$PWD/.amper-cache ./amper build -m android-app -p android -v debug
```

Run tests:

```bash
AMPER_BOOTSTRAP_CACHE_DIR=$PWD/.amper-cache ./amper test -m shared -p android
```

Open or generate the iOS Xcode project:

```bash
AMPER_BOOTSTRAP_CACHE_DIR=$PWD/.amper-cache ./amper build -m ios-app
```

After the first iOS build, Amper manages `ios-app/module.xcodeproj`.

# CI and release tooling

GitLab CI and fastlane now invoke Amper instead of Gradle. They use a
project-local Amper cache (`.amper-cache`), and the Play Store lanes still
expect Android signing and Google Play credentials to be configured before
publishing will work.




# Introduction

This is a template for doing Android development using GitLab and [fastlane](https://fastlane.tools/).
It is based on the tutorial for Android apps in general that can be found [here](https://developer.android.com/training/basics/firstapp/).
If you're learning Android at the same time, you can also follow along that
tutorial and learn how to do everything all at once.

# Reference links

- [GitLab CI Documentation](https://docs.gitlab.com/ee/ci/)
- [Blog post: Android publishing with GitLab and fastlane](https://about.gitlab.com/2019/01/28/android-publishing-with-gitlab-and-fastlane/)

You'll definitely want to read through the blog post since that walks you in detail
through a working production configuration using this model.

# Getting started

First thing is to follow the [Android tutorial](https://developer.android.com/training/basics/firstapp/) and
get Android Studio installed on your machine, so you can do development using
the Android IDE. Other IDE options are possible, but not directly described or
supported here. If you're using your own IDE, it should be fairly straightforward
to convert these instructions to use with your preferred toolchain.

## What's contained in this project

### Android code

The state of this project is as if you followed the first few steps in the linked
[Android tutorial](https://developer.android.com/training/basics/firstapp/) and
have created your project. You're definitely going to want to open up the
project and change the settings to match what you plan to build. In particular,
you're at least going to want to change the following:

- Application Name: "My First App"
- Company Domain: "example.com"

### Fastlane files

It also has fastlane setup per our [blog post](https://about.gitlab.com/2019/01/28/android-publishing-with-gitlab-and-fastlane/) on
getting GitLab CI set up with fastlane. Note that you may want to update your
fastlane bundle to the latest version; if a newer version is available, the pipeline
job output will tell you.

### Dockerfile build environment

In the root there is a Dockerfile which defines a build environment which will be
used to ensure consistent and reliable builds of your Android application using
the correct Android SDK and other details you expect. Feel free to add any
build-time tools or whatever else you need here.

We generate this environment as needed because installing the Android SDK
for every pipeline run would be very slow.

### Gradle configuration

The gradle configuration is exactly as output by Android Studio except for the
version name being updated to

Instead of:

`versionName "1.0"`

It is now set to:

`versionName "1.0-${System.env.VERSION_SHA}"`

You'll want to update this for whatever versioning scheme you prefer.

### Build configuration (`.gitlab-ci.yml`)

The sample project also contains a basic `.gitlab-ci.yml` which will successfully
build the Android application.

Note that for publishing to the test channels or production, you'll need to set
up your secret API key. The stub code is here for that, but please see our
[blog post](https://about.gitlab.com/2019/01/28/android-publishing-with-gitlab-and-fastlane/) for
details on how to set this up completely. In the meantime, publishing steps will fail.

The build script also handles automatic versioning by relying on the CI pipeline
ID to generate a unique, ever increasing number. If you have a different versioning
scheme you may want to change this.

```yaml
    - "export VERSION_CODE=$(($CI_PIPELINE_IID)) && echo $VERSION_CODE"
    - "export VERSION_SHA=`echo ${CI_COMMIT_SHA:0:8}` && echo $VERSION_SHA"
```