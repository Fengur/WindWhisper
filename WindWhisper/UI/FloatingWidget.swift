import Cocoa
import SnapKit

// MARK: - State

enum WidgetState {
    case idle
    case recording
    case transcribing
}

// MARK: - FloatingWidgetView

class FloatingWidgetView: NSView {
    var onToggle: (() -> Void)?
    var onHide: (() -> Void)?

    private let backgroundEffect = NSVisualEffectView()
    private let buttonIcon = NSImageView()
    private let indicatorDot = NSView()
    private let textLabel = NSTextField(labelWithString: "")
    private let glowLayer = CAShapeLayer()

    private(set) var state: WidgetState = .idle
    private let buttonSize: CGFloat = 44
    private let expandedHeight: CGFloat = 56

    // Drag support
    private var dragOrigin: NSPoint?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        setupBackground()
        setupButton()
        setupIndicator()
        setupTextLabel()
        setupGlow()
        applyIdleLayout()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupBackground() {
        backgroundEffect.material = .hudWindow
        backgroundEffect.state = .active
        backgroundEffect.blendingMode = .withinWindow
        backgroundEffect.wantsLayer = true
        backgroundEffect.layer?.cornerRadius = buttonSize / 2
        backgroundEffect.layer?.masksToBounds = true
        backgroundEffect.layer?.backgroundColor = NSColor(white: 0.15, alpha: 0.9).cgColor
        addSubview(backgroundEffect)
        backgroundEffect.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupButton() {
        buttonIcon.imageScaling = .scaleProportionallyDown
        buttonIcon.contentTintColor = .white
        buttonIcon.image = NSImage(systemSymbolName: "wind", accessibilityDescription: nil)
        addSubview(buttonIcon)
    }

    private func setupIndicator() {
        indicatorDot.wantsLayer = true
        indicatorDot.layer?.backgroundColor = NSColor.systemRed.cgColor
        indicatorDot.layer?.cornerRadius = 4
        indicatorDot.isHidden = true
        indicatorDot.alphaValue = 0
        addSubview(indicatorDot)
    }

    private func setupTextLabel() {
        textLabel.font = .systemFont(ofSize: 13)
        textLabel.textColor = .labelColor
        textLabel.lineBreakMode = .byWordWrapping
        textLabel.maximumNumberOfLines = 4
        textLabel.cell?.wraps = true
        textLabel.isHidden = true
        textLabel.alphaValue = 0
        addSubview(textLabel)
    }

    private func setupGlow() {
        glowLayer.fillColor = nil
        glowLayer.strokeColor = NSColor.systemBlue.withAlphaComponent(0.4).cgColor
        glowLayer.lineWidth = 2
        glowLayer.opacity = 0
        layer?.addSublayer(glowLayer)
    }

    // MARK: - Layout Modes

    private func applyIdleLayout() {
        buttonIcon.snp.remakeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(20)
        }
        buttonIcon.contentTintColor = .white
        backgroundEffect.layer?.cornerRadius = buttonSize / 2
    }

    private func applyExpandedLayout() {
        buttonIcon.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }

        indicatorDot.snp.remakeConstraints { make in
            make.leading.equalTo(buttonIcon.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(8)
        }

        textLabel.snp.remakeConstraints { make in
            make.leading.equalTo(indicatorDot.snp.trailing).offset(10)
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.lessThanOrEqualTo(320)
        }

        backgroundEffect.layer?.cornerRadius = expandedHeight / 2
    }

    // MARK: - State Transitions

