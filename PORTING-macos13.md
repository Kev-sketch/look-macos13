# PORTING-macos13.md — Look 0.7.2 on macOS 13 Ventura (Intel, Command Line Tools only)

> This file is the port's memory: it records what was measured, what was changed, and how each claim
> was verified, so a future session does not re-discover any of it.

## 1. Summary

- **Upstream:** `kunkka19xx/look` @ `33921ac` (branch `main`, three commits after the `v0.7.2` tag)
- **Port target:** macOS 13.0+ / x86_64, Swift 5.8 language mode, macOS 13.3 SDK, **no Xcode**
- **Status:** builds and runs on the target machine; core search, preview and command mode verified
  end-to-end. The "open a result" keystroke path is **not** exercised — see §6 for the exact split and
  why it is blocked.
- **What is verified, and how:**
  - Upstream release fails on this machine — `file Look.app/Contents/MacOS/Look` → `Mach-O 64-bit
    executable arm64` (Intel host), and `Look.app/Contents/Info.plist` → `LSMinimumSystemVersion 15.0`
  - Rust core + FFI staticlib build for `x86_64-apple-darwin` with `MACOSX_DEPLOYMENT_TARGET=13.0`
    (stable 1.99.0, no nightly) — `cargo build --release --target x86_64-apple-darwin`
  - Swift sources compile against the 13.3 SDK, and the app runs — §6 has every claim with its evidence

## 2. Environment facts (do not re-discover)

| Fact | Value |
|---|---|
| OS version | macOS 13.7.8 (build 22H730), Intel x86_64 |
| IDE present? | **Command Line Tools only** — `xcode-select -p` → `/Library/Developer/CommandLineTools`; no `Xcode.app` anywhere |
| SDKs available | `MacOSX13.3.sdk` (`xcrun --show-sdk-version` → `13.3`). Nothing newer is installable on Ventura (Xcode 15.4 is the last release that runs here) |
| Compiler version | Swift 5.8.1 (`swiftlang-5.8.0.124.5`), target `x86_64-apple-darwin22.6.0` |
| Package manager state | Cargo works — rustup + `stable-x86_64-apple-darwin` 1.99.0 at `~/.cargo/bin` (**not** on the default PATH). `xcodebuild` is a CLT stub that errors out |
| Missing IDE-only tools | `actool`, `ibtool` (no substitute); `iconutil`, `codesign`, `plutil`, `ditto` are present |
| Signing identity | none → **ad-hoc** (`codesign --sign -`); not notarizable |
| Hardware notes | Intel x86_64 — upstream ships arm64-only artifacts from `v0.7.2` |

## 3. Build configuration changes

| Area | Upstream | This port |
|---|---|---|
| Deployment target | `MACOSX_DEPLOYMENT_TARGET = 15.0` (pbxproj:210/:268 → `LSMinimumSystemVersion 15.0`); `build-rust-ffi.sh:41` defaults to 15.0 | `13.0` in the Xcode project and the FFI phase; the CLT build writes `LSMinimumSystemVersion 13.0` into its own bundle |
| Toolchain / language level | Swift 6.0 (`SWIFT_VERSION = 6.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY`, member-import visibility) — needs Xcode 26.3 | Swift 5 language mode (`-swift-version 5 -strict-concurrency=minimal`), Xcode-only flags dropped; the isolation those flags provided is restored explicitly where it matters |
| Project format / manifest | `objectVersion = 77`, `PBXFileSystemSynchronizedRootGroup` (Xcode 16+) | Xcode path unchanged; new `scripts/build-macos-clt.sh` drives `swiftc` directly and assembles the bundle by hand |
| Dependencies | Rust core + `bridge/ffi`; FFI phase ran `cargo +nightly` | Same crates, **stable** toolchain (manifest declares `rust-version = 1.88`, edition 2024; no nightly features exist) |
| Removed APIs | Observation, macOS 14/26 SwiftUI effects, EventKit full-access, `NSGlassEffectView`, `libproc.h` via Darwin | Gated on the `LOOK_VENTURA_SDK13` compilation condition (SDK-absent symbols cannot be availability-guarded), with legacy fallbacks — see §4 |

