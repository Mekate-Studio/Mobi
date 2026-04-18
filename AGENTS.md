# Mobi Agent Notes

## Purpose

`Mobi` is a standalone public reference architecture repository.

Use it to demonstrate:

- Kotlin Multiplatform mobile architecture
- explicit shared feature-state design
- native Android and iOS shells over shared Kotlin behavior
- thin CI with repo-owned scripts
- living architecture documentation grounded in runnable code

## Non-Negotiables

- `Mobi` is standalone publicly.
- Architecture readers are the primary audience.
- GitHub is the public hosting and onboarding path.
- Thin CI is preferred.
- Repo-owned scripts should carry operational behavior instead of bloating workflow YAML.
- The Gradle bridge is a current transitional constraint, not the long-term ideal.
- Public Android and iOS identity stays on `studio.mekate.mobi`.
- Do not reintroduce private repo relationships, internal-only naming, or hidden support assumptions.

## Where To Start

- Read [README.md](/Users/pragmatickeoz/StudioProjects/Mobi/README.md).
- Read [docs/reference/mobile-architecture.md](/Users/pragmatickeoz/StudioProjects/Mobi/docs/reference/mobile-architecture.md).
- Read [docs/reference/how-to-add-a-feature.md](/Users/pragmatickeoz/StudioProjects/Mobi/docs/reference/how-to-add-a-feature.md).
- For local validation, use the smoke path documented in the README and `./scripts/ci/run_job.sh`.
- When changing CI behavior, prefer adjusting repo-owned scripts under `scripts/ci/` before expanding GitHub workflow logic.

## Known Traps

- GitHub-hosted runners are cold and may expose missing tool declarations or bootstrap assumptions.
- Swift package macros may require hosted-runner-specific handling on iOS CI.
- Delegated Android Gradle bootstrap can be flaky on cold runners unless preseeded from repo-owned scripts.
- Release paths should remain separate from smoke/onboarding paths.
- Public docs should not read like an accidental copy of a private source repository.

## Working Rule

When changing `Mobi`, prefer the smallest change that improves one or more of:

- architectural clarity
- documentation quality
- the clean-clone runnable path
- public maintainability

If a change mainly serves private, product-specific, or internal operational needs, do not pull that framing into `Mobi`.
