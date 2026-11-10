# ADR 0020: Android Shared UI tests through a resource-enabled AGP target

Status: Proposed for review, 2026-11-10. Tracks AND-03; extends ADR 0002.

## Problem and application change

Shared Home checks refresh admission before launching its coroutine. Two queued
callbacks can both observe a ready state and start repository work. The actual
screen regression fails on that duplicate request. Moving the check into the
coroutine places admission, current-value selection and loading in one segment
without suspension. Its repository call and typed state remain unchanged.

The real screen test covers queued duplicates, busy rejection, disabled loading
UI, completion, and an older callback refreshing with the current value. It lives
in `shared-ui-home/test@android`, with a controlled repository boundary. No new
presentation state, public API or production test hook is introduced. Cancellation
recovery and tab retention remain separate MOB-04/06 work.

## Runner and ownership

Toolchain 0.13.0's normal Android host runner omits dependency resource classes;
the screen cannot construct ComposeView because poolingcontainer's `R$id` is
missing. Existing presenter compositions do not render Android views. The
resource-enabled [AGP/Robolectric recipe](https://robolectric.org/getting-started/)
renders the actual compiled screen and reaches its duplicate-admission assertion.

`tools/android-ui-tests` is a test-only Android library target, using public AGP
APIs, built-in Kotlin and the matching Compose compiler. AGP processes the actual
AAR resources. There are no copied production sources, synthetic R classes or
changes to generated Toolchain projects. Toolchain continues to compile the app
and own its delegated Android Gradle/AGP bootstrap.

The test dependencies belong to `shared-ui-home/module.yaml`. Toolchain resolves
them, including the normal Kotlin/JUnit libraries. The input exporter supplies
the three reviewed Mobi library JARs and the complete resolved **test** runtime
as hashed file inputs. Gradle does not resolve a second app graph or maintain
another set of app dependency versions. Repositories serve AGP/compiler tools.
The report separately records production-to-test substitutions; currently,
Robolectric's Guava brings the conventional empty listenablefuture compatibility
artifact in place of production's standalone 1.0 artifact.

The app's explicit build-tools declaration records the already selected 37.0.0;
the test target reads that SDK policy instead of declaring another SDK tuple.
AGP comes from the selected Toolchain distribution's Android classpath index;
Kotlin comes from its compile records. The Gradle launcher uses the existing
repo-owned distribution/bootstrap helper (currently 9.6.1).

## Maintenance cost and review points

- The extra Gradle build definition, manifest and properties are maintained code.
  `scripts/ci/run_android_ui_tests.sh` builds/resolves inputs, invokes the target
  and preserves its logs/results. It runs inside the existing `android-test` job;
  `android-ui-test` also exposes it separately for local diagnosis.
- **The artifact exporter reads Toolchain 0.13.0 incremental records. Those are
  version-bound implementation metadata, not a documented integration API.**
  It refuses changed record versions, missing outputs, mixed compilers and an
  expanded local-module graph. This is the AND-03 test-integration accommodation.
- The supported entry always asks Toolchain to build before exporting inputs.
  The Gradle target verifies binary/test-source hashes and refuses a changed
  source set; its result requires tests to execute with no failures/skips.
  Direct Gradle invocation against old metadata is not the onboarding command.
- The staged plan lists UI sources explicitly. Only this module's Android UI
  root is routed to AGP; unknown native test roots still refuse. Static Kotlin
  formatting and analysis cover the actual module-owned test source.
- Cold tool resolution and resource processing increase test cost. This PR
  makes no hosted speed claim. It adds no timeouts, sleeps, retries, scheduler
  drains or diagnostic suppressions. The controlled queued dispatcher comes from
  the selected [Compose testing v2 API](https://developer.android.com/develop/ui/compose/testing/migrate-v2).

## Replacement and future acceptance coverage

Recheck AND-03 on Toolchain, AGP, Gradle, Compose, Robolectric, Kotlin and test-JDK
updates. When Toolchain provides resource-enabled host tests, run the **same
screen assertions** through its supported command, preserving the failing
duplicate-admission control. Qualify local/cold/relocated and hosted delivery
before deleting the extra target, exporter and source-routing exception. Keep
the UI tests and repo-owned gate.

Robolectric is replaceable. Evaluate other runners against these scenarios using
measured cold/warm wall time, CI resource use, repeatability, failure diagnostics
and platform fidelity. Annotations and Activity lifecycle fixtures may change;
behavioral assertions should survive. Component acceptance coverage does not
qualify device dialogs, actual OS delivery or iOS rendering. Broader acceptance
coverage can use this target or an appropriate instrumented/device runner.

## Evidence

The original Toolchain route passed 68 Android app tests but failed the additional
screen test before feature assertions. A local AGP control using the actual
unchanged Mobi libraries passed single-click/reentry refresh, while its queued
duplicate case failed at the intended request assertion. The maintained target
then failed the same assertion before the admission change and passed afterward.
Final staged/hosted evidence and the full diff cost belong in the implementation
PR. No signed, device, iOS component-rendering or dependency-risk clearance is
claimed by this test-target qualification.