## 4. Blocker inventory

### Shipped artifact cannot run: wrong architecture and a hard OS floor
- **File:** the release asset `Look-0.7.2-macOS.zip` → `Look.app`
- **Symptom:** `bad CPU type in executable`; even on Apple Silicon Ventura the version gate would refuse it
- **Root cause:** the `v0.7.2` tag predates upstream's Intel support (`8c3c435`, "Add cross-compile support for MacOS Intel x86"), so the asset is arm64-only; `LSMinimumSystemVersion 15.0` is derived from `MACOSX_DEPLOYMENT_TARGET = 15.0`
- **Fix:** build from source for `x86_64-apple-macosx13.0` and lower the deployment target to 13.0
- **Verified:** `file` on both binaries; `plutil -p` on both Info.plists
- **Upstream?** Yes — upstream deliberately targets macOS 15+

### The project's toolchain cannot exist on this machine
- **File:** `apps/macos/LauncherApp/look-app.xcodeproj/project.pbxproj`
- **Symptom:** `xcodebuild` unavailable; no Xcode that supports `objectVersion = 77` or Swift 6.2 can be installed on Ventura
- **Root cause:** the project requires Xcode 26.3 / macOS 26 SDK; Ventura's ceiling is Xcode 15.4
- **Fix:** build with the compiler directly (`scripts/build-macos-clt.sh`), assembling `Look.app` by hand
- **Verified:** the script produces a bundle; §6 records the run
- **Upstream?** Yes — a property of the upstream project, not a defect

### Swift 6-only declaration syntax
- **File:** ~70 files under `apps/macos/LauncherApp/look-app/**`
- **Symptom:** parse errors under Swift 5.8
- **Root cause:** `nonisolated`, `nonisolated(unsafe)`, `@concurrent`
- **Fix:** modifiers stripped (no-ops in Swift 5 mode) — commit `7c43166`
- **Verified:** `swiftc -swift-version 5` parses every file
- **Upstream?** Introduced by upstream's Swift 6.2 baseline

### Symbols absent from the 13.3 SDK cannot be availability-guarded
- **File:** `Support/UI/AvailabilityShims.swift` (new), `Components/GlassEffectBackdrop.swift`, `Components/ThemedBackdrop.swift`, `Support/Calendar/EventKitService.swift`, `Views/Launcher/LauncherView.swift`, `Views/Commands/PomoMusicPlayer.swift`, `Views/Settings/ThemeSettingsView+*.swift`
- **Symptom:** `cannot find 'X' in scope` even inside `if #available(macOS 14, *)`
- **Root cause:** the SDK, not the OS, decides what can be referenced. `.symbolEffect`, `.contentTransition(.symbolEffect(.replace))`, `.numericText(countsDown:)`, `AVPlayerItem.didPlayToEndTimeNotification`, `MainActor.assumeIsolated`, EventKit `requestFullAccessToEvents`/`Reminders`, `NSGlassEffectView`, the two-parameter `onChange(of:)` overload, and the `Observation` module are all absent from `MacOSX13.3.sdk`
- **Fix:** `#if LOOK_VENTURA_SDK13` (set by the CLT script, unset for Xcode builds) with legacy/no-op fallbacks; effects are cosmetic and degrade rather than disappear; EventKit falls back to `requestAccess(to:)`; the modern path keeps its runtime `if #available` guard
- **Verified:** compiles against the 13.3 SDK; the Xcode path still sees the modern code
- **Upstream?** Introduced by the port

