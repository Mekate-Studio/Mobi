## Why

The maintainer has selected Toolchain adoption followed by independent iOS bridge retirement as the priority. Both reviewed Toolchain releases inherit the known findings, so an adoption decision must record accepted residual risk rather than claim that an upgrade remediates it.

## What Changes

- Prepare the exact Toolchain 0.13.0 retained-bridge patch, matching maintenance baselines and SDK 37 onboarding.
- Propose explicit, expiring, exact-input acceptance for the ten High/Critical findings while retaining their original classifications and all seventeen findings.
- Keep the normal seven-day release-age gate unless the maintainer separately authorizes an exact early-adoption exception.
- Preserve native targets, adapters, compiler plugins, minimum OS support, quality hooks and release defaults.
- Prioritize a fresh bridge-unavailable assessment after approved adoption is integrated; direct-default switching and physical deletion retain separate decisions.

## Capabilities

### New Capabilities

- `bounded-toolchain-risk-acceptance`: manual exact-input residual-risk decision with scope, expiry, drift refusal and independent freshness/age gates.

### Modified Capabilities

None. Existing evidence collection and independent bridge-retirement requirements remain in force. The new acceptance overlay must not rewrite discovery findings or their current blocking states.

## Impact

Toolchain wrappers, Android compile SDK, compatibility/plugin baselines, public setup documentation and a separately reviewed risk-decision overlay. Production policy and dependencies remain unchanged during proposal preparation. Cold hosted, physical-device and signed-delivery limits remain explicit; no staging, commit, push, publication or new schedule is included.
