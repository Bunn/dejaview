import SwiftUI
import UIKit

/// Renders the remote framebuffer into a CALayer and maps touches
/// to VNC pointer events.
///
/// One finger (see `RemoteTouchMode`):
/// - direct:   tap = click where you touch, drag = click-drag (absolute)
/// - trackpad: drag moves the cursor from where it is, tap = click at the
///             cursor, long-press then drag = click-drag (relative)
///
/// Two fingers (both modes):
/// - two-finger tap / trackpad secondary tap = right click
/// - two-finger drag = scroll wheel (natural direction)
/// - pinch = zoom the visible stream
///
/// When follow-cursor is enabled, zoomed trackpad/hover cursor movement
/// recenters the visible stream around the remote cursor.
struct RemoteDesktopView<Session: RemoteSessionControlling>: UIViewRepresentable {
    @ObservedObject var session: Session
    @Binding var zoomScale: CGFloat
    var followsCursor: Bool

    func makeUIView(context: Context) -> ScreenView {
        let view = ScreenView()
        view.session = session
        view.onZoomScaleChanged = context.coordinator.setZoomScale(_:)
        Task { @MainActor in
            view.becomeFirstResponder()
        }
        return view
    }

    func updateUIView(_ uiView: ScreenView, context: Context) {
        context.coordinator.zoomScale = $zoomScale
        uiView.session = session
        uiView.display(image: session.image)
        uiView.setZoomScale(zoomScale, notify: false)
        uiView.setFollowsCursor(followsCursor)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(zoomScale: $zoomScale)
    }

    final class Coordinator {
        var zoomScale: Binding<CGFloat>

        init(zoomScale: Binding<CGFloat>) {
            self.zoomScale = zoomScale
        }

        @MainActor
        func setZoomScale(_ zoomScale: CGFloat) {
            self.zoomScale.wrappedValue = zoomScale
        }
    }

    final class ScreenView: UIView, UIGestureRecognizerDelegate {
        weak var session: (any RemoteSessionInputControlling)?
        var onZoomScaleChanged: ((CGFloat) -> Void)?

        private var imageSize: CGSize = .zero
        private let imageLayer = CALayer()
        private weak var pointerScrollPan: UIPanGestureRecognizer?

        private var zoomScale: CGFloat = 1
        private var followsCursor = true
        private var viewportCenter: CGPoint?
        private var pinchStartZoomScale: CGFloat = 1

        // Single-touch state
        private var lastTouchLocation: CGPoint = .zero
        private var touchStartTime: TimeInterval = 0
        private var touchMoved = false
        private var isDragging = false
        private var multiTouchActive = false
        private var longPressWork: DispatchWorkItem?

        // Direct-mode deferred press (avoids a stray left click when the
        // first finger of a two-finger gesture lands slightly early).
        private var pendingPressWork: DispatchWorkItem?
        private var pendingPressPoint: CGPoint?
        private var directPressed = false

        // Scroll state
        private var touchScrollAccumulator = CGPoint.zero
        private var pointerScrollAccumulator = CGPoint.zero

        private let tapMovementThreshold: CGFloat = 8
        private let tapDurationThreshold: TimeInterval = 0.35
        private let longPressDelay: TimeInterval = 0.5
        private let pressDebounce: TimeInterval = 0.05
        private let minimumZoomScale: CGFloat = 1
        private let maximumZoomScale: CGFloat = 4

        /// Points of finger travel per wheel step. Wheel steps only move a
        /// few lines each on macOS, so this needs to be small — and it acts
        /// as a sensitivity dial (lower = faster scrolling).
        private let scrollStep: CGFloat = 4

        override var canBecomeFirstResponder: Bool {
            true
        }