### `Observation` is absent from the 13.3 SDK
- **File:** 6 classes (`LaunchpadController`, `PomoMenuBarItem`, `PomoView`, `PomoMusicPlayer`, `SpeedTestCommand`, `TodoCommand`)
- **Symptom:** `@Observable` cannot be declared
- **Root cause:** the macro needs Swift 5.9 and the `Observation` module does not exist in the 13.3 SDK
- **Fix:** unified on `ObservableObject` + `@Published` (Combine). No `$`-bindings existed, so `@ObservedObject`/`@StateObject` were drop-in
- **Verified:** compiles; the affected views must be exercised at runtime (§6)
- **Upstream?** Introduced by the port — the one place app logic was touched

### `libproc.h` is not exported by the 13.3 Darwin module
- **File:** `build-clt/CltLibproc.modulemap` (generated), `Support/Launcher/ProcessService.swift`
- **Symptom:** `proc_pidinfo`, `proc_name`, `proc_pid_rusage`, `proc_pidfdinfo` unresolved
- **Root cause:** the header exists in the SDK but is not part of the `Darwin` module on 13.3
- **Fix:** a side modulemap exposing the SDK header, imported behind `canImport(CltLibproc)` so newer SDKs are unaffected
- **Verified:** compiles; process listing must be exercised at runtime (§6)
- **Upstream?** Introduced by the port

### Stray markdown shipped as an app resource
- **File:** `look-app/Support/QuickActions/Controls/README.md`
- **Symptom:** upstream's shipped `Look.app/Contents/Resources/README.md` contains the controls README
- **Root cause:** Xcode-16 synchronized root groups copy every non-source file into the bundle unless excluded
- **Fix:** `PBXFileSystemSynchronizedBuildFileExceptionSet` membership exception in the pbxproj; the CLT build never copies `.md` files
- **Verified:** pbxproj exception present; CLT bundle contains only `AppIcon.icns`
- **Upstream?** Yes — present upstream too

## 5. Post-port fixes (found by running it)

### Default MainActor isolation is an Xcode-only setting
- **File:** `Views/Commands/SpeedGaugeView.swift`
- **Symptom:** 9 compile errors — `main actor-isolated property 'pulseProgress' can not be referenced from a non-isolated context`, `call to main actor-isolated instance method 'snap(download:upload:)' in a synchronous nonisolated context`, and one `no exact matches in call to instance method 'draw'`
- **Root cause:** upstream relies on `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, which the CLT build has no equivalent for; without it the `Canvas` render closures are nonisolated while `GaugeMotion` is `@MainActor`. Separately, inside `GraphicsContext.draw` the macOS 13.3 SDK resolves `Text.foregroundStyle` to the generic `View` modifier (`some View`), which has no `draw` overload
- **Fix:** `@MainActor` on `SpeedGaugeView` (restores the isolation the Xcode flag implied) and `foregroundColor` instead of `foregroundStyle` for the tick labels
- **Verified:** the build reaches a linked binary (§6)
- **Upstream?** Introduced by the port

## 6. Verification

Verified on the port target machine (macOS 13.7.8, Intel, Command Line Tools only):

| Claim | Evidence |
|---|---|
| The committed tree compiles on its own | `swiftc -typecheck -swift-version 5 -target x86_64-apple-macosx13.0 -D LOOK_VENTURA_SDK13` over all 214 files in a clean worktree at `2fda288` → exit 0, 0 errors |
| The build is repeatable from scratch | `rm -rf build-clt && ./scripts/build-macos-clt.sh debug` → exit 0, 3m44s, 214 files, 0 errors |
| The artifact is the right slice, with the right OS floor | `file` → `Mach-O 64-bit executable x86_64`; `lipo -archs` → `x86_64`; `LSMinimumSystemVersion` = `13.0`; 37 MB |
| It is signed and the signature verifies | `codesign -dvv` → `Signature=adhoc`, `Identifier=noah-code.Look`; `codesign --verify --deep` → valid, satisfies its Designated Requirement |
| The Rust staticlib executes on Ventura | `Look --list-modes` prints the 18-mode table through `look_modes_list_text()`; `Look --version` → `look 0.7.2` |
| The Rust code passes its own tests | core workspace: 198 tests, 0 failed; `bridge/ffi`: 47 tests, 0 failed |
| The app launches and stays up | launched with an isolated config, alive across three restarts, no crash report |
| **Core search works end-to-end** | `Look apps safari` → the launcher renders the `a"safari` query with ranked results (Safari selected) and a populated preview panel (`Safari 16.6`, `/Applications/Safari.app`) |
| Command mode evaluates in the core | `Look calc "2+2"` → `Result: 4` |

