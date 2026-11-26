import UIKit
import Foundation

@_silgen_name("vgi_set_slot") private func nativeSetSlot(_ enabled: Int32) -> Int32
@_silgen_name("vgi_editor_view") private func nativeEditorView(_ p: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?
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
@_silgen_name("vgi_archive") private func nativeArchive(_ p: UnsafeMutableRawPointer?, _ m: UnsafeMutableRawPointer, _ c: UnsafeMutableRawPointer?, _ row: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?
@_silgen_name("vgi_editor") private func nativeEditor(_ p: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?
@_silgen_name("vgi_editor_inset") private func nativeEditorInset(_ p: UnsafeMutableRawPointer) -> Double
@_silgen_name("vgi_editor_reserve") private func nativeEditorReserve(_ p: UnsafeMutableRawPointer, _ width: Double, _ expected: Double, _ right: Double) -> Int32
@_silgen_name("vgi_read_row") private func nativeReadRow(_ p: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?
@_silgen_name("vgi_read_is_edit") private func nativeReadIsEdit(_ p: UnsafeMutableRawPointer) -> Int32
@_silgen_name("vgi_read_message") private func nativeReadMessage(_ p: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?
@_silgen_name("vgi_read_text") private func nativeReadText(_ p: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?
@_silgen_name("vgi_read_button") private func nativeReadButton(_ p: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?
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
    // Never request a UIView from a layer-backed ASDisplayNode.
    let layerSel = NSSelectorFromString("isLayerBacked")
    if n.responds(to: layerSel) {
        typealias Getter = @convention(c) (AnyObject, Selector) -> Bool
        if let f=n.method(for:layerSel), unsafeBitCast(f,to:Getter.self)(n,layerSel) { return nil }
    }
    return n.perform(sel)?.takeUnretainedValue() as? UIView
}
private func nodeLayer(_ o: AnyObject?) -> CALayer? {
    if let view=o as? UIView { return view.layer }
    guard let n=o as? NSObject else { return nil }
    let sel=NSSelectorFromString("layer")
    return n.responds(to:sel) ? n.perform(sel)?.takeUnretainedValue() as? CALayer : nil
}
private func maybeNode(_ view: UIView) -> NSObject? { node(view) ?? (kind(view)>0 ? view : nil) }
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
    private var menuCode: String?
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
        let code = UserDefaults.standard.string(forKey: "ayu.extra.translateTo") ?? "en"
        // Swift rebuilds its own UIMenu during layout. Keep the exact same
        // native menu/action objects while the user scrolls. Refresh ONLY
        // on first attachment or a real language selection, not per timer.
        if (menu == nil || menuCode != code), let source = b.menu {
            menu = source; menuCode = code
        }
        let badgeCode = String(code.uppercased().prefix(3))
        if badge.text != badgeCode { badge.text = badgeCode; accessibilityValue = code.uppercased() }
        if globe.tintColor != anchor.tintColor { globe.tintColor = anchor.tintColor }
    }
}
private final class ComposerPlacement {
    weak var bar: UIView?
    weak var original: UIButton?
    weak var panel: NSObject?
    let button = TranslateButton()
    let gap: CGFloat = 34
    private final class Shift {
        weak var view: UIView?
        var base: CGRect
        var placed: CGRect
        init(_ view:UIView,_ base:CGRect,_ placed:CGRect){self.view=view;self.base=base;self.placed=placed}
    }
    private var shifts = [ObjectIdentifier:Shift]()
    init(_ bar: UIView) { self.bar = bar }
    private func close(_ a:CGRect,_ b:CGRect) -> Bool {
        abs(a.minX-b.minX)<0.75 && abs(a.minY-b.minY)<0.75 &&
        abs(a.width-b.width)<0.75 && abs(a.height-b.height)<0.75
    }
    private func restoreShifts(except keep:Set<ObjectIdentifier> = []) {
        for key in Array(shifts.keys) where !keep.contains(key) {
            if let shift=shifts.removeValue(forKey:key),let v=shift.view,close(v.frame,shift.placed) { v.frame=shift.base }
        }
    }
    func reset() {
        restoreShifts()
        original?.isHidden=false; original=nil
        button.removeFromSuperview()
        bar?.isUserInteractionEnabled=true
    }
    func place(_ b:UIButton,stack:UIStackView,anchor a:UIView,parent:UIView,peers:[UIView],
               panel p:NSObject?,editor e:NSObject?,richView:UIView?,slotChanged:Bool) {
        if original !== b { original?.isHidden=false;original=b }
        panel=p
        let frame=CGRect(x:a.frame.minX-gap,y:a.frame.minY,width:gap,height:a.frame.height)
        guard frame.minX>=parent.bounds.minX-2,frame.height>15 else { reset();return }

        // Patch the native text layout, not just the visible view's clipping
        // rectangle. Refresh the real editor once immediately; every later
        // native layout computes the reserved margin itself.
        if slotChanged {
            if let p { _=nativeRelayout(ptr(p)) }
            if let e,let v=(object(nativeEditorView(ptr(e))) as? UIView) ?? richView ?? nodeView(e),
               v.bounds.width>=50 {
                let right=nativeEditorInset(ptr(e))
                if right>=0 && right<=180 { _=nativeEditorReserve(ptr(e),Double(v.bounds.width),right,right) }
            }
        }

        // Native gift/other accessory views live left of emoji. Shift those
        // peers by the exact reserved slot, leaving the emoji fixed. Keep a
        // reversible baseline rather than accumulating offsets on each tick.
        var kept=Set<ObjectIdentifier>()
        for v in peers where v !== a && v.superview === parent && visible(v) {
            let key=ObjectIdentifier(v)
            let old=shifts[key]
            let base=(old != nil && close(v.frame,old!.placed)) ? old!.base : v.frame
            guard base.midX<a.frame.midX && a.frame.minX-base.maxX<180 &&
                abs(base.midY-a.frame.midY)<12 else { continue }
            let target=base.offsetBy(dx:-gap,dy:0)
            guard target.minX>=parent.bounds.minX-2 else { continue }
            kept.insert(key)
            if !close(v.frame,target) { v.frame=target }
            shifts[key]=Shift(v,base,target)
        }
        restoreShifts(except:kept)
        // If the app puts a visible accessory in the proposed slot but it
        // cannot be moved safely, leave the original control intact.
        if peers.contains(where:{$0 !== a && $0.superview === parent && visible($0) &&
            $0.frame.intersects(frame.insetBy(dx:2,dy:2))}) { reset();return }
        if button.superview !== parent {
            button.removeFromSuperview();parent.addSubview(button)
        }
        if !close(button.frame,frame) { button.frame=frame }
        if parent.subviews.last !== button { parent.bringSubviewToFront(button) }
        button.sync(b,anchor:a)
        b.isHidden=true
        bar?.isUserInteractionEnabled = !stack.arrangedSubviews.allSatisfy{ $0.isHidden }
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
private final class HistoryAction: UIButton {
    weak var presentation: NSObject?
    weak var row: NSObject?
    weak var chat: UIViewController?
    weak var nativeText: CALayer?
    weak var root: UIViewController?
    let label=UILabel(),detail=UILabel()
    init(presentation:NSObject?,row:NSObject?,chat:UIViewController?,root:UIViewController?,nativeText:CALayer?,time:String,color:UIColor) {
        self.presentation=presentation;self.row=row;self.chat=chat;self.root=root;self.nativeText=nativeText
        super.init(frame:.zero)
        accessibilityLabel="سجل التعديلات";accessibilityTraits = .button;isAccessibilityElement=true
        label.text="سجل التعديلات";label.textColor=color;label.font = .systemFont(ofSize:16,weight:.medium)
        detail.text=time.isEmpty ? "عرض النص قبل التعديل" : time
        detail.textColor=color.withAlphaComponent(0.72);detail.font = .systemFont(ofSize:11)
        detail.adjustsFontSizeToFitWidth=true;detail.minimumScaleFactor=0.65
        for l in [label,detail] { l.isUserInteractionEnabled=false;l.textAlignment = .natural;addSubview(l) }
        addTarget(self,action:#selector(open),for:.touchUpInside)
    }
    required init?(coder:NSCoder){nil}
    deinit { nativeText?.opacity=1 }
    override func layoutSubviews(){
        super.layoutSubviews()
        label.frame=CGRect(x:0,y:max(0,(bounds.height-35)/2),width:bounds.width,height:20)
        detail.frame=CGRect(x:0,y:label.frame.maxY,width:bounds.width,height:15)
    }
    @objc private func open(){
        let p=presentation
        let chat=self.chat ?? root.flatMap{findChat($0)}
        let rowPtr=row.map(ptr)
        let menuPtr=p.map(ptr)
        let message=rowPtr.flatMap{nativeReadMessage($0)} ?? menuPtr.flatMap{nativeMessage($0)}
        guard let m=message,let raw=nativeArchive(menuPtr,m,chat.map(ptr),rowPtr),
              let archive=Unmanaged<AnyObject>.fromOpaque(raw).takeRetainedValue() as? UIViewController else {
            let presenter=root.map(visibleController) ?? chat
            if let presenter {
                let a=UIAlertController(title:"سجل التعديلات",message:"تعذر فتح السجل المحلي لهذه الرسالة.",preferredStyle:.alert)
                a.addAction(UIAlertAction(title:"حسناً",style:.default));presenter.present(a,animated:true)
            }
            return
        }
        // Dismiss the native context menu before presenting an independent sheet.
        if let p {
            let sel=NSSelectorFromString("dismissTapGesture:")
            if p.responds(to:sel) {
                let g=UITapGestureRecognizer()
                _=p.perform(sel,with:g)
            }
        }
        if let controller=root.map(visibleController),NSStringFromClass(type(of:controller)).contains("ContextControllerImpl") {
            controller.dismiss(animated:true)
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+0.5){[weak chat,weak root=self.root] in
            guard let presenter=chat.map(visibleController) ?? root.map(visibleController) else{return}
            let container=ArchiveContainer(archive);container.modalPresentationStyle = .pageSheet
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
        NotificationCenter.default.addObserver(self,selector:#selector(schedule),name:UITextView.textDidChangeNotification,object:nil)
        let t=Timer(timeInterval:0.4,target:self,selector:#selector(tick),userInfo:nil,repeats:true)
        RunLoop.main.add(t,forMode:.common); timer=t
        NSLog("[VGI4] Composer/history loaded; fingerprint=%d",nativeCompatible())
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
    private func history(_ w:UIWindow,all:[UIView]){
        var menu:NSObject?
        // The actual edit-time header is a custom context item, not a ContextMenuActionItem.
        for v in all { if let n=maybeNode(v),kind(n)==4 { menu=n;break } }
        let chat: UIViewController?
        if let p=menu,let raw=nativeChat(ptr(p)) { chat=Unmanaged<AnyObject>.fromOpaque(raw).takeRetainedValue() as? UIViewController }
        else { chat=findChat(w.rootViewController) ?? lastChat }
        var seenRows=Set<ObjectIdentifier>()
        for v in all {
            guard let n=maybeNode(v),let r=object(nativeReadRow(ptr(n))) as? NSObject,
                nativeReadIsEdit(ptr(r)) != 0, nativeReadMessage(ptr(r)) != nil,seenRows.insert(ObjectIdentifier(r)).inserted else { continue }
            let rowView=nodeView(r) ?? v
            let btn=nodeView(object(nativeReadButton(ptr(r))))
            let host=(rowView.bounds.height>=25 && rowView.bounds.height<=110) ? rowView : (btn?.superview ?? rowView)
            guard visible(host),host.bounds.width>=100,host.bounds.height>=25,host.bounds.height<=110 else{continue}
            let layer=nodeLayer(object(nativeReadText(ptr(r))))
            let labelFrame=layer.map{$0.convert($0.bounds,to:host.layer)}
            let start=max(16,min(host.bounds.width-90,labelFrame?.minX ?? 48))
            let frame=CGRect(x:start,y:0,width:max(0,host.bounds.width-start-8),height:host.bounds.height)
            if let old=host.subviews.first(where:{$0 is HistoryAction}) as? HistoryAction {
                old.frame=frame;layer?.opacity=0;host.bringSubviewToFront(old);continue
            }
            let color:UIColor=host.traitCollection.userInterfaceStyle == .dark ? .white : .label
            let overlay=HistoryAction(presentation:menu,row:r,chat:chat,root:w.rootViewController,nativeText:layer,time:"عرض النص قبل التعديل",color:color)
            overlay.frame=frame;host.addSubview(overlay);host.bringSubviewToFront(overlay);layer?.opacity=0
        }
        // Keep the old action-item path for variants that use an ordinary row.
        guard let p=menu else{return}
        for v in all {
            guard let n=maybeNode(v),kind(n)==5||kind(n)==6,let raw=nativeActionText(ptr(n)) else{continue}
            let text=raw.assumingMemoryBound(to:String.self).pointee
            guard isTime(text),v.bounds.height>=28,v.subviews.allSatisfy({!($0 is HistoryAction)}) else{continue}
            let layer=nodeLayer(object(nativeActionLabel(ptr(n))))
            let start=max(16,min(v.bounds.width-90,layer.map{$0.convert($0.bounds,to:v.layer).minX} ?? 48))
            let overlay=HistoryAction(presentation:p,row:nil,chat:chat,root:w.rootViewController,nativeText:layer,time:text,color:v.traitCollection.userInterfaceStyle == .dark ? .white : .label)
            overlay.frame=CGRect(x:start,y:0,width:v.bounds.width-start-8,height:v.bounds.height)
            v.addSubview(overlay);v.bringSubviewToFront(overlay);layer?.opacity=0
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
                var view:UIView?=parent,panel:NSObject?
                while let v=view { if let n=maybeNode(v),kind(n)==3 { panel=n;break };view=v.superview }
                let ar=a.convert(a.bounds,to:w)
                if panel==nil {
                    panel=all.compactMap{v->NSObject? in
                        guard let n=maybeNode(v),kind(n)==3 else{return nil}
                        let r=v.convert(v.bounds,to:w);return abs(r.maxY-ar.midY)<180 ? n:nil
                    }.first
                }
                let clip=panel.flatMap{nodeView(object(nativeClip(ptr($0))))} ??
                    all.first(where:{$0.layer.name=="textInputNodeClippingContainer" && abs($0.convert($0.bounds,to:w).midY-ar.midY)<120})
                var editor=panel.flatMap{object(nativeEditor(ptr($0))) as? NSObject}
                let local=clip.map{descendants($0,limit:500)} ?? all
                if editor==nil {
                    editor=local.compactMap{v->NSObject? in
                        guard let n=maybeNode(v),kind(n)==10,abs(v.convert(v.bounds,to:w).midY-ar.midY)<140 else{return nil}
                        return n
                    }.first
                }
                let richView=local.first(where:{kind($0)==11 && visible($0) && abs($0.convert($0.bounds,to:w).midY-ar.midY)<140})
                let state=nativeSetSlot(1)
                guard state>=0 else { continue }
                let key=ObjectIdentifier(bar);seen.insert(key)
                let placement=placements[key] ?? ComposerPlacement(bar);placements[key]=placement
                placement.place(b,stack:stack,anchor:a,parent:parent,peers:candidates,panel:panel,editor:editor,richView:richView,slotChanged:state==1)
            }
            if nativeCompatible() != 0 { history(w,all:all) }
        }
        var oldPanels=[NSObject]()
        for k in Array(placements.keys) where !seen.contains(k) {
            if let placement=placements.removeValue(forKey:k) {
                if let p=placement.panel { oldPanels.append(p) }
                placement.reset()
            }
        }
        if seen.isEmpty && nativeSetSlot(0)==1 {
            for p in oldPanels { _=nativeRelayout(ptr(p)) }
        }
    }
}
@_cdecl("vgi_views_changed") public func vgiViewsChanged() { DispatchQueue.main.async { Coordinator.shared.schedule() } }
@_cdecl("vgi_start") public func vgiStart() { DispatchQueue.main.async { Coordinator.shared.begin() } }
