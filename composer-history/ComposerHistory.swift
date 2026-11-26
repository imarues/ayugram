import UIKit
import Foundation

@_silgen_name("vgi_kira_has_history") private func kiraHasHistory(_ key:UnsafeMutableRawPointer) -> Int32
@_silgen_name("vgi_kira_show_history") private func kiraShowHistory(_ key:UnsafeMutableRawPointer,_ host:UnsafeMutableRawPointer) -> Int32
@_silgen_name("vgi_set_slot") private func nativeSetSlot(_ enabled: Int32) -> Int32
@_silgen_name("vgi_panel_writable") private func nativePanelWritable(_ p: UnsafeMutableRawPointer) -> Int32
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
// Match only known native message/header types, reading direct fields with
// bounded Swift Mirror when a resilient ASDisplayNode has no native view.
private func child(_ value:Any,_ name:String) -> Any? {
    var mirror:Mirror?=Mirror(reflecting:value)
    for _ in 0..<8 {
        guard let m=mirror else{return nil}
        if let field=m.children.first(where:{$0.label==name}) { return field.value }
        mirror=m.superclassMirror
    }
    return nil
}
private func editRowMessage(_ row:NSObject) -> AnyObject? {
    if let m=object(nativeReadMessage(ptr(row))) { return m }
    guard NSStringFromClass(type(of:row)).contains("ChatReadReportContextItemNode"),
          let item=child(row,"item"),child(item,"isEdit") as? Bool == true,
          let value=child(item,"message"),String(describing:type(of:value))=="Message" else{return nil}
    return value as AnyObject
}
private func kiraHistoryKey(_ message:AnyObject) -> NSString? {
    guard let mid=child(message,"id"), let peer=child(mid,"peerId"),
          let ns=child(peer,"namespace").flatMap({child($0,"rawValue")}),
          let ident=child(peer,"id").flatMap({child($0,"rawValue")}) as? Int64,
          let msgNs=child(mid,"namespace") as? Int32, msgNs==0,
          let id=child(mid,"id") as? Int32,id>0 else{return nil}
    let namespace=(ns as? UInt32).map{Int32(bitPattern:$0)} ?? (ns as? Int32)
    guard let namespace, (0...2).contains(namespace),ident>0 else{return nil}
    let prefix=["u","g","c"][Int(namespace)]
    return "\(prefix)\(ident):\(id)" as NSString
}
private func nativeSubnodes(_ object:NSObject)->[NSObject] {
    let sel=NSSelectorFromString("subnodes")
    guard object.responds(to:sel) else{return []}
    return object.perform(sel)?.takeUnretainedValue() as? [NSObject] ?? []
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
    weak var accessory: UIView?
    let button = TranslateButton()
    let gap: CGFloat = 34
    private var baseWidth: Double?
    private var originalWasHidden=false
    private var originalBarInteraction=true
    private var glyphShifts=[ObjectIdentifier:(CALayer,CATransform3D,CATransform3D)]()
    init(_ bar:UIView) { self.bar=bar; originalBarInteraction=bar.isUserInteractionEnabled }
    private func close(_ a:Double,_ b:Double)->Bool { abs(a-b)<0.75 }
    private func restoreGlyphs(){
        for (_,entry) in glyphShifts where CATransform3DEqualToTransform(entry.0.transform,entry.2) {
            entry.0.transform=entry.1
        }
        glyphShifts.removeAll()
    }
    private func releaseAccessory() {
        button.removeFromSuperview()
        restoreGlyphs()
        if let a=accessory,let base=baseWidth {
            let current=nativeWidth(ptr(a))
            if close(current,base+Double(gap)) && nativeSetWidth(ptr(a),current,base) != 0,
               let p=panel { _=nativeRelayout(ptr(p)) }
        }
        accessory=nil;panel=nil;baseWidth=nil
    }
    func reset(){
        releaseAccessory()
        original?.isHidden=originalWasHidden
        original=nil
        bar?.isUserInteractionEnabled=originalBarInteraction
    }
    // A composer may still supply its floating original button in a channel
    // that has no input panel. Suppress it; never place a button over the feed.
    func suppress(_ b:UIButton,stack:UIStackView){
        if original !== b {
            original?.isHidden=originalWasHidden
            original=b;originalWasHidden=b.isHidden
        }
        b.isHidden=true
        bar?.isUserInteractionEnabled = !stack.arrangedSubviews.allSatisfy{$0.isHidden}
    }
    func noInput(_ b:UIButton,stack:UIStackView) {
        releaseAccessory();suppress(b,stack:stack)
    }
    private func alignGlyphs(_ a:UIView,base:CGFloat) {
        // The system centers its existing icon within the widened native
        // accessory. Keep that icon in its original trailing physical slot.
        var kept=Set<ObjectIdentifier>()
        for i in 0..<5 {
            guard let o=object(nativeGlyph(ptr(a),Int32(i))),let layer=nodeLayer(o),
                  layer !== a.layer,layer.superlayer != nil,layer.bounds.width>0 else{continue}
            let id=ObjectIdentifier(layer)
            let previous=glyphShifts[id]
            let origin=(previous != nil && CATransform3DEqualToTransform(layer.transform,previous!.2)) ? previous!.1 : layer.transform
            let actual=layer.convert(CGPoint(x:layer.bounds.midX,y:layer.bounds.midY),to:a.layer).x
            let target=a.bounds.maxX-base/2
            let currentOffset:CGFloat=(previous != nil && CATransform3DEqualToTransform(layer.transform,previous!.2)) ? previous!.2.m41-previous!.1.m41 : 0
            let delta=target-(actual-currentOffset)
            // Preserve native animation transforms and only adjust the
            // expected centered icon; skip non-icon / unrelated layers.
            guard abs(delta)<=gap/2+5 else{continue}
            let transform=CATransform3DTranslate(origin,delta,0,0)
            if !CATransform3DEqualToTransform(layer.transform,transform) {
                CATransaction.begin();CATransaction.setDisableActions(true)
                layer.transform=transform;CATransaction.commit()
            }
            kept.insert(id);glyphShifts[id]=(layer,origin,transform)
        }
        for k in Array(glyphShifts.keys) where !kept.contains(k) {
            if let e=glyphShifts.removeValue(forKey:k),CATransform3DEqualToTransform(e.0.transform,e.2){e.0.transform=e.1}
        }
    }
    func place(_ b:UIButton,stack:UIStackView,anchor a:UIView,panel p:NSObject,clip:UIView) {
        suppress(b,stack:stack)
        if accessory !== a || panel !== p {
            releaseAccessory();accessory=a;panel=p
        }
        let width=nativeWidth(ptr(a))
        guard width>=12,width<=125 else {releaseAccessory();return}
        if let old=baseWidth {
            if !close(width,old+Double(gap)) {baseWidth=width}
        } else {baseWidth=width}
        guard let base=baseWidth,base>=12,base<=90 else {releaseAccessory();return}
        let wanted=base+Double(gap)
        if !close(width,wanted) {
            guard nativeSetWidth(ptr(a),width,wanted) != 0 else{releaseAccessory();return}
            _=nativeRelayout(ptr(p))
        }
        // Do not draw a floating or overlapping substitute. Wait until the
        // native composer has actually allocated the additional width.
        guard close(Double(a.bounds.width),wanted),let parent=a.superview,
              visible(clip),clip.window===a.window else {
            button.removeFromSuperview();return
        }
        let anchorRect=a.convert(a.bounds,to:parent)
        let frame=CGRect(x:anchorRect.minX,y:anchorRect.minY,width:gap,height:anchorRect.height)
        guard frame.height>=20,frame.minX>=parent.bounds.minX-2 else{button.removeFromSuperview();return}
        alignGlyphs(a,base:CGFloat(base))
        if button.superview !== parent {button.removeFromSuperview();parent.addSubview(button)}
        if button.frame != frame {button.frame=frame}
        if parent.subviews.last !== button {parent.bringSubviewToFront(button)}
        button.sync(b,anchor:a)
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
        let message=row.flatMap{editRowMessage($0)} ?? menuPtr.flatMap{object(nativeMessage($0))}
        let key=message.flatMap{kiraHistoryKey($0)}
        let hasKira=key.map{kiraHasHistory(ptr($0)) != 0} ?? false
        let archive:UIViewController? = hasKira ? nil : message.flatMap{m in
            guard let raw=nativeArchive(menuPtr,ptr(m),chat.map(ptr),rowPtr) else{return nil}
            return Unmanaged<AnyObject>.fromOpaque(raw).takeRetainedValue() as? UIViewController
        }
        guard hasKira || archive != nil else {
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
            if let key,hasKira,kiraShowHistory(ptr(key),ptr(presenter)) != 0 { return }
            guard let archive else{return}
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
        NSLog("[VGI5] Composer/history loaded; fingerprint=%d",nativeCompatible())
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
        var seenRows=Set<ObjectIdentifier>(),seenNodes=Set<ObjectIdentifier>()
        var pairs=[(NSObject,UIView)]()
        for v in all {
            if let n=maybeNode(v),[4,5,6,8,9].contains(kind(n)),seenNodes.insert(ObjectIdentifier(n)).inserted {
                pairs.append((n,v))
            }
        }
        var cursor=0
        while cursor<pairs.count && pairs.count<900 {
            let (n,v)=pairs[cursor];cursor+=1
            for sub in nativeSubnodes(n) where seenNodes.insert(ObjectIdentifier(sub)).inserted {
                pairs.append((sub,nodeView(sub) ?? v))
            }
        }
        for (n,v) in pairs {
            let candidate=object(nativeReadRow(ptr(n))) as? NSObject
            guard let r=candidate ?? (NSStringFromClass(type(of:n)).contains("ChatReadReportContextItemNode") ? n:nil),
                editRowMessage(r) != nil,seenRows.insert(ObjectIdentifier(r)).inserted else{continue}
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
            // Associate an accessory with its actual writable native input
            // panel, never with unrelated controls in the same window.
            let panels=all.compactMap { v -> (NSObject,UIView,UIView)? in
                guard visible(v),let n=maybeNode(v),kind(n)==3,nativePanelWritable(ptr(n)) != 0,
                      let clip=object(nativeClip(ptr(n))) as? UIView,visible(clip) else{return nil}
                return (n,v,clip)
            }
            for bar in bars {
                guard let stack=descendants(bar,limit:80).compactMap({$0 as? UIStackView}).first,
                      let b=stack.arrangedSubviews.compactMap({$0 as? UIButton}).first(where:{ ($0.configuration?.title?.hasPrefix("→")==true || $0.menu != nil) && $0.menu != nil }) else { continue }
                let key=ObjectIdentifier(bar);seen.insert(key)
                let placement=placements[key] ?? ComposerPlacement(bar);placements[key]=placement
                let barRect=bar.convert(bar.bounds,to:w)
                let barChat=nearestController(bar)
                let eligible=panels.filter { _,host,clip in
                    let rect=clip.convert(clip.bounds,to:w)
                    return rect.width>=50 && abs(rect.maxY-barRect.midY)<180 &&
                        (barChat==nil || nearestController(host)===barChat)
                }
                guard let (panel,host,clip)=eligible.min(by:{
                    abs($0.2.convert($0.2.bounds,to:w).maxY-barRect.midY) < abs($1.2.convert($1.2.bounds,to:w).maxY-barRect.midY)
                }) else {placement.noInput(b,stack:stack);continue}
                let clipRect=clip.convert(clip.bounds,to:w)
                let candidates=descendants(host,limit:700).filter{a in
                    guard kind(a)==2,visible(a) else{return false}
                    let r=a.convert(a.bounds,to:w)
                    return r.height>=20 && r.height<=70 && abs(r.midY-clipRect.maxY)<70 &&
                        nativeWidth(ptr(a))>=12
                }
                guard let anchor=candidates.max(by:{$0.convert($0.bounds,to:w).maxX < $1.convert($1.bounds,to:w).maxX}) else {
                    placement.noInput(b,stack:stack);continue
                }
                placement.place(b,stack:stack,anchor:anchor,panel:panel,clip:clip)
            }
            if nativeCompatible() != 0 { history(w,all:all) }
        }
        for k in Array(placements.keys) where !seen.contains(k) {
            placements.removeValue(forKey:k)?.reset()
        }
    }
}
@_cdecl("vgi_views_changed") public func vgiViewsChanged() { DispatchQueue.main.async { Coordinator.shared.schedule() } }
@_cdecl("vgi_start") public func vgiStart() { DispatchQueue.main.async { Coordinator.shared.begin() } }
