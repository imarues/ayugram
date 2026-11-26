import UIKit
import Foundation

@_silgen_name("vgi_compatible") private func nativeCompatible() -> Int32
@_silgen_name("vgi_kind") private func nativeKind(_ p: UnsafeMutableRawPointer) -> Int32
@_silgen_name("vgi_width") private func nativeWidth(_ p: UnsafeMutableRawPointer) -> Double
@_silgen_name("vgi_set_width") private func nativeSetWidth(_ p: UnsafeMutableRawPointer, _ expected: Double, _ value: Double) -> Int32
@_silgen_name("vgi_relayout") private func nativeRelayout(_ p: UnsafeMutableRawPointer) -> Int32
@_silgen_name("vgi_clip") private func nativeClip(_ p: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?
@_silgen_name("vgi_glyph") private func nativeGlyph(_ p: UnsafeMutableRawPointer, _ i: Int32) -> UnsafeMutableRawPointer?
@_silgen_name("vgi_menu_message") private func nativeMessage(_ p: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?
@_silgen_name("vgi_menu_chat") private func nativeChat(_ p: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?
@_silgen_name("vgi_action_text") private func nativeActionText(_ p: UnsafeMutableRawPointer) -> UnsafeRawPointer?
@_silgen_name("vgi_action_label") private func nativeActionLabel(_ p: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?
@_silgen_name("vgi_archive") private func nativeArchive(_ p: UnsafeMutableRawPointer, _ m: UnsafeMutableRawPointer, _ c: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?
@_silgen_name("vgi_install_hooks") private func nativeInstallHooks()
@_silgen_name("vgi_node_for_view") private func nativeNode(_ p: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?

private func ptr(_ o: AnyObject) -> UnsafeMutableRawPointer { Unmanaged.passUnretained(o).toOpaque() }
private func object(_ p: UnsafeMutableRawPointer?) -> AnyObject? { p.map { Unmanaged<AnyObject>.fromOpaque($0).takeUnretainedValue() } }
private func kind(_ o: AnyObject) -> Int32 { nativeKind(ptr(o)) }
private func node(_ v: UIView) -> NSObject? { object(nativeNode(ptr(v))) as? NSObject }
private func nodeView(_ o: AnyObject?) -> UIView? {
    if let v = o as? UIView { return v }
    guard let n = o as? NSObject else { return nil }
    let sel = NSSelectorFromString("view")
    guard n.responds(to: sel) else { return nil }
    return n.perform(sel)?.takeUnretainedValue() as? UIView
}
private func visible(_ v: UIView) -> Bool {
    guard v.window != nil, !v.bounds.isEmpty else { return false }
    var p: UIView? = v
    while let x = p { if x.isHidden || x.alpha < 0.01 { return false }; p = x.superview }
    return true
}
private func descendants(_ root: UIView, limit: Int = 12000) -> [UIView] {
    // Breadth-first: the chat composer and context menu are visited before an arbitrarily large message list.
    var result = [root], index = 0
    while index < result.count && result.count < limit {
        let v = result[index]; index += 1
        if !v.isHidden && v.alpha > 0.01 { result.append(contentsOf: v.subviews) }
    }
    return result
}
private func nearestController(_ v: UIView) -> UIViewController? {
    var r: UIResponder? = v
    while let x = r {
        if let c = x as? UIViewController { return c }
        r = x.next
    }
    return nil
}
private func findChat(_ root: UIViewController?, depth: Int = 0) -> UIViewController? {
    guard let c = root, depth < 18 else { return nil }
    if kind(c) == 7 { return c }
    for child in c.children.reversed() { if let found = findChat(child, depth: depth+1), found.viewIfLoaded?.window != nil { return found } }
    if let n = c as? UINavigationController { return findChat(n.visibleViewController, depth: depth+1) }
    if let presented = c.presentedViewController { return findChat(presented, depth: depth+1) }
    return nil
}
private func visibleController(_ root: UIViewController) -> UIViewController {
    if let p = root.presentedViewController, !p.isBeingDismissed { return visibleController(p) }
    if let n = root as? UINavigationController, let top = n.visibleViewController { return visibleController(top) }
    return root
}

private final class TranslateButton: UIButton {
    weak var original: UIButton?
    let globe = UIImageView(image: UIImage(systemName: "globe"))
    let badge = UILabel()
    init() {
        super.init(frame: .zero)
        accessibilityLabel = "ترجمة قبل الإرسال"
        accessibilityHint = "اضغط مطولاً لاختيار اللغة"
        showsMenuAsPrimaryAction = false
        backgroundColor = .clear
        globe.contentMode = .scaleAspectFit; globe.isUserInteractionEnabled = false
        addSubview(globe)
        badge.font = .systemFont(ofSize: 8, weight: .semibold)
        badge.textAlignment = .center; badge.textColor = .white
        badge.backgroundColor = .systemBlue; badge.layer.cornerRadius = 4
        badge.clipsToBounds = true; badge.isUserInteractionEnabled = false
        addSubview(badge)
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { nil }
    override func layoutSubviews() {
        super.layoutSubviews()
        globe.frame = CGRect(x: 4, y: (bounds.height-20)/2+1, width: 20, height: 20)
        badge.frame = CGRect(x: 15, y: max(1,(bounds.height-20)/2-3), width: 17, height: 11)
    }
    @objc private func tapped() { original?.sendActions(for: .touchUpInside) }
    func sync(_ b: UIButton, anchor: UIView) {
        original = b
        if menu !== b.menu { menu = b.menu }
        let code = UserDefaults.standard.string(forKey: "ayu.extra.translateTo") ?? "en"
        badge.text = String(code.uppercased().prefix(3)); accessibilityValue = code.uppercased()
        globe.tintColor = anchor.tintColor
    }
}
private final class ComposerPlacement {
    weak var bar: UIView?
    weak var original: UIButton?
    weak var anchor: UIView?
    weak var panel: NSObject?
    weak var clip: UIView?
    var baseWidth: Double = 0
    var glyphs: [(UIView,CGAffineTransform)] = []
    let button = TranslateButton()
    private var insetViews = [(UITextView, UIEdgeInsets)]()
    private var changedClip: (UIView, CGRect)?
    let gap: CGFloat = 33
    init(_ bar: UIView) { self.bar = bar }
    private func restoreFallback() {
        for (tv, old) in insetViews {
            if abs(tv.textContainerInset.right-old.right-gap) < 1 { tv.textContainerInset = old }
        }
        insetViews.removeAll()
        if let (v, old) = changedClip, abs(v.frame.width-old.width+gap) < 1 { v.frame = old }
        changedClip = nil
    }
    private func restoreAnchor() {
        restoreFallback()
        for (v, t) in glyphs { v.transform = t }
        glyphs.removeAll()
        if let a = anchor, baseWidth > 0 {
            let changed = nativeSetWidth(ptr(a), baseWidth+Double(gap), baseWidth)
            if changed != 0, a.window != nil, let p = panel { _ = nativeRelayout(ptr(p)) }
        }
        anchor = nil; panel = nil; baseWidth = 0
    }
    func reset() {
        restoreAnchor()
        original?.isHidden = false; original = nil
        button.removeFromSuperview()
        bar?.isUserInteractionEnabled = true
    }
    func place(_ b: UIButton, stack: UIStackView, anchor a: UIView, parent: UIView, panel p: NSObject?, clip c: UIView?) {
        if original !== b { original?.isHidden = false; original = b }
        if anchor !== a {
            restoreAnchor()
            self.anchor = a; self.panel = p; self.clip = c
            let width = nativeWidth(ptr(a))
            if let p, width >= 12, width <= 90, nativeSetWidth(ptr(a), width, width+Double(gap)) != 0 {
                baseWidth = width
                for i: Int32 in [0,1,2,3,4] {
                    if let v = nodeView(object(nativeGlyph(ptr(a),i))), v !== a { glyphs.append((v,v.transform)) }
                }
                _ = nativeRelayout(ptr(p))
            }
        }
        var reserved = baseWidth > 0 && abs(a.bounds.width-CGFloat(baseWidth)-gap)<3
        if !reserved, baseWidth > 0, let p {
            let width = nativeWidth(ptr(a))
            if abs(width-baseWidth)<1 { _ = nativeSetWidth(ptr(a),width,width+Double(gap)) }
            _ = nativeRelayout(ptr(p))
            reserved = abs(a.bounds.width-CGFloat(baseWidth)-gap)<3
        }
        if reserved {
            restoreFallback()
            for (v,t) in glyphs {
                let center = v.center.x
                if abs(center-a.bounds.midX)<5 || v.transform != t { v.transform = t.translatedBy(x: gap/2,y: 0) }
            }
        } else {
            // Public UIKit fallback: reserve the text area's right inset instead of leaving the chip floating.
            if let c, insetViews.isEmpty, changedClip == nil {
                let editors = descendants(c, limit: 350).compactMap { $0 as? UITextView }
                if editors.isEmpty, c.frame.width > 80 {
                    changedClip = (c,c.frame); c.frame.size.width -= gap
                } else {
                    for tv in editors {
                        let old = tv.textContainerInset; insetViews.append((tv,old))
                        var new = old; new.right += gap; tv.textContainerInset = new
                    }
                }
            } else if let (v, old) = changedClip, abs(v.frame.width-old.width)<2 { v.frame.size.width -= gap }
            for (tv, old) in insetViews where abs(tv.textContainerInset.right-old.right)<1 {
                var new = old; new.right += gap; tv.textContainerInset = new
            }
        }
        let frame = CGRect(x: a.frame.minX-(reserved ? 0 : gap), y: a.frame.minY, width: gap, height: a.frame.height)
        guard frame.minX >= parent.bounds.minX-2, frame.height > 15 else { return }
        if button.superview !== parent { button.removeFromSuperview(); parent.addSubview(button) }
        button.frame = frame; parent.bringSubviewToFront(button)
        button.sync(b,anchor:a)
        b.isHidden = true
        bar?.isUserInteractionEnabled = !stack.arrangedSubviews.allSatisfy { $0.isHidden }
    }
}

private final class ArchiveContainer: UIViewController {
    let archive: UIViewController
    init(_ a: UIViewController) { archive = a; super.init(nibName:nil,bundle:nil) }
    required init?(coder: NSCoder) { nil }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let close = UIButton(type: .system); close.setTitle("إغلاق",for:.normal); close.addTarget(self,action:#selector(done),for:.touchUpInside)
        close.translatesAutoresizingMaskIntoConstraints=false
        addChild(archive); archive.view.translatesAutoresizingMaskIntoConstraints=false
        view.addSubview(archive.view); view.addSubview(close); archive.didMove(toParent:self)
        NSLayoutConstraint.activate([
            close.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-20),
            close.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor),
            close.heightAnchor.constraint(equalToConstant:36),
            archive.view.topAnchor.constraint(equalTo:close.bottomAnchor),
            archive.view.bottomAnchor.constraint(equalTo:view.bottomAnchor),
            archive.view.leadingAnchor.constraint(equalTo:view.leadingAnchor),
            archive.view.trailingAnchor.constraint(equalTo:view.trailingAnchor)
        ])
    }
    @objc private func done() { dismiss(animated:true) }
}
private final class HistoryAction: UIView {
    weak var presentation: NSObject?
    weak var chat: UIViewController?
    weak var nativeText: UIView?
    weak var root: UIViewController?
    let label = UILabel(), detail = UILabel()
    init(presentation: NSObject, chat: UIViewController?, root: UIViewController?, nativeText: UIView?, time: String, color: UIColor) {
        self.presentation=presentation; self.chat=chat; self.root=root; self.nativeText=nativeText
        super.init(frame:.zero)
        accessibilityLabel="سجل التعديلات"; isAccessibilityElement=true; accessibilityTraits = .button
        nativeText?.alpha=0
        label.text="سجل التعديلات"; label.textColor=color; label.font = .systemFont(ofSize:16,weight:.medium)
        detail.text=time; detail.textColor=color.withAlphaComponent(0.72); detail.font = .systemFont(ofSize:11)
        detail.adjustsFontSizeToFitWidth=true; detail.minimumScaleFactor=0.65
        for l in [label,detail] { l.isUserInteractionEnabled=false; l.textAlignment = .natural; addSubview(l) }
        addGestureRecognizer(UITapGestureRecognizer(target:self,action:#selector(open(_:))))
    }
    required init?(coder: NSCoder) { nil }
    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame=CGRect(x:0,y:max(0,(bounds.height-35)/2),width:bounds.width,height:20)
        detail.frame=CGRect(x:0,y:label.frame.maxY,width:bounds.width,height:15)
    }
    @objc private func open(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, let p=presentation else { return }
        let chat = self.chat ?? root.flatMap { findChat($0) }
        guard let m=nativeMessage(ptr(p)), let chat, let raw=nativeArchive(ptr(p),m,ptr(chat)) else {
            let presenter = root.map(visibleController) ?? chat
            if let presenter {
                let a=UIAlertController(title:"سجل التعديلات",message:"تعذر الوصول إلى السجل المحلي لهذه الرسالة.",preferredStyle:.alert)
                a.addAction(UIAlertAction(title:"حسناً",style:.default)); presenter.present(a,animated:true)
            }
            return
        }
        guard let archive = Unmanaged<AnyObject>.fromOpaque(raw).takeRetainedValue() as? UIViewController else { return }
        let sel=NSSelectorFromString("dismissTapGesture:")
        if p.responds(to:sel) { _ = p.perform(sel,with:gesture) }
        DispatchQueue.main.asyncAfter(deadline:.now()+0.46) { [weak chat, weak root=self.root] in
            guard let presenter = root.map(visibleController) ?? chat else { return }
            let container=ArchiveContainer(archive); container.modalPresentationStyle = .pageSheet
            presenter.present(container,animated:true)
        }
    }
}

private final class Coordinator: NSObject {
    static let shared=Coordinator()
    var placements=[ObjectIdentifier:ComposerPlacement]()
    var timer: Timer?
    var pending=false, scanning=false
    weak var lastChat: UIViewController?
    func begin() {
        guard timer==nil else { return }
        nativeInstallHooks()
        NotificationCenter.default.addObserver(self,selector:#selector(schedule),name:UIApplication.didBecomeActiveNotification,object:nil)
        NotificationCenter.default.addObserver(self,selector:#selector(schedule),name:UIWindow.didBecomeVisibleNotification,object:nil)
        let t=Timer(timeInterval:0.4,target:self,selector:#selector(tick),userInfo:nil,repeats:true)
        RunLoop.main.add(t,forMode:.common); timer=t
        NSLog("[VGI2] Composer/history loaded; fingerprint=%d",nativeCompatible())
        schedule()
    }
    @objc func schedule() {
        guard !pending else { return }; pending=true
        DispatchQueue.main.async { [weak self] in self?.pending=false; self?.tick() }
    }
    private func isTime(_ s: String) -> Bool {
        let t=s.lowercased()
        return t.contains("تم تعديل")||t.contains("عُدّلت")||t.contains("معدّل")||t.contains("معدلة")||t.contains("edited ")||t.contains("изменено")||t.contains("відредаговано")
    }
    private func history(_ menu: NSObject, menuView: UIView, w: UIWindow) {
        let chat: UIViewController?
        if let raw=nativeChat(ptr(menu)) { chat=Unmanaged<AnyObject>.fromOpaque(raw).takeRetainedValue() as? UIViewController }
        else { chat=findChat(w.rootViewController) ?? lastChat }
        for v in descendants(menuView,limit:3200) {
            guard let n=node(v), kind(n)==5||kind(n)==6 else { continue }
            guard let s=nativeActionText(ptr(n)) else { continue }
            let text=s.assumingMemoryBound(to:String.self).pointee
            guard isTime(text),v.bounds.height>=28 else { continue }
            let tv=nodeView(object(nativeActionLabel(ptr(n))))
            let labelFrame=tv.map { $0.convert($0.bounds,to:v) }
            let start=max(16,min(v.bounds.width-90,labelFrame?.minX ?? 50))
            let frame=CGRect(x:start,y:0,width:max(0,v.bounds.width-start-8),height:v.bounds.height)
            if let old=v.subviews.first(where:{$0 is HistoryAction}) as? HistoryAction { old.frame=frame; tv?.alpha=0; continue }
            let color: UIColor = v.traitCollection.userInterfaceStyle == .dark ? .white : .label
            let overlay=HistoryAction(presentation:menu,chat:chat,root:w.rootViewController,nativeText:tv,time:text,color:color)
            overlay.frame=frame; v.addSubview(overlay); v.bringSubviewToFront(overlay)
        }
    }
    @objc func tick() {
        guard !scanning else { return }; scanning=true; defer { scanning=false }
        // Telegram and sideloaded variants may use windows outside foreground scenes. Never gate the feature on one scene state.
        nativeInstallHooks()
        let app=UIApplication.shared
        guard app.applicationState != .background else { return }
        var windows=app.windows
        windows += app.connectedScenes.compactMap{$0 as? UIWindowScene}.flatMap{$0.windows}
        var seenWindows=Set<ObjectIdentifier>(), seen=Set<ObjectIdentifier>()
        for w in windows where !w.isHidden && w.alpha>0.01 && seenWindows.insert(ObjectIdentifier(w)).inserted {
            let all=descendants(w)
            if let c=findChat(w.rootViewController) { lastChat=c }
            let bars=all.filter{kind($0)==1 && visible($0)}
            let accessories=all.filter{kind($0)==2 && visible($0)}
            for bar in bars {
                guard let stack=descendants(bar,limit:80).compactMap({$0 as? UIStackView}).first,
                      let b=stack.arrangedSubviews.compactMap({$0 as? UIButton}).first(where:{ ($0.configuration?.title?.hasPrefix("→")==true || $0.menu != nil) && $0.menu != nil }) else { continue }
                let barRect=bar.convert(bar.bounds,to:w)
                var candidates=accessories.filter { a in
                    let r=a.convert(a.bounds,to:w)
                    return r.height>=20 && r.height<=70 && abs(r.midY-barRect.midY)<250
                }
                if candidates.isEmpty {
                    for cl in all where cl.layer.name=="textInputNodeClippingContainer" && visible(cl) {
                        let r=cl.convert(cl.bounds,to:w)
                        guard abs(r.midY-barRect.midY)<250, let par=cl.superview else { continue }
                        candidates += par.subviews.filter { $0 is UIControl && visible($0) && $0.bounds.width>=18 && $0.bounds.width<=75 && $0.bounds.height>=20 && $0.bounds.height<=70 }
                    }
                }
                // Native input accessory is rightmost for conventional chat composer. The sibling controls stay intact.
                guard let a=candidates.max(by:{ $0.convert($0.bounds,to:w).midX < $1.convert($1.bounds,to:w).midX }), let parent=a.superview else { continue }
                var view: UIView?=parent, panel: NSObject?
                while let v=view { if let n=node(v), kind(n)==3 { panel=n; break }; view=v.superview }
                let clip = panel.flatMap { object(nativeClip(ptr($0))) as? UIView } ?? parent.subviews.first(where:{$0.layer.name=="textInputNodeClippingContainer"})
                let key=ObjectIdentifier(bar); seen.insert(key)
                let placement=placements[key] ?? ComposerPlacement(bar); placements[key]=placement
                placement.place(b,stack:stack,anchor:a,parent:parent,panel:panel,clip:clip)
            }
            if nativeCompatible() != 0 {
                for v in all { if let n=node(v),kind(n)==4 { history(n,menuView:v,w:w) } }
            }
        }
        for k in Array(placements.keys) where !seen.contains(k) { placements.removeValue(forKey:k)?.reset() }
    }
}
@_cdecl("vgi_views_changed") public func vgiViewsChanged() { DispatchQueue.main.async { Coordinator.shared.schedule() } }
@_cdecl("vgi_start") public func vgiStart() { DispatchQueue.main.async { Coordinator.shared.begin() } }
