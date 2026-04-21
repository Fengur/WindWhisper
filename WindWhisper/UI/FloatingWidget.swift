import Cocoa
import SnapKit

// MARK: - Brand Colors

enum WindColor {
    static let teal = NSColor(calibratedRed: 0.30, green: 0.74, blue: 0.77, alpha: 1.0)
    static let tealLight = NSColor(calibratedRed: 0.49, green: 0.83, blue: 0.80, alpha: 1.0)
    static let tealDark = NSColor(calibratedRed: 0.16, green: 0.54, blue: 0.56, alpha: 1.0)
}

// MARK: - State

enum WidgetState {
    case idle
    case recording
    case transcribing
    case result
}

// MARK: - FloatingWidgetView

class FloatingWidgetView: NSView {
    var onToggle: (() -> Void)?
    var onHide: (() -> Void)?
    var onDragEnd: (() -> Void)?
    var onCopy: (() -> Void)?
    var onClose: (() -> Void)?

    private let backgroundEffect = NSVisualEffectView()
    private let iconContainer = NSView()
    private let buttonIcon = NSImageView()
    private let rippleLayer1 = CAShapeLayer()
    private let rippleLayer2 = CAShapeLayer()
    private let indicatorDot = NSView()
    private let textLabel = NSTextField(labelWithString: "")
    private let copyButton = NSButton()
    private let closeButton = NSButton()
    private let toastLabel = NSTextField(labelWithString: "")

    private(set) var state: WidgetState = .idle
    private let buttonSize: CGFloat = 44
    private let expandedHeight: CGFloat = 56
    private let idleAlpha: CGFloat = 0.55

    private var dragOrigin: NSPoint?
    private var didDrag = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        alphaValue = idleAlpha

        setupBackground()
        setupIcon()
        setupRipples()
        setupIndicator()
        setupTextLabel()
        setupActionButtons()
        setupToast()
        setupTrackingArea()
        applyIdleLayout()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupBackground() {
        backgroundEffect.material = .hudWindow
        backgroundEffect.state = .active
        backgroundEffect.blendingMode = .withinWindow
        backgroundEffect.wantsLayer = true
        backgroundEffect.layer?.masksToBounds = true
        addSubview(backgroundEffect)
    }

    private func setupIcon() {
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = buttonSize / 2
        iconContainer.layer?.masksToBounds = true
        addSubview(iconContainer)

        buttonIcon.imageScaling = .scaleAxesIndependently
        buttonIcon.image = NSImage(named: "icon_widget")
        iconContainer.addSubview(buttonIcon)
    }

    private func setupRipples() {
        guard let containerLayer = layer else { return }
        for ripple in [rippleLayer1, rippleLayer2] {
            ripple.fillColor = nil
            ripple.strokeColor = WindColor.teal.withAlphaComponent(0.6).cgColor
            ripple.lineWidth = 2
            ripple.opacity = 0
            containerLayer.insertSublayer(ripple, at: 0)
        }
    }

    private func setupIndicator() {
        indicatorDot.wantsLayer = true
        indicatorDot.layer?.backgroundColor = WindColor.teal.cgColor
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

    private func setupActionButtons() {
        let iconSize = NSSize(width: 14, height: 14)

        copyButton.bezelStyle = .circular
        copyButton.isBordered = false
        copyButton.wantsLayer = true
        copyButton.layer?.cornerRadius = 12
        copyButton.layer?.backgroundColor = WindColor.teal.withAlphaComponent(0.2).cgColor
        if let img = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "复制") {
            img.size = iconSize
            copyButton.image = img
        }
        copyButton.contentTintColor = WindColor.teal
        copyButton.target = self
        copyButton.action = #selector(copyTapped)
        copyButton.isHidden = true
        copyButton.alphaValue = 0
        addSubview(copyButton)

        closeButton.bezelStyle = .circular
        closeButton.isBordered = false
        closeButton.wantsLayer = true
        closeButton.layer?.cornerRadius = 12
        closeButton.layer?.backgroundColor = NSColor.gray.withAlphaComponent(0.2).cgColor
        if let img = NSImage(systemSymbolName: "xmark", accessibilityDescription: "关闭") {
            img.size = iconSize
            closeButton.image = img
        }
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        closeButton.isHidden = true
        closeButton.alphaValue = 0
        addSubview(closeButton)
    }

    private func setupToast() {
    }

