## Why

Module graphs omit selected compiler-plugin and delegated Android build inputs. Direct bridge-retirement assessment needs invocation and resolver evidence for those surfaces, independently of an earlier module-graph or native round-trip pass.

## What Changes

- Add a manual paired `direct-build-inputs` profile using the existing isolated executor and facade experiment.
- Retain compiler telemetry, selected plugin classpath hashes and generated Android Gradle resolution evidence.
- Capture settings/project buildscript and configuration scope, variants, edges and artifact identities without modifying production inputs.
- Reuse exact-input advisory collection; mark unsupported attribution and unexecuted capabilities explicitly.
- Publish a current-tuple assessment and the next bounded retirement gate.

## Capabilities

### New Capabilities

- `direct-build-input-proof`: Source-bound compiler invocation and delegated Android graph evidence with conservative coverage and refusal behavior.

### Modified Capabilities

None.

## Impact

Compatibility adapter, evidence parsers, isolated Gradle observer, reports, contracts and public maintenance docs. No dependency adoption, builder-default change, physical bridge removal, release change, schedule, commit or push.