    func setState(_ newState: WidgetState, text: String = "") {
        let oldState = state
        state = newState
        textLabel.stringValue = text

        switch newState {
        case .idle:
            transitionToIdle()
        case .recording:
            if oldState == .idle {
                transitionToRecording()
            }
            buttonIcon.contentTintColor = .white
            buttonIcon.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)
        case .transcribing:
            stopPulse()
            stopGlow()
            buttonIcon.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: nil)
            indicatorDot.layer?.backgroundColor = NSColor.systemOrange.cgColor
        }
    }

    func updateText(_ text: String) {
        textLabel.stringValue = text
    }

    // MARK: - Transition Animations

    private func transitionToRecording() {
        applyExpandedLayout()

        textLabel.isHidden = false
        indicatorDot.isHidden = false

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.4
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            self.textLabel.animator().alphaValue = 1.0
            self.indicatorDot.animator().alphaValue = 1.0
            self.layoutSubtreeIfNeeded()
        }

        startPulse()
        startGlow()
    }

    private func transitionToIdle() {
        stopPulse()
        stopGlow()

        buttonIcon.image = NSImage(systemSymbolName: "wind", accessibilityDescription: nil)

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            ctx.allowsImplicitAnimation = true
            self.textLabel.animator().alphaValue = 0
            self.indicatorDot.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.textLabel.isHidden = true
            self?.indicatorDot.isHidden = true
            self?.textLabel.stringValue = ""
            self?.applyIdleLayout()
            self?.layoutSubtreeIfNeeded()
        })
    }

    // MARK: - Pulse Animation

    private func startPulse() {
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.3
        pulse.duration = 0.6
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        indicatorDot.layer?.add(pulse, forKey: "pulse")
    }

    private func stopPulse() {
        indicatorDot.layer?.removeAnimation(forKey: "pulse")
    }

    // MARK: - Glow Animation

    private func startGlow() {
        let glow = CABasicAnimation(keyPath: "opacity")
        glow.fromValue = 0.0
        glow.toValue = 0.6
        glow.duration = 1.2
        glow.autoreverses = true
        glow.repeatCount = .infinity
        glow.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glowLayer.add(glow, forKey: "glow")
    }

    private func stopGlow() {
        glowLayer.removeAnimation(forKey: "glow")
        glowLayer.opacity = 0
    }

    override func layout() {
        super.layout()
        let rect = bounds.insetBy(dx: -1, dy: -1)
        let path = CGPath(roundedRect: rect, cornerWidth: bounds.height / 2, cornerHeight: bounds.height / 2, transform: nil)
        glowLayer.path = path
        glowLayer.frame = bounds
    }

    // MARK: - Mouse Events (Drag + Click + Right-Click)

    override func mouseDown(with event: NSEvent) {
        dragOrigin = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin = dragOrigin, let window else { return }
        let current = event.locationInWindow
        let dx = current.x - origin.x
        let dy = current.y - origin.y
        var frame = window.frame
        frame.origin.x += dx
        frame.origin.y += dy
        window.setFrameOrigin(frame.origin)
    }

    override func mouseUp(with event: NSEvent) {
        guard let origin = dragOrigin else { return }
        let current = event.locationInWindow
        let distance = hypot(current.x - origin.x, current.y - origin.y)
        if distance < 3 {
            onToggle?()
        } else {
            snapToEdge()
        }
        dragOrigin = nil
    }

    private func snapToEdge() {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let frame = window.frame
        let margin: CGFloat = 6

        let distToLeft = frame.origin.x - visible.minX
        let distToRight = visible.maxX - frame.maxX

        var targetX: CGFloat
        if distToLeft < distToRight {
            targetX = visible.minX + margin
        } else {
            targetX = visible.maxX - frame.width - margin
        }

        let targetY = max(visible.minY + margin, min(frame.origin.y, visible.maxY - frame.height - margin))
        let target = NSPoint(x: targetX, y: targetY)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrameOrigin(target)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "隐藏悬浮按钮", action: #selector(hideWidget), keyEquivalent: ""))
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func hideWidget() {
        onHide?()
    }
}

// MARK: - Controller

class FloatingWidgetController {
    private var panel: NSPanel?
    private var widgetView: FloatingWidgetView?
    private var onToggle: (() -> Void)?

    private static let posXKey = "widget.posX"
    private static let posYKey = "widget.posY"
    private static let visibleKey = "widget.visible"

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func setup(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
        createPanel()

        let shouldShow = UserDefaults.standard.object(forKey: Self.visibleKey) as? Bool ?? true
        if shouldShow {
            show()
        }
    }

    func show() {
        guard let panel else {
            Log.error("FloatingWidget: show() called but panel is nil")
            return
        }
        panel.orderFrontRegardless()
        UserDefaults.standard.set(true, forKey: Self.visibleKey)
        Log.info("FloatingWidget: shown at \(panel.frame)")
    }

    func hide() {
        panel?.orderOut(nil)
        UserDefaults.standard.set(false, forKey: Self.visibleKey)
    }

