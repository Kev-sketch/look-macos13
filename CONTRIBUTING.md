# Contributing to look

Thanks for contributing.

## Contributions and licensing

This fork does **not** use a Contributor License Agreement. Upstream's `CLA.md`
named the upstream maintainer as the grantee of a relicensing right, which does
not apply to this fork, so that file has been removed here. By opening a pull
request you confirm that you have the right to submit the work and agree that
your contribution is licensed under the project's license,
**GPL-3.0-or-later**. You keep the copyright to your own contribution.

## Before you open an issue

- search existing issues first to avoid duplicates
- use a clear title with area prefix when possible (`ui:`, `engine:`, `indexing:`, `ffi:`)
- include enough context so someone else can reproduce quickly

## Bug reports

A good bug report must include:

- expected behavior
- actual behavior
- exact reproduction steps (numbered)
- frequency (`always`, `sometimes`, `once`)
- environment details:
  - OS + version (macOS 13.x / macOS 15.x / Windows 11 24H2 / etc.)
  - look app version or commit SHA
  - install method:
    - macOS: Xcode run, Command Line Tools build (`./scripts/build-macos-clt.sh`), zip install, Homebrew
    - Windows: NSIS installer (`.exe`), or a local `make app-run` dev build
    - Linux: `.deb`, AppImage, AUR, or a local `make app-run` dev build
  - architecture (`arm64` / `x86_64` on macOS; `x64` / `ARM64` on Windows)
- logs or screenshots if available

If crash related, include:

- crash dialog text
- macOS: stack trace or Xcode console output
- Windows: contents of `%LOCALAPPDATA%\look\look-crash.log`, plus `Get-WinEvent -LogName Application -MaxEvents 10` filtered to `lookapp`
- whether it happens on clean launch

## Feature requests

Please include:

- problem statement (what pain exists today)
- proposed behavior
- alternatives considered
- impact/risk (perf, UX, safety)

User-facing feature documentation lives in `docs/` (`features.md`, `user-guide.md`) and is enough for end users and most contributors. Maintainers may also keep internal design specs under `specs/` (purpose, behavior, edge cases, non-goals); that directory is `.gitignore`d and not required reading.

## Adding a Quick Action control

Quick Actions are the interactive toggles/buttons in the launcher's right panel (e.g. Bluetooth on/off). Adding one is designed to be small: one shared descriptor, one native adapter file, one registry line. See [docs/writing-controls.md](docs/writing-controls.md) for the step-by-step guide and the reference implementation.

## Development setup

[DEVELOPMENT.md](DEVELOPMENT.md) has the full per-platform prerequisites and build walkthrough. In short: Rust stable plus GNU Make everywhere, with Xcode on macOS, Visual Studio 2022 Build Tools (Desktop C++ workload) for the Tauri app on Windows, and the WebKitGTK/GTK system libraries on Linux.

Before opening a PR, run the cross-platform checks:

```bash
cargo test --workspace --manifest-path core/Cargo.toml
cargo test --manifest-path bridge/ffi/Cargo.toml
```

If you touched the macOS shell (`apps/macos/**`) or the build scripts, also run
the Ventura / Command Line Tools build:

```bash
./scripts/build-macos-clt.sh debug
```

macOS-13-specific changes must keep the canonical Xcode 26.3 build working too.
The Swift sources have to compile under both the CLT script (which defines
`LOOK_VENTURA_SDK13`) and the Xcode project (which does not). Where the two
diverge, gate the difference on `LOOK_VENTURA_SDK13` and leave the modern path
untouched, as described in [PORTING-macos13.md](PORTING-macos13.md).

## Branch and PR flow

- `main` is the only long-lived branch; every PR targets it
- `main` must stay releasable at all times, since there is no staging branch behind it
- this fork does not cut releases: upstream's release workflows require upstream's
  signing secrets and Xcode/Nix setup, so they are gated off here and will not run

Suggested local flow:

```bash
git fetch origin
git checkout main
git pull --ff-only origin main
git checkout -b feat/short-description
```

Before opening PR:

- rebase onto latest `main`
- run local checks from the Development setup section
- ensure docs are updated when behavior changes

## Git guidelines for contributors

- always branch from `main`; do not develop directly on `main`
- keep branches short-lived and focused to reduce merge conflicts
- update your branch from `main` before requesting review:

```bash
git fetch origin
git checkout <your-branch>
git rebase origin/main
```

- if your branch is shared and you want to avoid rewriting history, merge instead of rebase:

```bash
git fetch origin
git checkout <your-branch>
git merge origin/main
```

- do not merge or cherry-pick individual `main` commits into your branch to catch up. Your PR then carries duplicate copies of commits that already exist upstream, and each one becomes a conflict. Rebase (or merge `origin/main` whole) instead
- if GitHub shows "This branch has conflicts": resolve locally, run checks, then push the resolution commit
- avoid force-pushing shared branches unless maintainers explicitly agree
- when adding limits/thresholds for safety or validation, prefer named constants over magic numbers

## CI behavior

CI runs for pushes to `main` and for pull requests targeting `main`.

- Rust jobs (`lint`, `test`, `cargo-audit`, release `build`) run only when Rust-related paths change
- secrets scanning (`gitleaks`) always runs
- the Ventura / Command Line Tools build (`build-ventura.yml`) builds the port on an
  Intel runner with `./scripts/build-macos-clt.sh`
- the upstream-only jobs are skipped in this fork (guarded by
  `github.repository_owner`): the Xcode 26.3 macOS app and release-smoke jobs, the
  linows release flows, and the Nix/Cachix workflows
- linows (Tauri) build runs when `apps/linows/**` or `core/**` changes
- release-style Rust build artifacts run only on push to `main`

## Pull request checklist

- scope is focused and minimal
- base branch is `main`
- docs updated when behavior changes
- no unrelated formatting-only changes
- tests/checks pass locally
- PR description explains why this change is needed

## Commit style

Keep commits small and descriptive.

Recommended prefixes:

- `fix:` bug fix
- `feat:` new behavior
- `docs:` documentation
- `refactor:` internal cleanup without behavior change
- `test:` tests only