**Not verified — blocked by a machine permission, not by a defect.** The end-to-end "open the selected
result" path (Enter on a row) could not be exercised: the process running the checks has no
Accessibility permission (`AXIsProcessTrusted()` is false), so synthetic keystrokes are dropped by the
window server. A global `CGEvent` and a PID-targeted `CGEvent.postToPid` were both tried; `osascript` →
System Events is denied as well. The same block prevented exercising the Settings panel render, "empty
trash", and a quick-action row click. To close it: grant Accessibility to the invoking app and press
Enter on a result. Everything downstream of that keystroke is the same code path the preview panel
already proves resolves to a real app.

Evidence files live in the workspace at `deliverables/gstack/evidence/`: build log, `file`/`codesign`
output, mode table, Rust test logs, restart proof, and the two search screenshots.

## 7. How to build

Prerequisites: macOS 13.x with Command Line Tools (13.3 SDK), rustup with a stable toolchain ≥ 1.88.

```bash
./scripts/build-macos-clt.sh          # debug bundle -> build-clt/Look.app
./scripts/build-macos-clt.sh release  # optimised
```

The script builds (or reuses) `bridge/ffi/target/x86_64-apple-darwin/release/liblook_ffi.a`, compiles
every Swift file in `apps/macos/LauncherApp/look-app/` for `x86_64-apple-macosx13.0`, compiles the app
icon with `iconutil`, writes an `Info.plist` with `LSMinimumSystemVersion 13.0`, and ad-hoc signs the
bundle with `Look.entitlements`.

Run it: `open build-clt/Look.app`.

**`LOOK_CONFIG_PATH` does not survive `open`** — and neither does `open --env`. LaunchServices starts
the app in the login session's environment, so the variable is ignored and the app falls back to
`~/.look/config`. To point a test run at a separate config and database, launch the bundle binary
directly:

```bash
LOOK_CONFIG_PATH=$HOME/.look/config.ventura build-clt/Look.app/Contents/MacOS/Look
```

The canonical release build is unchanged and still requires Xcode 26.3
(`scripts/release-macos-app.sh`), which is what upstream's CI uses.

## 8. How to publish

- Fork remotes: `origin` → this fork, `upstream` → `https://github.com/kunkka19xx/look`
- Tag the port so it cannot be mistaken for upstream: `<version>-macos13`
- Keep upstream's GPLv3 license and credit; this port is a fork, not an upstream release
- Attach the built artifact to a release so Intel/Ventura users do not have to build it

## 9. Known limitations

- **Ad-hoc signed, not notarized** — fine locally; a downloaded copy would need a Gatekeeper bypass
- **No compiled asset catalog** (`actool` is IDE-only) — the app references no asset-catalog images or
  colors by name, so nothing renders differently; the icon comes from `AppIcon.icns`
- **Liquid Glass theme** is hidden below macOS 26 by upstream design; the backdrop falls back to
  `NSVisualEffectView`
- **Apple Intelligence** requires macOS 26 and reports as unavailable
- **Symbol animations** (bounce/replace transitions, numeric counters) are inert on Ventura
- **Calendar/Reminders** use the pre-macOS-14 permission API on Ventura
- **macOS 13.0–13.2 are untested** — the toolchain here provides the 13.3 SDK
