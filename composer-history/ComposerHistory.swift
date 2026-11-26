import UIKit
import Foundation

@_silgen_name("vgi_compatible") private func nativeCompatible() -> Int32
@_silgen_name("vgi_width") private func nativeWidth(_ p: UnsafeMutableRawPointer) -> Double
@_silgen_name("vgi_set_width") private func nativeSetWidth(_ p: UnsafeMutableRawPointer, _ expected: Double, _ value: Double) -> Int32
@_silgen_name("vgi_relayout") private func nativeRelayout(_ p: UnsafeMutableRawPointer) -> Int32
@_silgen_name("vgi_archive") private func nativeArchive(_ ctx: UnsafeMutableRawPointer, _ msg: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?
private func ptr(_ object: AnyObject) -> UnsafeMutableRawPointer { Unmanaged.passUnretained(object).toOpaque() }
private func typeName(_ o: AnyObject) -> String { NSStringFromClass(type(of: o)) }
private func isType(_ o: AnyObject, _ suffix: String) -> Bool {
    let n = typeName(o)
    return n.hasSuffix("." + suffix) || (n.hasPrefix("_TtC") && n.hasSuffix(String(suffix.count) + suffix))
}
private func unwrap(_ v: Any) -> Any? {
    let m = Mirror(reflecting: v)
    if m.displayStyle == .optional { return m.children.first.flatMap { unwrap($0.value) } }
    return v
}
private func member(_ v: Any, _ name: String) -> Any? {
    var mirror: Mirror? = Mirror(reflecting: v)
    while let m = mirror {
        for c in m.children where c.label == name { return unwrap(c.value) }
        mirror = m.superclassMirror
    }
    return nil
}
private func node(_ view: UIView) -> NSObject? {
    let sel = NSSelectorFromString("asyncdisplaykit_node")
    guard view.responds(to: sel) else { return nil }
    return view.perform(sel)?.takeUnretainedValue() as? NSObject
}
private func nodeView(_ n: Any?) -> UIView? {
    guard let ob = n as? NSObject else { return nil }
    if let v = ob as? UIView { return v }
    let sel = NSSelectorFromString("view")
    guard ob.responds(to: sel) else { return nil }
    return ob.perform(sel)?.takeUnretainedValue() as? UIView
}
private func visible(_ v: UIView) -> Bool {
    guard v.window != nil, !v.bounds.isEmpty else { return false }
    var w: UIView? = v
    while let view = w { if view.isHidden || view.alpha < 0.05 { return false }; w = view.superview }
    return true
}
private func views(_ root: UIView, limit: Int = 4500) -> [UIView] {
    var pending = [root], found = [UIView]()
    while let v = pending.popLast(), found.count < limit {
        found.append(v)
        if !v.isHidden && v.alpha > 0.02 { pending.append(contentsOf: v.subviews) }
    }
    return found
}
private final class TranslateButton: UIButton {
    weak var original: UIButton?
    let globe = UIImageView(image: UIImage(systemName: "globe"))
    let badge = UILabel()
    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        accessibilityLabel = "ترجمة قبل الإرسال"
        accessibilityHint = "اضغط مطولاً لاختيار اللغة"
        showsMenuAsPrimaryAction = false
        globe.contentMode = .scaleAspectFit
        globe.isUserInteractionEnabled = false
        addSubview(globe)
        badge.font = .systemFont(ofSize: 8, weight: .semibold)
        badge.textAlignment = .center
        badge.textColor = .white
        badge.backgroundColor = .systemBlue
        badge.layer.cornerRadius = 4
        badge.clipsToBounds = true
        badge.isUserInteractionEnabled = false
        addSubview(badge)
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { nil }
    override func layoutSubviews() {
        super.layoutSubviews()
        globe.frame = CGRect(x: 4, y: (bounds.height - 19) / 2 + 1, width: 19, height: 19)
        badge.frame = CGRect(x: 15, y: max(1, (bounds.height - 19) / 2 - 4), width: 17, height: 11)
    }
    @objc private func tapped() { original?.sendActions(for: .touchUpInside) }
    func sync(_ b: UIButton, anchor: UIView) {
        original = b
        if menu !== b.menu { menu = b.menu }
        let code = UserDefaults.standard.string(forKey: "ayu.extra.translateTo") ?? "en"
        badge.text = String(code.uppercased().prefix(3))
        accessibilityValue = code.uppercased()
        globe.tintColor = anchor.tintColor
    }
}
private final class ComposerPlacement {
    weak var bar: UIView?
    weak var original: UIButton?
    weak var anchor: UIView?
    weak var container: UIView?
    weak var panel: NSObject?
    var baseWidth: Double = 0
    var baseInteraction = true
    var glyphs: [(UIView, CGAffineTransform)] = []
    let proxy = TranslateButton()
    init(bar: UIView) { self.bar = bar; baseInteraction = bar.isUserInteractionEnabled }
    func restoreAnchor() {
        for (v, transform) in glyphs { v.transform = transform }
        if let a = anchor, baseWidth > 0 {
            let restored = nativeSetWidth(ptr(a), baseWidth + 33, baseWidth)
            if restored != 0, a.window != nil, let p = panel { _ = nativeRelayout(ptr(p)) }
        }
        glyphs.removeAll()
        anchor = nil
        baseWidth = 0
    }
    func reset() {
        restoreAnchor()
        original?.isHidden = false
        bar?.isUserInteractionEnabled = baseInteraction
        proxy.removeFromSuperview()
        original = nil
    }
    func place(original b: UIButton, stack: UIStackView, anchor a: UIView, in parent: UIView, panel p: NSObject) {
        if original !== b { original?.isHidden = false; original = b }
        if anchor !== a {
            restoreAnchor()
            let width = nativeWidth(ptr(a))
            guard width >= 16 && width <= 80, nativeSetWidth(ptr(a), width, width + 33) != 0 else { reset(); return }
            baseWidth = width
            anchor = a
            container = parent
            panel = p
            // Native layout uses the width field for both editor insets and accessory positioning.
            for name in ["iconImageView", "textView", "animationView", "tintMaskTextView", "tintMaskAnimationView"] {
                if let v = nodeView(member(a, name)), v !== a {
                    glyphs.append((v, v.transform))
                }
            }
            _ = nativeRelayout(ptr(p))
        }
        let width = nativeWidth(ptr(a))
        if abs(width - baseWidth) < 0.1 {
            for (v, transform) in glyphs { v.transform = transform }
            if nativeSetWidth(ptr(a), width, width + 33) != 0 { _ = nativeRelayout(ptr(p)) }
        }
        if abs(a.frame.width - CGFloat(baseWidth + 33)) >= 2 { _ = nativeRelayout(ptr(p)) }
        guard abs(a.frame.width - CGFloat(baseWidth + 33)) < 2 else {
            proxy.removeFromSuperview(); b.isHidden = false; bar?.isUserInteractionEnabled = baseInteraction
            return
        }
        // The native button's center moves left when its width expands. Keep its own icon in its original right-hand slot.
        for (v, transform) in glyphs {
            let f = v.frame
            if abs(f.midX - a.bounds.midX) < 4 || v.transform != transform {
                v.transform = transform.translatedBy(x: 16.5, y: 0)
            }
        }
        if proxy.superview !== parent { proxy.removeFromSuperview(); parent.addSubview(proxy) }
        proxy.frame = CGRect(x: a.frame.minX, y: a.frame.minY, width: 33, height: a.frame.height)
        parent.bringSubviewToFront(proxy)
        proxy.sync(b, anchor: a)
        b.isHidden = true
        if stack.arrangedSubviews.allSatisfy({ $0.isHidden }) { bar?.isUserInteractionEnabled = false }
        else { bar?.isUserInteractionEnabled = baseInteraction }
    }
    deinit { reset() }
}
private final class HistoryAction: UIView {
    weak var presentation: NSObject?
    weak var chat: UIViewController?
    weak var message: AnyObject?
    weak var nativeText: UIView?
    let label = UILabel()
    let detail = UILabel()
    init(presentation: NSObject, chat: UIViewController, message: AnyObject, nativeText: UIView?, time: String, color: UIColor) {
        self.presentation = presentation; self.chat = chat; self.message = message; self.nativeText = nativeText
        super.init(frame: .zero)
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = "سجل التعديلات"
        accessibilityHint = "عرض النسخ المحفوظة من هذه الرسالة"
        UIView.performWithoutAnimation { nativeText?.alpha = 0 }
        label.text = "سجل التعديلات"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = color
        detail.text = time
        detail.textColor = color.withAlphaComponent(0.7)
        detail.font = .systemFont(ofSize: 11)
        detail.adjustsFontSizeToFitWidth = true
        detail.minimumScaleFactor = 0.75
        for l in [label, detail] { l.isUserInteractionEnabled = false; l.textAlignment = .natural; addSubview(l) }
        let tap = UITapGestureRecognizer(target: self, action: #selector(open(_:)))
        addGestureRecognizer(tap)
    }
    required init?(coder: NSCoder) { nil }
    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = CGRect(x: 0, y: max(0, (bounds.height-36)/2), width: bounds.width, height: 20)
        detail.frame = CGRect(x: 0, y: label.frame.maxY, width: bounds.width, height: 15)
    }
    @objc private func open(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, let p = presentation, let m = message, let chat = chat,
              let nav = chat.navigationController,
              let raw = nativeArchive(ptr(p), ptr(m)) else { return }
        let obj = Unmanaged<AnyObject>.fromOpaque(raw).takeRetainedValue()
        guard let archive = obj as? UIViewController else { return }
        let selector = NSSelectorFromString("dismissTapGesture:")
        guard p.responds(to: selector) else { return }
        _ = p.perform(selector, with: gesture)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak nav] in
            nav?.pushViewController(archive, animated: true)
        }
    }
    deinit { nativeText?.alpha = 1 }
}
private final class Coordinator: NSObject {
    static let shared = Coordinator()
    private var placements = [ObjectIdentifier: ComposerPlacement]()
    private var timer: Timer?
    private weak var lastChat: UIViewController?
    func begin() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 0.23, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
    private func sourceObject(_ value: Any, depth: Int = 0) -> AnyObject? {
        guard depth <= 3 else { return nil }
        let m = Mirror(reflecting: value)
        if m.displayStyle == .class {
            let o = value as AnyObject
            return isType(o, "ChatMessageContextExtractedContentSource") ? o : nil
        }
        guard m.displayStyle == .enum || m.displayStyle == .optional || m.displayStyle == .tuple else { return nil }
        for c in m.children { if let found = sourceObject(c.value, depth: depth + 1) { return found } }
        return nil
    }
    private func isEditTime(_ text: String) -> Bool {
        let s = text.lowercased()
        return s.contains("تم تعديل") || s.contains("عُدّلت") || s.contains("edited ") || s.contains("изменено") || s.contains("відредаговано")
    }
    private func installHistory(_ p: NSObject, view: UIView) {
        guard let sourceEnum = member(p, "source"), let source = sourceObject(sourceEnum),
              let messageValue = member(source, "message"), isType(messageValue as AnyObject, "Message"),
              let chat = (member(source, "chatController") as? UIViewController) ?? lastChat,
              chat.navigationController != nil else { return }
        let message = messageValue as AnyObject
        for v in views(view, limit: 1800) {
            guard let action = node(v) else { continue }
            let compact = isType(action, "ContextActionNode")
            guard compact || isType(action, "ContextControllerActionsListActionItemNode") else { continue }
            guard let item = member(action, compact ? "action" : "item"),
                  let text = member(item, "text") as? String, isEditTime(text),
                  let tv = nodeView(member(action, compact ? "textNode" : "titleLabelNode")) else { continue }
            if let old = v.subviews.first(where: { $0 is HistoryAction }) as? HistoryAction {
                old.frame = CGRect(x: tv.frame.minX, y: 0, width: max(0, v.bounds.width-tv.frame.minX-10), height: v.bounds.height)
                old.nativeText?.alpha = 0
                continue
            }
            guard tv.frame.width > 10, v.bounds.height >= 30 else { continue }
            let color: UIColor
            if let attributed = member(member(action, compact ? "textNode" : "titleLabelNode") ?? action, "attributedText") as? NSAttributedString,
               attributed.length > 0, let c = attributed.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor { color = c }
            else { color = v.traitCollection.userInterfaceStyle == .dark ? .white : .label }
            let overlay = HistoryAction(presentation: p, chat: chat, message: message, nativeText: tv, time: text, color: color)
            overlay.frame = CGRect(x: tv.frame.minX, y: 0, width: max(0, v.bounds.width-tv.frame.minX-10), height: v.bounds.height)
            overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            v.addSubview(overlay)
        }
    }
    @objc private func tick() {
        guard UIApplication.shared.applicationState == .active, nativeCompatible() != 0 else { return }
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.filter { $0.activationState == .foregroundActive }.flatMap { $0.windows }
        var seen = Set<ObjectIdentifier>()
        for w in windows where !w.isHidden {
            let all = views(w)
            for v in all where isType(v, "AyuComposerBar") && visible(v) {
                if let chat = member(v, "controller") as? UIViewController { lastChat = chat }
                guard let stack = member(v, "stack") as? UIStackView,
                      let b = stack.arrangedSubviews.compactMap({ $0 as? UIButton }).first(where: { $0.configuration?.title?.hasPrefix("→ ") == true && $0.menu != nil }),
                      let chat = member(v, "controller") as? UIViewController, let root = chat.viewIfLoaded else { continue }
                // Only native composer accessory buttons; do not attach in a gallery, search or unrelated text field.
                let accessories = views(root).filter { isType($0, "AccessoryItemIconButton") && visible($0) && $0.bounds.height >= 25 && $0.bounds.height <= 65 }
                let emoji = accessories.filter { candidate in
                    guard let item = member(candidate, "item") else { return false }
                    return Mirror(reflecting: item).children.first?.label == "input" || String(describing: item).hasPrefix("input(")
                }
                let candidates = emoji.isEmpty ? accessories : emoji
                guard let a = candidates.min(by: { $0.convert($0.bounds, to: root).minX < $1.convert($1.bounds, to: root).minX }), let parent = a.superview,
                      parent.subviews.contains(where: { $0.layer.name == "textInputNodeClippingContainer" }) else { continue }
                var ancestor: UIView? = parent
                var panel: NSObject?
                while let v = ancestor {
                    if let n = node(v), isType(n, "ChatTextInputPanelNode") { panel = n; break }
                    ancestor = v.superview
                }
                guard let panel else { continue }
                let key = ObjectIdentifier(v)
                let placement = placements[key] ?? ComposerPlacement(bar: v)
                placements[key] = placement
                seen.insert(key)
                placement.place(original: b, stack: stack, anchor: a, in: parent, panel: panel)
            }
            for v in all {
                if let p = node(v), isType(p, "ContextControllerExtractedPresentationNode") { installHistory(p, view: v) }
            }
        }
        for key in Array(placements.keys) where !seen.contains(key) {
            placements.removeValue(forKey: key)?.reset()
        }
    }
}
@_cdecl("vgi_start") public func vgiStart() {
    DispatchQueue.main.async { Coordinator.shared.begin() }
}
