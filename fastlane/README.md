fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android buildDebug

```sh
[bundle exec] fastlane android buildDebug
```

Builds the debug code

### android buildRelease

```sh
[bundle exec] fastlane android buildRelease
```

Builds the release code

### android test

```sh
[bundle exec] fastlane android test
```

Runs all the tests

### android internal

```sh
[bundle exec] fastlane android internal
```

Submit a new Internal Build to Play Store

### android promote_internal_to_alpha

```sh
[bundle exec] fastlane android promote_internal_to_alpha
```

Promote Internal to Alpha

### android promote_alpha_to_beta

```sh
[bundle exec] fastlane android promote_alpha_to_beta
```

Promote Alpha to Beta

### android promote_beta_to_production

```sh
[bundle exec] fastlane android promote_beta_to_production
```

Promote Beta to Production

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