        override init(frame: CGRect) {
            super.init(frame: frame)

            backgroundColor = .black
            clipsToBounds = true
            imageLayer.contentsGravity = .resize
            imageLayer.magnificationFilter = .linear
            imageLayer.minificationFilter = .linear
            layer.addSublayer(imageLayer)
            isMultipleTouchEnabled = true

            let pinch = UIPinchGestureRecognizer(target: self,
                                                 action: #selector(handlePinch(_:)))
            addGestureRecognizer(pinch)

            let twoFingerTap = UITapGestureRecognizer(target: self,
                                                      action: #selector(handleTwoFingerTap(_:)))
            twoFingerTap.numberOfTouchesRequired = 2
            addGestureRecognizer(twoFingerTap)

            let pointerSecondaryTap = UITapGestureRecognizer(target: self,
                                                             action: #selector(handlePointerSecondaryTap(_:)))
            pointerSecondaryTap.allowedTouchTypes = [
                NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)
            ]
            pointerSecondaryTap.buttonMaskRequired = .secondary
            addGestureRecognizer(pointerSecondaryTap)

            let twoFingerPan = UIPanGestureRecognizer(target: self,
                                                      action: #selector(handleTwoFingerPan(_:)))
            twoFingerPan.minimumNumberOfTouches = 2
            twoFingerPan.maximumNumberOfTouches = 2
            addGestureRecognizer(twoFingerPan)

            let pointerHover = UIHoverGestureRecognizer(target: self,
                                                        action: #selector(handlePointerHover(_:)))
            addGestureRecognizer(pointerHover)

            let pointerScrollPan = UIPanGestureRecognizer(target: self,
                                                          action: #selector(handlePointerScroll(_:)))
            pointerScrollPan.allowedScrollTypesMask = .all
            pointerScrollPan.delegate = self
            addGestureRecognizer(pointerScrollPan)
            self.pointerScrollPan = pointerScrollPan
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            updateImageLayerFrame()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()

            if window != nil {
                becomeFirstResponder()
            }
        }

        func display(image: CGImage?) {
            imageLayer.contents = image

            if let image {
                imageSize = CGSize(width: image.width, height: image.height)
                if viewportCenter == nil {
                    viewportCenter = CGPoint(x: imageSize.width / 2,
                                             y: imageSize.height / 2)
                }
            }

            updateImageLayerFrame()
        }

        func setZoomScale(_ newZoomScale: CGFloat, notify: Bool) {
            let clamped = clampedZoomScale(newZoomScale)
            guard clamped != zoomScale else { return }

            let anchor = followsCursor ? nil : CGPoint(x: bounds.midX, y: bounds.midY)
            setZoomScale(clamped, anchorInView: anchor, notify: notify)
        }

        func setFollowsCursor(_ newValue: Bool) {
            let changed = followsCursor != newValue
            followsCursor = newValue

            if changed {
                followCursorIfNeeded()
            }
        }

        // MARK: - Coordinate mapping

        private var renderScale: CGFloat {
            guard imageSize.width > 0, imageSize.height > 0,
                  bounds.width > 0, bounds.height > 0 else { return 1 }

            return min(bounds.width / imageSize.width,
                       bounds.height / imageSize.height)
        }

        private var effectiveScale: CGFloat {
            renderScale * zoomScale
        }

        private func framebufferPoint(for point: CGPoint) -> CGPoint? {
            guard imageSize.width > 0, imageSize.height > 0,
                  bounds.width > 0, bounds.height > 0 else { return nil }

            let scale = effectiveScale
            let origin = imageLayer.frame.origin

            let fx = (point.x - origin.x) / scale
            let fy = (point.y - origin.y) / scale

            guard fx >= 0, fy >= 0,
                  fx <= imageSize.width, fy <= imageSize.height else { return nil }

            return CGPoint(x: fx, y: fy)
        }

        // MARK: - Zoom

        @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                pinchStartZoomScale = zoomScale
                enterMultiTouch()

            case .changed:
                setZoomScale(pinchStartZoomScale * gesture.scale,
                             anchorInView: gesture.location(in: self),
                             notify: true)

            default:
                pinchStartZoomScale = zoomScale
            }
        }

        private func setZoomScale(_ newZoomScale: CGFloat,
                                  anchorInView: CGPoint?,
                                  notify: Bool) {
            let clamped = clampedZoomScale(newZoomScale)
            guard imageSize.width > 0, imageSize.height > 0 else {
                zoomScale = clamped
                if notify { onZoomScaleChanged?(clamped) }
                return
            }

            let anchorFramebuffer = anchorInView.flatMap(framebufferPoint(for:))
            zoomScale = clamped

            if clamped == minimumZoomScale {
                viewportCenter = CGPoint(x: imageSize.width / 2,
                                         y: imageSize.height / 2)
            } else if followsCursor, anchorInView == nil, let session {
                viewportCenter = session.cursorLocation
            } else if let anchorInView, let anchorFramebuffer {
                let viewportCenterX = anchorFramebuffer.x
                    - (anchorInView.x - bounds.midX) / effectiveScale
                let viewportCenterY = anchorFramebuffer.y
                    - (anchorInView.y - bounds.midY) / effectiveScale
                viewportCenter = CGPoint(x: viewportCenterX,
                                         y: viewportCenterY)
            }

            updateImageLayerFrame()

            if notify {
                onZoomScaleChanged?(clamped)
            }
        }

        private func clampedZoomScale(_ zoomScale: CGFloat) -> CGFloat {
            min(max(zoomScale, minimumZoomScale), maximumZoomScale)
        }

        private func updateImageLayerFrame() {
            guard imageSize.width > 0, imageSize.height > 0,
                  bounds.width > 0, bounds.height > 0 else {
                imageLayer.frame = .zero
                return
            }

            let scale = effectiveScale
            let renderedSize = CGSize(width: imageSize.width * scale,
                                      height: imageSize.height * scale)
            let center = clampedViewportCenter(viewportCenter ?? CGPoint(x: imageSize.width / 2,
                                                                         y: imageSize.height / 2),
                                               renderedSize: renderedSize)
            viewportCenter = center

            var origin = CGPoint(x: bounds.midX - center.x * scale,
                                 y: bounds.midY - center.y * scale)

            if renderedSize.width <= bounds.width {
                origin.x = (bounds.width - renderedSize.width) / 2
            } else {
                origin.x = min(max(origin.x, bounds.width - renderedSize.width), 0)
            }

            if renderedSize.height <= bounds.height {
                origin.y = (bounds.height - renderedSize.height) / 2
            } else {
                origin.y = min(max(origin.y, bounds.height - renderedSize.height), 0)
            }

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            imageLayer.frame = CGRect(origin: origin, size: renderedSize)
            CATransaction.commit()
        }

        private func clampedViewportCenter(_ center: CGPoint,
                                           renderedSize: CGSize) -> CGPoint {
            guard zoomScale > minimumZoomScale else {
                return CGPoint(x: imageSize.width / 2,
                               y: imageSize.height / 2)
            }

            return CGPoint(x: clampedViewportCoordinate(center.x,
                                                        imageLength: imageSize.width,
                                                        renderedLength: renderedSize.width,
                                                        viewportLength: bounds.width),
                           y: clampedViewportCoordinate(center.y,
                                                        imageLength: imageSize.height,
                                                        renderedLength: renderedSize.height,
                                                        viewportLength: bounds.height))
        }

        private func clampedViewportCoordinate(_ coordinate: CGFloat,
                                               imageLength: CGFloat,
                                               renderedLength: CGFloat,
                                               viewportLength: CGFloat) -> CGFloat {
            guard renderedLength > viewportLength else {
                return imageLength / 2
            }

            let visibleHalfLength = viewportLength / (2 * effectiveScale)
            let lowerBound = visibleHalfLength
            let upperBound = imageLength - visibleHalfLength

            return min(max(coordinate, lowerBound), upperBound)
        }

        private func followCursorIfNeeded() {
            guard followsCursor, zoomScale > minimumZoomScale, let session else { return }

            viewportCenter = session.cursorLocation
            updateImageLayerFrame()
        }

        // MARK: - Two-finger gestures

        @objc private func handleTwoFingerTap(_ gesture: UITapGestureRecognizer) {
            rightClick(from: gesture, usesPointerLocation: false)
        }

        @objc private func handlePointerSecondaryTap(_ gesture: UITapGestureRecognizer) {
            rightClick(from: gesture, usesPointerLocation: true)
        }

        private func rightClick(from gesture: UITapGestureRecognizer,
                                usesPointerLocation: Bool) {
            guard let session else { return }

            becomeFirstResponder()

            switch session.touchMode {
            case .trackpad:
                if usesPointerLocation,
                   let point = framebufferPoint(for: gesture.location(in: self)) {
                    session.rightClick(at: point)
                } else {
                    session.rightClickAtCursor()
                }

            case .direct:
                if let point = framebufferPoint(for: gesture.location(in: self)) {
                    session.rightClick(at: point)
                }
            }

            followCursorIfNeeded()
        }

        @objc private func handleTwoFingerPan(_ gesture: UIPanGestureRecognizer) {
            guard session != nil else { return }

            switch gesture.state {
            case .began:
                touchScrollAccumulator = .zero

            case .changed:
                let delta = gesture.translation(in: self)
                gesture.setTranslation(.zero, in: self)

                forwardScroll(delta: delta,
                              accumulator: &touchScrollAccumulator)

            default:
                touchScrollAccumulator = .zero
            }
        }

        @objc private func handlePointerScroll(_ gesture: UIPanGestureRecognizer) {
            guard session != nil else { return }

            switch gesture.state {
            case .began:
                pointerScrollAccumulator = .zero
                becomeFirstResponder()

            case .changed:
                let delta = gesture.translation(in: self)
                gesture.setTranslation(.zero, in: self)

                forwardScroll(delta: delta,
                              accumulator: &pointerScrollAccumulator)

            default:
                pointerScrollAccumulator = .zero
            }
        }

        @objc private func handlePointerHover(_ gesture: UIHoverGestureRecognizer) {
            guard let session,
                  gesture.state == .began || gesture.state == .changed,
                  let point = framebufferPoint(for: gesture.location(in: self)) else {
                return
            }

            becomeFirstResponder()
            session.moveCursor(to: point)
            followCursorIfNeeded()
        }

        private func forwardScroll(delta: CGPoint,
                                   accumulator: inout CGPoint) {
            accumulator.x += delta.x
            accumulator.y += delta.y

            let horizontalSteps = Int(abs(accumulator.x) / scrollStep)

            if horizontalSteps > 0 {
                let direction: RemoteScrollDirection =
                    accumulator.x > 0 ? .left : .right

                session?.scroll(direction, steps: UInt32(horizontalSteps))

                accumulator.x -= CGFloat(horizontalSteps) * scrollStep
                    * (accumulator.x > 0 ? 1 : -1)
            }

            let verticalSteps = Int(abs(accumulator.y) / scrollStep)

            if verticalSteps > 0 {
                // Natural direction: fingers down -> content follows (wheel up).
                let direction: RemoteScrollDirection =
                    accumulator.y > 0 ? .up : .down

                session?.scroll(direction, steps: UInt32(verticalSteps))

                accumulator.y -= CGFloat(verticalSteps) * scrollStep
                    * (accumulator.y > 0 ? 1 : -1)
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldReceive touch: UITouch) -> Bool {
            gestureRecognizer !== pointerScrollPan
        }

        // MARK: - Single-finger touch handling

        private func activeTouchCount(_ event: UIEvent?) -> Int {
            event?.allTouches?.filter {
                $0.phase == .began || $0.phase == .moved || $0.phase == .stationary
            }.count ?? 0
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first, let session else { return }

            becomeFirstResponder()

            // Second finger down → this is a two-finger gesture. Abort any
            // single-finger interaction and let the recognizers take over.
            if activeTouchCount(event) >= 2 {
                enterMultiTouch()
                return
            }

            let location = touch.location(in: self)

            switch session.touchMode {
            case .trackpad:
                lastTouchLocation = location
                touchStartTime = touch.timestamp
                touchMoved = false
                isDragging = false
                multiTouchActive = false
                scheduleLongPress()

            case .direct:
                guard let point = framebufferPoint(for: location) else { return }

                multiTouchActive = false
                pendingPressPoint = point
                schedulePendingPress()
            }
        }

        // MARK: - Hardware keyboard input

        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            guard let session else {
                super.pressesBegan(presses, with: event)
                return
            }

            var unhandledPresses = Set<UIPress>()

            for press in presses {
                guard let key = press.key else {
                    unhandledPresses.insert(press)
                    continue
                }

                if let keyCode = HardwareKeyboardKeyMapper.keyCode(for: key.keyCode) {
                    let modifiers = HardwareKeyboardKeyMapper.modifierKeyCodes(
                        for: key.modifierFlags,
                        includeShift: true
                    )

                    session.sendKey(keyCode, modifiers: modifiers)
                } else if !sendText(for: key, through: session) {
                    unhandledPresses.insert(press)
                }
            }

            if !unhandledPresses.isEmpty {
                super.pressesBegan(unhandledPresses, with: event)
            }
        }

        private func sendText(for key: UIKey, through session: any RemoteSessionInputControlling) -> Bool {
            let shortcutModifiers: UIKeyModifierFlags = [.command, .control, .alternate]
            let shouldForwardShortcut = !key.modifierFlags.intersection(shortcutModifiers).isEmpty

            if shouldForwardShortcut, !key.charactersIgnoringModifiers.isEmpty {
                let modifiers = HardwareKeyboardKeyMapper.modifierKeyCodes(
                    for: key.modifierFlags,
                    includeShift: true
                )

                session.sendText(key.charactersIgnoringModifiers, modifiers: modifiers)
                return true
            }

            guard !key.characters.isEmpty else { return false }

            session.sendText(key.characters)
            return true
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first, let session,
                  !multiTouchActive, activeTouchCount(event) < 2 else { return }

            let location = touch.location(in: self)

            switch session.touchMode {
            case .trackpad:
                let delta = CGPoint(x: location.x - lastTouchLocation.x,
                                    y: location.y - lastTouchLocation.y)

                if !touchMoved,
                   abs(delta.x) + abs(delta.y) > tapMovementThreshold {
                    touchMoved = true
                    cancelLongPress()
                }

                guard touchMoved else { return }

                lastTouchLocation = location

                // View-point delta → framebuffer delta, so finger travel
                // matches on-screen cursor travel.
                let scale = effectiveScale
                let fbDelta = CGPoint(x: delta.x / scale, y: delta.y / scale)

                session.moveCursor(by: fbDelta, dragging: isDragging)
                followCursorIfNeeded()

            case .direct:
                guard let point = framebufferPoint(for: location) else { return }

                // Movement before the debounce fired → press immediately so
                // dragging stays responsive.
                firePendingPressIfNeeded()

                guard directPressed else { return }

                // Button stays pressed while coordinates change → drag.
                session.leftButtonDown(at: point)
            }
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first, let session else { return }

            if multiTouchActive {
                if activeTouchCount(event) == 0 { multiTouchActive = false }
                return
            }

            switch session.touchMode {
            case .trackpad:
                cancelLongPress()

                if isDragging {
                    session.releaseAtCursor()
                    isDragging = false
                } else if !touchMoved,
                          touch.timestamp - touchStartTime < tapDurationThreshold {
                    session.clickAtCursor()
                }

            case .direct:
                // Tap ended before the debounce → full click now.
                firePendingPressIfNeeded()

                guard directPressed else { return }

                directPressed = false

                let point = framebufferPoint(for: touch.location(in: self))
                    ?? session.cursorLocation
                session.leftButtonUp(at: point)
                followCursorIfNeeded()
            }
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let session else { return }

            cancelLongPress()
            cancelPendingPress()

            if isDragging {
                session.releaseAtCursor()
                isDragging = false
            }

            if directPressed {
                directPressed = false
                session.leftButtonUp(at: session.cursorLocation)
            }

            if activeTouchCount(event) == 0 { multiTouchActive = false }
        }

        private func enterMultiTouch() {
            multiTouchActive = true

            cancelLongPress()
            cancelPendingPress()

            if isDragging {
                session?.releaseAtCursor()
                isDragging = false
            }

            if directPressed {
                directPressed = false
                session?.leftButtonUp(at: session?.cursorLocation ?? .zero)
            }
        }

        // MARK: - Deferred press (direct mode)

        private func schedulePendingPress() {
            cancelPendingPress()

            let work = DispatchWorkItem { [weak self] in
                self?.firePendingPressIfNeeded()
            }

            pendingPressWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + pressDebounce,
                                          execute: work)
        }

        private func firePendingPressIfNeeded() {
            guard let point = pendingPressPoint else { return }

            cancelPendingPress()
            pendingPressPoint = nil
            directPressed = true
            session?.leftButtonDown(at: point)
        }

        private func cancelPendingPress() {
            pendingPressWork?.cancel()
            pendingPressWork = nil
        }

        // MARK: - Long-press → drag (trackpad mode)

        private func scheduleLongPress() {
            let work = DispatchWorkItem { [weak self] in
                guard let self, !self.touchMoved, !self.isDragging,
                      !self.multiTouchActive else { return }

                self.isDragging = true
                self.session?.pressAtCursor()

                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }

            longPressWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + longPressDelay,
                                          execute: work)
        }

        private func cancelLongPress() {
            longPressWork?.cancel()
            longPressWork = nil
        }
    }
}