    private func setupTrackingArea() {
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    // MARK: - Layout

    private func applyIdleLayout() {
        iconContainer.snp.remakeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(buttonSize)
        }
        iconContainer.layer?.cornerRadius = buttonSize / 2
        buttonIcon.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
        backgroundEffect.snp.remakeConstraints { make in
            make.edges.equalTo(iconContainer)
        }
        backgroundEffect.layer?.cornerRadius = buttonSize / 2
        backgroundEffect.layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func applyExpandedLayout() {
        let expandedIconSize: CGFloat = 40
        iconContainer.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(expandedIconSize)
        }
        iconContainer.layer?.cornerRadius = expandedIconSize / 2
        buttonIcon.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }

        indicatorDot.snp.remakeConstraints { make in
            make.leading.equalTo(iconContainer.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(8)
        }

        textLabel.snp.remakeConstraints { make in
            make.leading.equalTo(indicatorDot.snp.trailing).offset(10)
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.lessThanOrEqualTo(320)
        }

        backgroundEffect.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
        backgroundEffect.layer?.cornerRadius = expandedHeight / 2
        backgroundEffect.layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.85).cgColor
    }

    private func applyResultLayout() {
        let expandedIconSize: CGFloat = 40
        iconContainer.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(expandedIconSize)
        }
        iconContainer.layer?.cornerRadius = expandedIconSize / 2
        buttonIcon.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }

        copyButton.snp.remakeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(28)
        }
        closeButton.snp.remakeConstraints { make in
            make.trailing.equalTo(copyButton.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(28)
        }

        textLabel.snp.remakeConstraints { make in
            make.leading.equalTo(iconContainer.snp.trailing).offset(10)
            make.trailing.equalTo(closeButton.snp.leading).offset(-10)
            make.centerY.equalToSuperview()
            make.width.lessThanOrEqualTo(300)
        }

        backgroundEffect.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
        backgroundEffect.layer?.cornerRadius = expandedHeight / 2
        backgroundEffect.layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.85).cgColor
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
        case .transcribing:
            stopRipples()
            stopDotPulse()
            indicatorDot.layer?.backgroundColor = WindColor.tealDark.cgColor
        case .result:
            transitionToResult()
        }
    }

    func updateText(_ text: String) {
        textLabel.stringValue = text
    }

    func showToast(_ message: String) {
    }

    // MARK: - Transitions

    private func transitionToRecording() {
        self.animator().alphaValue = 1.0
        applyExpandedLayout()
        textLabel.isHidden = false
        indicatorDot.isHidden = false
        hideActionButtons()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.4
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            self.textLabel.animator().alphaValue = 1.0
            self.indicatorDot.animator().alphaValue = 1.0
            self.layoutSubtreeIfNeeded()
        }

        bounceIcon()
        startRipples()
        startDotPulse()
    }

    private func transitionToResult() {
        stopRipples()
        stopDotPulse()
        indicatorDot.isHidden = true
        indicatorDot.alphaValue = 0

        applyResultLayout()
        copyButton.isHidden = false
        closeButton.isHidden = false

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.allowsImplicitAnimation = true
            self.copyButton.animator().alphaValue = 1.0
            self.closeButton.animator().alphaValue = 1.0
            self.layoutSubtreeIfNeeded()
        }
    }

    private func transitionToIdle() {
        stopRipples()
        stopDotPulse()

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            ctx.allowsImplicitAnimation = true
            self.textLabel.animator().alphaValue = 0
            self.indicatorDot.animator().alphaValue = 0
            self.copyButton.animator().alphaValue = 0
            self.closeButton.animator().alphaValue = 0
            self.animator().alphaValue = self.idleAlpha
        }, completionHandler: { [weak self] in
            self?.textLabel.isHidden = true
            self?.indicatorDot.isHidden = true
            self?.textLabel.stringValue = ""
            self?.hideActionButtons()
            self?.applyIdleLayout()
            self?.layoutSubtreeIfNeeded()
        })
    }

    private func hideActionButtons() {
        copyButton.isHidden = true
        copyButton.alphaValue = 0
        closeButton.isHidden = true
        closeButton.alphaValue = 0
    }

    // MARK: - Bounce

    private func bounceIcon() {
        let bounce = CAKeyframeAnimation(keyPath: "transform.scale")
        bounce.values = [1.0, 1.25, 0.9, 1.05, 1.0]
        bounce.keyTimes = [0, 0.2, 0.5, 0.75, 1.0]
        bounce.duration = 0.5
        iconContainer.layer?.add(bounce, forKey: "bounce")
    }

    // MARK: - Ripple

    private func startRipples() {
        let center = CGPoint(x: buttonSize / 2, y: buttonSize / 2)
        let startR = buttonSize / 2
        let endR = buttonSize / 2 + 14

        for (i, ripple) in [rippleLayer1, rippleLayer2].enumerated() {
            let startPath = CGPath(ellipseIn: CGRect(x: center.x - startR, y: center.y - startR, width: startR * 2, height: startR * 2), transform: nil)
            let endPath = CGPath(ellipseIn: CGRect(x: center.x - endR, y: center.y - endR, width: endR * 2, height: endR * 2), transform: nil)
            ripple.path = startPath
            ripple.frame = iconContainer.frame

            let pathAnim = CABasicAnimation(keyPath: "path")
            pathAnim.fromValue = startPath
            pathAnim.toValue = endPath
            let opacityAnim = CABasicAnimation(keyPath: "opacity")
            opacityAnim.fromValue = 0.6
            opacityAnim.toValue = 0.0

            let group = CAAnimationGroup()
            group.animations = [pathAnim, opacityAnim]
            group.duration = 1.6
            group.repeatCount = .infinity
            group.beginTime = CACurrentMediaTime() + Double(i) * 0.8
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ripple.add(group, forKey: "ripple")
        }
    }

    private func stopRipples() {
        rippleLayer1.removeAllAnimations()
        rippleLayer2.removeAllAnimations()
        rippleLayer1.opacity = 0
        rippleLayer2.opacity = 0
    }

    private func startDotPulse() {
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.2
        pulse.duration = 0.6
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        indicatorDot.layer?.add(pulse, forKey: "dotPulse")
    }

    private func stopDotPulse() {
        indicatorDot.layer?.removeAnimation(forKey: "dotPulse")
    }

    override func layout() {
        super.layout()
        rippleLayer1.frame = iconContainer.frame
        rippleLayer2.frame = iconContainer.frame
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        dragOrigin = event.locationInWindow
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin = dragOrigin, let window else { return }
        let current = event.locationInWindow
        let dx = current.x - origin.x
        let dy = current.y - origin.y
        if !didDrag && hypot(dx, dy) > 3 { didDrag = true }
        if didDrag {
            var frame = window.frame
            frame.origin.x += dx
            frame.origin.y += dy
            window.setFrameOrigin(frame.origin)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if !didDrag {
            if state == .idle || state == .recording {
                onToggle?()
            }
        } else {
            onDragEnd?()
        }
        dragOrigin = nil
        didDrag = false
    }

    // MARK: - Hover

    override func mouseEntered(with event: NSEvent) {
        if state == .idle {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                self.animator().alphaValue = 1.0
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        if state == .idle {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                self.animator().alphaValue = self.idleAlpha
            }
        }
    }

    // MARK: - Right Click

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "隐藏悬浮按钮", action: #selector(hideWidget), keyEquivalent: ""))
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func hideWidget() { onHide?() }
    @objc private func copyTapped() { onCopy?() }
    @objc private func closeTapped() { onClose?() }
}

