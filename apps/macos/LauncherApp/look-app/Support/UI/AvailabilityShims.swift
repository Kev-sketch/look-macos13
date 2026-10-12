import SwiftUI

/// SDK-availability shims for APIs that do not exist in the macOS 13.3 SDK.
///
/// Under the Xcode 26.3 path (modern SDK) these forward to the real APIs,
/// still runtime-guarded for older systems. Under the Command Line Tools /
/// Ventura path (`LOOK_VENTURA_SDK13`) the symbols do not exist in the SDK at
/// all, so the effects degrade to a no-op or their legacy equivalent. All of
/// these effects are cosmetic.
extension View {
    /// macOS 14 `.contentTransition(.symbolEffect(.replace))`.
    @ViewBuilder
    func lookSymbolReplaceTransition() -> some View {
#if LOOK_VENTURA_SDK13
        self
#else
        if #available(macOS 14.0, *) {
            self.contentTransition(.symbolEffect(.replace))
        } else {
            self
        }
#endif
    }

    /// macOS 14 `.symbolEffect(.bounce, value:)`.
    @ViewBuilder
    func lookSymbolEffectBounce(value: some Equatable) -> some View {
#if LOOK_VENTURA_SDK13
        self
#else
        if #available(macOS 14.0, *) {
            self.symbolEffect(.bounce, value: value)
        } else {
            self
        }
#endif
    }

    /// macOS 14 `.contentTransition(.numericText(countsDown: true))`; falls
    /// back to the 13.0 plain form on older SDKs/systems.
    @ViewBuilder
    func lookNumericTextCountDown() -> some View {
#if LOOK_VENTURA_SDK13
        self.contentTransition(.numericText())
#else
        if #available(macOS 14.0, *) {
            self.contentTransition(.numericText(countsDown: true))
        } else {
            self.contentTransition(.numericText())
        }
#endif
    }

    /// macOS 14 `.scrollClipDisabled()`; no-op on older SDKs/systems, which
    /// only costs the cosmetic ability of a tooltip to spill past the clip.
    @ViewBuilder
    func lookScrollClipDisabled() -> some View {
#if LOOK_VENTURA_SDK13
        self
#else
        if #available(macOS 14.0, *) {
            self.scrollClipDisabled()
        } else {
            self
        }
#endif
    }

    /// macOS 15 `.pointerStyle(.link)`; no-op on older SDKs/systems. The link
    /// cursor is cosmetic - rows stay fully clickable without it.
    @ViewBuilder
    func lookPointerStyleLink(_ isLink: Bool) -> some View {
#if LOOK_VENTURA_SDK13
        self
#else
        if #available(macOS 15.0, *) {
            self.pointerStyle(isLink ? .link : nil)
        } else {
            self
        }
#endif
    }
}
