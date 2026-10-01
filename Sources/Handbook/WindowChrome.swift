import SwiftUI

// AppKit seams the window needs: a titlebar it can draw itself, a drag
// region standing in for one, and the glass the bar is made of.

/// Makes the host window's titlebar transparent so our bar reads as the titlebar, and lets
/// the window be dragged by its background.
struct WindowConfigurator: NSViewRepresentable {
    /// How far to nudge the traffic lights in from the window corner, so they sit on the
    /// bar's line rather than crowded into it.
    private static let inset = CGSize(width: 12, height: 10)

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titlebarAppearsTransparent = true
            // Deliberately NOT movable by background: that makes a drag anywhere in the page
            // move the window, so selecting text drags it instead. The bar drags the window
            // explicitly (WindowDragArea), which is the only place that should.
            window.isMovableByWindowBackground = false
            context.coordinator.apply(to: window)
            context.coordinator.observe(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var tokens: [NSObjectProtocol] = []
        /// AppKit's own origin for each button, captured once. The offset is applied against
        /// THIS, never against the button's current position — re-applying a delta on every
        /// resize and focus change walked the buttons steadily down the window until they
        /// fell out of the titlebar and stopped responding to clicks entirely.
        private var origins: [NSWindow.ButtonType: NSPoint] = [:]

        func observe(_ window: NSWindow) {
            let center = NotificationCenter.default
            for name in [NSWindow.didResizeNotification, NSWindow.didBecomeKeyNotification,
                         NSWindow.didExitFullScreenNotification] {
                tokens.append(center.addObserver(forName: name, object: window, queue: .main) { [weak self] note in
                    guard let window = note.object as? NSWindow else { return }
                    MainActor.assumeIsolated { self?.apply(to: window) }
                })
            }
        }

        @MainActor
        func apply(to window: NSWindow) {
            let types: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
            for type in types {
                guard let button = window.standardWindowButton(type),
                      let container = button.superview else { continue }
                let base = origins[type] ?? button.frame.origin
                origins[type] = base

                // Unflipped container: down means a smaller y. Clamp so the button stays
                // fully inside its container — outside it, clicks land on the view behind
                // and the window can no longer be closed.
                let wanted = container.isFlipped
                    ? base.y + WindowConfigurator.inset.height
                    : base.y - WindowConfigurator.inset.height
                let lowest: CGFloat = 1
                let highest = container.bounds.height - button.frame.height - 1
                let y = min(max(wanted, lowest), max(lowest, highest))
                button.setFrameOrigin(NSPoint(x: base.x + WindowConfigurator.inset.width, y: y))
            }
        }

        deinit { tokens.forEach(NotificationCenter.default.removeObserver) }
    }
}

/// A drag region behind the bar. `isMovableByWindowBackground` alone does not cover a view
/// that handles its own mouse events, and the title is the part people grab.
struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
        override var mouseDownCanMoveWindow: Bool { true }
    }

    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}


/// Liquid-glass capsule for the toolbar's controls: real glass on macOS 26+, and on earlier
/// systems an ultra-thin material with a light-catching rim that approximates it.
///
/// The package carries its own rather than asking the host for one — a help window should look
/// right in an app that has no glass vocabulary of its own.
extension View {
    func glassCapsule() -> some View { modifier(GlassCapsuleStyle()) }
}

extension View {
    /// The search field's capsule: flat while the field waits — a quiet fill
    /// with no glass, so it does not stand up from the bar like a button — and
    /// glass once it has the cursor, its bright rim toned down by a hairline of
    /// the bar's own ink over it.
    func searchCapsule(focused: Bool) -> some View { modifier(SearchCapsuleStyle(focused: focused)) }
}

private struct SearchCapsuleStyle: ViewModifier {
    let focused: Bool
    @Environment(\.colorScheme) private var colorScheme

    /// One structure whatever the focus: only values change. A style that
    /// swapped branches on focus rebuilt the field it wraps, which dropped the
    /// focus, which swapped the branch back — a loop that froze the window and
    /// brought it down in layout.
    func body(content: Content) -> some View {
        let ink: Color = colorScheme == .dark ? .black : .white
        if #available(macOS 26.0, *) {
            content
                // Resting: a quiet lift of the bar. Focused: a well darker than the resting
                // fill under the glass, so the field reads as sunk, not raised.
                .background(Capsule().fill(.primary.opacity(focused ? 0 : (colorScheme == .dark ? 0.06 : 0.05))))
                .background(Capsule().fill(.black.opacity(focused ? (colorScheme == .dark ? 0.32 : 0.08) : 0)))
                .glassEffect(focused ? .clear : .identity, in: Capsule())
                // Centred ON the edge, where the glass's light is: an inner border sat just
                // inside it and the bright line still showed outside.
                .overlay(Capsule().stroke(ink.opacity(focused ? 0.55 : 0), lineWidth: 2.5))
        } else {
            content
                .background(Capsule().fill(.primary.opacity(focused ? 0.1 : 0.06)))
        }
    }
}

private struct GlassCapsuleStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .background(
                    Capsule().fill(
                        Color(nsColor: .windowBackgroundColor)
                            .opacity(colorScheme == .dark ? 0.52 : 0.32)
                    )
                )
                .glassEffect(.clear, in: Capsule())
                .overlay {
                    if colorScheme == .light {
                        Capsule().strokeBorder(.black.opacity(0.10), lineWidth: 0.5)
                    }
                }
                .shadow(color: colorScheme == .light ? .black.opacity(0.10) : .clear,
                        radius: 3, y: 1)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                .overlay(Capsule().stroke(.black.opacity(0.12), lineWidth: 0.5))
        }
    }
}

/// A toolbar button that is flat at rest and stands on a glass circle only
/// while the pointer is over it — the way the toolbar buttons of a macOS 27
/// app read beside a window's own controls, where a glass capsule around every
/// button at rest is a row of pills competing with the page.
///
/// The glass is mounted only while it shows: a hidden glass pane still costs
/// its compositing on every frame.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GhostButton(configuration: configuration)
    }

    private struct GhostButton: View {
        let configuration: ButtonStyleConfiguration
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .background {
                    if hovering && isEnabled {
                        if #available(macOS 26.0, *) {
                            Circle().fill(.clear).glassEffect(.clear, in: Circle())
                        } else {
                            Circle().fill(.primary.opacity(0.08))
                        }
                    }
                }
                .opacity(configuration.isPressed ? 0.7 : 1)
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
        }
    }
}