// MARK: - Controller

class FloatingWidgetController {
    private var panel: NSPanel?
    private var widgetView: FloatingWidgetView?
    private var onToggle: (() -> Void)?
    private var lastResultText: String = ""
    private var homePosition: NSPoint = .zero

    private static let posXKey = "widget.posX"
    private static let posYKey = "widget.posY"
    private static let visibleKey = "widget.visible"

    var isVisible: Bool { panel?.isVisible ?? false }

    func setup(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
        createPanel()

        let shouldShow = UserDefaults.standard.object(forKey: Self.visibleKey) as? Bool ?? true
        if shouldShow { show() }
    }

    func show() {
        guard let panel else { return }
        panel.orderFrontRegardless()
        UserDefaults.standard.set(true, forKey: Self.visibleKey)
    }

    func hide() {
        panel?.orderOut(nil)
        UserDefaults.standard.set(false, forKey: Self.visibleKey)
    }

    func startRecording() {
        if !isVisible { show() }
        widgetView?.setState(.recording, text: "正在聆听...")
        expandPanel()
    }

    func updateText(_ text: String) {
        widgetView?.updateText(text)
    }

    func showResult(_ text: String) {
        lastResultText = text
        widgetView?.setState(.result, text: text)
    }

    func collapse() {
        collapseToHome()
    }

