## Context

Merged direct-default revision `2cc75fd6df31a3470fc9248847b37e7c649ddd53` retains eleven bridge inputs. Historical maintenance profiles still assume them. See proposal.md for motivation.

## Goals / Non-Goals

Goals: direct-source native and maintenance operation, exact recovery and conservative evidence. Non-goals: Swift export adoption, signed delivery, vulnerability remediation or expanded runtime support.

## Decisions

Audit each retained input before deletion. Keep Android delegated bootstrap and independent assessment tools under their own ownership rather than treating every Gradle input as iOS-only. Retire bridge profiles explicitly on direct source; preserve historical contract fixtures and read-only receipts. Current compatibility checks use the direct declarations and a new watch scope to avoid conflating historical bridge observations.

Recover complete published content from Git, including bytes and executable modes. Revision `2cc75fd` restores the immediately preceding direct default with bridge inputs; revision `349e07e0929033e8feb71269e9555420d3285e35` restores retained SKIE consumers. Prove both source identity and restored native consumers in isolated copies. Selector changes cannot restore consumers.

## Risks / Trade-offs

Inherited 17 build-tool findings remain accepted only until 2026-11-03T05:48:38Z. Removal approval does not refresh expiry. Hosted setup uncertainty remains inconclusive. Historical adapters are retained only where explicitly scoped; current callers must not silently fail because catalog inputs disappeared.

## Migration Plan

Audit callers and packaging; remove only proven inputs; adapt contracts/policy/docs; validate bridge-unavailable native and unsigned surfaces; rebuild complete retained recovery; run normal pre-commit; publish reviewable PR and collect exact hosted evidence. Leave merge to the maintainer.