    func startRecording() {
        if !isVisible {
            show()
        }
        widgetView?.setState(.recording, text: "正在聆听...")
        updatePanelSize(expanded: true)
    }

    func updateText(_ text: String) {
        widgetView?.updateText(text)
    }

    func showFinal(_ text: String, then completion: @escaping () -> Void) {
        widgetView?.setState(.transcribing, text: text)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            completion()
            self?.collapseAndRestore()
        }
    }

    func collapse() {
        collapseAndRestore()
    }

    private func collapseAndRestore() {
        widgetView?.setState(.idle)
        updatePanelSize(expanded: false)
        let wasHidden = !(UserDefaults.standard.object(forKey: Self.visibleKey) as? Bool ?? true)
        if wasHidden {
            hide()
        }
    }

    func resetPosition() {
        UserDefaults.standard.removeObject(forKey: Self.posXKey)
        UserDefaults.standard.removeObject(forKey: Self.posYKey)
        positionPanel()
    }

    // MARK: - Panel

    private func createPanel() {
        let widget = FloatingWidgetView(frame: NSRect(x: 0, y: 0, width: 48, height: 48))
        widget.onToggle = { [weak self] in self?.onToggle?() }
        widget.onHide = { [weak self] in self?.hide() }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 48, height: 48),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.hasShadow = false
        panel.contentView = widget

        self.panel = panel
        self.widgetView = widget
        positionPanel()

        Log.info("FloatingWidget: panel created at \(panel.frame)")

        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.savePosition()
        }
    }

    private func currentScreen() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        for screen in NSScreen.screens {
            if screen.frame.contains(mouseLocation) {
                return screen
            }
        }
        return NSScreen.main ?? NSScreen.screens.first!
    }

    private func positionPanel() {
        guard let panel else { return }

        if let x = UserDefaults.standard.object(forKey: Self.posXKey) as? CGFloat,
           let y = UserDefaults.standard.object(forKey: Self.posYKey) as? CGFloat {
            let savedPoint = NSPoint(x: x, y: y)
            let onScreen = NSScreen.screens.contains {
                $0.visibleFrame.insetBy(dx: -50, dy: -50).contains(savedPoint)
            }
            if onScreen {
                panel.setFrameOrigin(savedPoint)
                Log.info("FloatingWidget: restored position \(savedPoint)")
                return
            }
            Log.info("FloatingWidget: saved position \(savedPoint) not on any screen, resetting")
        }

        let screen = currentScreen()
        let visible = screen.visibleFrame
        let x = visible.maxX - 70
        let y = visible.midY
        let origin = NSPoint(x: x, y: y)
        panel.setFrameOrigin(origin)
        Log.info("FloatingWidget: default position \(origin) on screen \(visible)")
    }

    private func savePosition() {
        guard let panel else { return }
        UserDefaults.standard.set(panel.frame.origin.x, forKey: Self.posXKey)
        UserDefaults.standard.set(panel.frame.origin.y, forKey: Self.posYKey)
    }

    private var collapsedOrigin: NSPoint?

    private func isDockedRight() -> Bool {
        guard let panel, let screen = panel.screen ?? NSScreen.main else { return true }
        let midX = panel.frame.midX
        let screenMidX = screen.visibleFrame.midX
        return midX > screenMidX
    }

    private func updatePanelSize(expanded: Bool) {
        guard let panel else { return }
        let expandedWidth: CGFloat = 420
        let expandedHeight: CGFloat = 56
        let collapsedWidth: CGFloat = 48
        let collapsedHeight: CGFloat = 48

        if expanded {
            collapsedOrigin = panel.frame.origin
            let newWidth = expandedWidth
            let newHeight = expandedHeight
            var newX = panel.frame.origin.x
            let newY = panel.frame.origin.y - (newHeight - panel.frame.height) / 2

            if isDockedRight() {
                newX = panel.frame.maxX - newWidth
            }

            let newFrame = NSRect(x: newX, y: newY, width: newWidth, height: newHeight)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.4
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(newFrame, display: true)
            }
        } else {
            let restoreOrigin = collapsedOrigin ?? panel.frame.origin
            let newFrame = NSRect(x: restoreOrigin.x, y: restoreOrigin.y, width: collapsedWidth, height: collapsedHeight)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.35
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(newFrame, display: true)
            }
            collapsedOrigin = nil
        }
    }
}