    func copyToClipboard() {
        guard !lastResultText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastResultText, forType: .string)
        showToast("已复制")
    }

    // MARK: - Toast

    private var toastPanel: NSPanel?

    private func showToast(_ message: String) {
        guard let panel else { return }

        let font = NSFont.boldSystemFont(ofSize: 13)
        let textSize = (message as NSString).size(withAttributes: [.font: font])
        let padding: CGFloat = 24
        let toastWidth = textSize.width + padding * 2
        let toastHeight: CGFloat = 32

        let toast = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: toastWidth, height: toastHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        toast.level = .floating + 1
        toast.isOpaque = false
        toast.backgroundColor = .clear
        toast.hasShadow = false
        toast.isReleasedWhenClosed = false

        let container = NSView(frame: NSRect(x: 0, y: 0, width: toastWidth, height: toastHeight))
        container.wantsLayer = true
        container.layer?.cornerRadius = toastHeight / 2
        container.layer?.backgroundColor = WindColor.teal.cgColor

        let label = NSTextField(labelWithString: message)
        label.font = font
        label.textColor = .white
        label.alignment = .center
        label.isBezeled = false
        label.isEditable = false
        label.drawsBackground = false
        label.sizeToFit()
        label.frame = NSRect(
            x: (toastWidth - label.frame.width) / 2,
            y: (toastHeight - label.frame.height) / 2,
            width: label.frame.width,
            height: label.frame.height
        )
        container.addSubview(label)
        toast.contentView = container

        let x = panel.frame.midX - toastWidth / 2
        let y = panel.frame.maxY + 8
        toast.setFrameOrigin(NSPoint(x: x, y: y))
        toast.alphaValue = 0
        toast.orderFrontRegardless()

        toastPanel?.orderOut(nil)
        toastPanel = toast

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            toast.animator().alphaValue = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                toast.animator().alphaValue = 0
            }, completionHandler: {
                toast.orderOut(nil)
                if self?.toastPanel === toast { self?.toastPanel = nil }
            })
        }
    }

    private func collapseToHome() {
        widgetView?.setState(.idle)
        Log.info("collapseToHome: homePosition=\(homePosition)")

        let newFrame = NSRect(x: homePosition.x, y: homePosition.y, width: 48, height: 48)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.panel?.animator().setFrame(newFrame, display: true)
        }

        let wasHidden = !(UserDefaults.standard.object(forKey: Self.visibleKey) as? Bool ?? true)
        if wasHidden { hide() }
    }

    func resetPosition() {
        UserDefaults.standard.removeObject(forKey: Self.posXKey)
        UserDefaults.standard.removeObject(forKey: Self.posYKey)
        setDefaultPosition()
    }

    // MARK: - Panel

    private func createPanel() {
        let widget = FloatingWidgetView(frame: NSRect(x: 0, y: 0, width: 48, height: 48))
        widget.onToggle = { [weak self] in self?.onToggle?() }
        widget.onHide = { [weak self] in self?.hide() }
        widget.onDragEnd = { [weak self] in self?.handleDragEnd() }
        widget.onCopy = { [weak self] in self?.copyToClipboard() }
        widget.onClose = { [weak self] in self?.collapseToHome() }

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
        loadPosition()
    }

    private func loadPosition() {
        guard let panel else { return }

        if let x = UserDefaults.standard.object(forKey: Self.posXKey) as? CGFloat,
           let y = UserDefaults.standard.object(forKey: Self.posYKey) as? CGFloat {
            let ballRight = NSPoint(x: x + 48, y: y + 24)
            if NSScreen.screens.contains(where: { $0.frame.contains(ballRight) }) {
                homePosition = NSPoint(x: x, y: y)
                panel.setFrameOrigin(homePosition)
                return
            }
        }

        setDefaultPosition()
    }

    private func setDefaultPosition() {
        guard let panel else { return }
        let screen = screenForMouse()
        let visible = screen.visibleFrame
        homePosition = NSPoint(x: visible.midX + visible.width / 4, y: visible.midY)
        panel.setFrameOrigin(homePosition)
    }

    private func handleDragEnd() {
        guard let panel else { return }
        if widgetView?.state == .idle && panel.frame.width <= 48 {
            homePosition = panel.frame.origin
            savePosition()
        }
    }

    private func savePosition() {
        UserDefaults.standard.set(homePosition.x, forKey: Self.posXKey)
        UserDefaults.standard.set(homePosition.y, forKey: Self.posYKey)
    }

    private func screenForMouse() -> NSScreen {
        let loc = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(loc) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private func screenForPanel() -> NSScreen {
        guard let panel else { return screenForMouse() }
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        return NSScreen.screens.first { $0.frame.contains(center) } ?? screenForMouse()
    }

    private func expandPanel() {
        guard let panel else { return }
        let expandedWidth: CGFloat = 460
        let expandedHeight: CGFloat = 56

        let screen = screenForPanel()
        let visible = screen.visibleFrame
        let isRight = panel.frame.midX > visible.midX

        var newX = homePosition.x
        let newY = homePosition.y - (expandedHeight - 48) / 2

        if isRight {
            newX = homePosition.x + 48 - expandedWidth
        }

        let newFrame = NSRect(x: newX, y: newY, width: expandedWidth, height: expandedHeight)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.4
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(newFrame, display: true)
        }
    }
}
