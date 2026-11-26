#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <objc/runtime.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <dispatch/dispatch.h>
#include <dlfcn.h>

extern void vgi_start(void);
static const uint8_t ui_uuid[16]={0x19,0xf6,0xe4,0xbf,0x5a,0x19,0x3d,0x56,0x9c,0x86,0xa0,0xa1,0xad,0xa2,0x4a,0x52};
static const uint8_t pb_uuid[16]={0x53,0x15,0x44,0x64,0x26,0x25,0x33,0x52,0xaf,0x46,0x32,0x4e,0xd4,0xab,0x14,0xa2};
static const struct mach_header_64 *image(const char *suffix,const uint8_t *uuid) {
    for(uint32_t i=0;i<_dyld_image_count();i++){
        const char *n=_dyld_get_image_name(i); if(!n)continue;
        size_t l=strlen(n),s=strlen(suffix);
        if(l<s||strcmp(n+l-s,suffix))continue;
        const struct mach_header_64 *h=(const void *)_dyld_get_image_header(i);
        if(!h||h->magic!=MH_MAGIC_64)continue;
        const uint8_t *p=(const uint8_t *)(h+1),*e=p+h->sizeofcmds;
        for(uint32_t j=0;j<h->ncmds&&p+sizeof(struct load_command)<=e;j++){
            const struct load_command *c=(const void *)p;
            if(c->cmdsize<sizeof(*c)||c->cmdsize>(size_t)(e-p))break;
            if(c->cmd==LC_UUID&&c->cmdsize>=sizeof(struct uuid_command)&&!memcmp(((const struct uuid_command *)c)->uuid,uuid,16))return h;
            p+=c->cmdsize;
        }
    }
    return 0;
}
static const struct mach_header_64 *ui(void){static const struct mach_header_64 *h=0;if(!h)h=image("/TelegramUIFramework",ui_uuid);return h;}
static const struct mach_header_64 *pb(void){static const struct mach_header_64 *h=0;if(!h)h=image("/PostboxFramework",pb_uuid);return h;}
int vgi_compatible(void){return ui()!=0&&pb()!=0;}
// Exact V4 native layout sites plus executable header trampoline. The byte
// resides in verified, file-backed RW alignment padding (not Swift objects).
// -1: unsupported image, 0: already set, 1: state changed.
int vgi_set_slot(int enabled) {
    const uint8_t *base=(const void*)ui();
    if(!base || *(const uint32_t*)(base+0x2f97b3c)!=0x17422131 ||
        *(const uint32_t*)(base+0x2f97cd8)!=0x174220d2 ||
        *(const uint32_t*)(base+0x2f97ce4)!=0x174220d7 ||
        *(const uint32_t*)(base+0x20000)!=0xb0035990) return -1;
    volatile uint8_t *flag=(volatile uint8_t *)(base+0x6b51c7f);
    uint8_t value=enabled?1:0;
    if(*flag==value)return 0;
    if(*flag>1)return -1;
    *flag=value;
    return 1;
}

static Class exact_class(void *obj,const char *name){
    if(!obj)return Nil;
    Class c=object_getClass((id)obj);
    if(!c)return Nil;
    const char *actual=class_getName(c);
    Class expected=objc_lookUpClass(name);
    if((expected&&c==expected)||(actual&&!strcmp(actual,name)))return c;
    // Swift's Objective-C names may be returned in demangled module.name form.
    if(actual&&name[0]=='_'&&name[1]=='T'&&strchr(actual,'.')){
        const char *tail=strrchr(actual,'.')+1;
        size_t l=strlen(tail),n=strlen(name);
        if(n>=l&&!strcmp(name+n-l,tail)){
            const char *p=name+4; size_t module_len=0;
            while(*p>='0'&&*p<='9'){module_len=module_len*10+(size_t)(*p-'0');p++;}
            if(module_len==(size_t)(strchr(actual,'.')-actual)&&!memcmp(p,actual,module_len))return c;
        }
    }
    return Nil;
}
// Swift's class metadata field-offset vector contains byte offsets, one word each.
// Both UUID and exact runtime class must match before accessing a private field.
static void *field(void *obj,const char *name,size_t vector,size_t index,size_t bytes){
    Class cls=exact_class(obj,name); if(!cls)return NULL;
    const uintptr_t *meta=(const void *)cls;
    size_t size=class_getInstanceSize(cls),off=meta[vector+index];
    if(off<sizeof(void *)||off>size||bytes>size-off)return NULL;
    return (char*)obj+off;
}
// Exact names rather than Swift Mirror: the UIKit object is the source of truth.
int vgi_kind(void *obj){
    if(!obj)return 0;
    Class c=object_getClass((id)obj);
    if(!c)return 0;
    static const char *names[]={
        "_TtC10TelegramUI14AyuComposerBar",
        "_TtC22ChatTextInputPanelNode23AccessoryItemIconButton",
        "_TtC22ChatTextInputPanelNode22ChatTextInputPanelNode",
        "_TtC21ContextControllerImpl42ContextControllerExtractedPresentationNode",
        "_TtC21ContextControllerImpl17ContextActionNode",
        "_TtC21ContextControllerImpl42ContextControllerActionsListActionItemNode",
        "_TtC10TelegramUI18ChatControllerImpl",
        "_TtC10TelegramUIP33_F4622A4AA96A8F4630A22AAB747A555C29ChatReadReportContextItemNode",
        "_TtC21ContextControllerImplP33_0F3557A72401F2D3216C491A5145FE3C42ContextControllerActionsListCustomItemNode",
        "_TtC26ChatRichTextEditorComposer27RichTextEditorChatInputNode",
        "_TtC19RichTextEditorUIKit18RichTextEditorView"
    };
    static Class known[11]={0};
    for(int i=0;i<11;i++)if(known[i]==c)return i+1;
    const char *n=class_getName(c);
    if(!n||((n[0]!='_'||n[1]!='T')&&!strchr(n,'.')))return 0;
    for(int i=0;i<11;i++)if(exact_class(obj,names[i])){known[i]=c;return i+1;}
    return 0;
}
static void *read_object(void *obj,const char *name,size_t vec,size_t i){
    void **p=field(obj,name,vec,i,sizeof(void*));
    return p?*p:0;
}
// Explicitly require a native text-enabled input panel; never migrate the
// translator into broadcast-channel action/search panels.
int vgi_panel_writable(void *panel){
    if(!ui())return 0;
    const char *name="_TtC22ChatTextInputPanelNode22ChatTextInputPanelNode";
    uint8_t *disabled=field(panel,name,0x23,86,1);
    uint8_t *custom=field(panel,name,0x23,104,1);
    uint8_t *deleted=field(panel,name,0x23,91,1);
    return disabled&&custom&&deleted&&!*disabled&&!*custom&&!*deleted;
}
void *vgi_clip(void *panel){
    if(!ui())return 0;
    return read_object(panel,"_TtC22ChatTextInputPanelNode22ChatTextInputPanelNode",0x23,7);
}
void *vgi_editor(void *panel){
    if(!ui())return 0;
    void *obj=read_object(panel,"_TtC22ChatTextInputPanelNode22ChatTextInputPanelNode",0x23,9);
    return vgi_kind(obj)==10?obj:0;
}
void *vgi_editor_view(void *editor){
    if(!ui())return 0;
    return read_object(editor,"_TtC26ChatRichTextEditorComposer27RichTextEditorChatInputNode",0xa,1);
}
static double *editor_inset(void *editor){
    if(!ui())return 0;
    return field(editor,"_TtC26ChatRichTextEditorComposer27RichTextEditorChatInputNode",0xa,5,8);
}
double vgi_editor_inset(void *editor){
    double *p=editor_inset(editor);return p?*p:-1;
}
extern void vgi_editor_layout_call(void *editor,void *fn,double width,double right);
__asm__(".text\n"
        ".p2align 2\n"
        "_vgi_editor_layout_call:\n"
        "stp x20, x30, [sp, #-16]!\n"
        "mov x20, x0\n"
        "blr x1\n"
        "ldp x20, x30, [sp], #16\n"
        "ret\n");
int vgi_editor_reserve(void *editor,double width,double expected,double right){
    const uint8_t *base=(const void*)ui();
    double *p=editor_inset(editor);
    if(!base||!p||*p!=expected||!(width>=50&&width<=2000)||!(right>=0&&right<=250))return 0;
    // This exact native routine stores d1 as trackedRightInset and forwards
    // d1+14 in the actual editor-layout margins. d0 is the editor width.
    if(*(const uint32_t*)(base+0x2f97aec)!=0xd101c3ff||
       *(const uint32_t*)(base+0x2f97b14)!=0xfc286a81||
       *(const uint32_t*)(base+0x2f97b3c)!=0x17422131||
       *(const uint32_t*)(base+0x2f97b6c)!=0xd63f0100)return 0;
    vgi_editor_layout_call(editor,(void*)(base+0x2f97aec),width,right);
    return *p==right;
}
#define READ_ROW "_TtC10TelegramUIP33_F4622A4AA96A8F4630A22AAB747A555C29ChatReadReportContextItemNode"
#define READ_ITEM "_TtC10TelegramUI25ChatReadReportContextItem"
#define CUSTOM_ROW "_TtC21ContextControllerImplP33_0F3557A72401F2D3216C491A5145FE3C42ContextControllerActionsListCustomItemNode"
void *vgi_read_row(void *obj){
    if(!ui())return 0;
    int k=vgi_kind(obj);
    if(k==8)return obj;
    if(k==9){
        void *row=read_object(obj,CUSTOM_ROW,0xa,4);
        return vgi_kind(row)==8?row:0;
    }
    return 0;
}
static void *read_item(void *row){
    return read_object(row,READ_ROW,0xa,0);
}
int vgi_read_is_edit(void *row){
    if(!ui())return 0;
    uint8_t *p=field(read_item(row),READ_ITEM,0xa,3,1);
    return p&&*p==1;
}
void *vgi_read_message(void *row){
    if(!vgi_read_is_edit(row))return 0;
    return read_object(read_item(row),READ_ITEM,0xa,1);
}
void *vgi_read_text(void *row){
    if(!vgi_read_is_edit(row))return 0;
    return read_object(row,READ_ROW,0xa,6);
}
void *vgi_read_button(void *row){
    if(!vgi_read_is_edit(row))return 0;
    return read_object(row,READ_ROW,0xa,15);
}
void *vgi_glyph(void *accessory,int i){
    if(!ui()||i<0||i>4)return 0;
    return read_object(accessory,"_TtC22ChatTextInputPanelNode23AccessoryItemIconButton",0x16,4+i);
}
void *vgi_menu_source(void *presentation){
    if(!ui())return 0;
    uintptr_t *s=field(presentation,"_TtC21ContextControllerImpl42ContextControllerExtractedPresentationNode",0xa,8,16);
    // Native call sites encode .extracted in the witness word, not the object pointer.
    if(!s||!s[0]||(s[1]&0xc000000000000000ULL)!=0x8000000000000000ULL)return 0;
    void *obj=(void*)s[0];
    return exact_class(obj,"_TtC10TelegramUI40ChatMessageContextExtractedContentSource")?obj:0;
}
void *vgi_menu_message(void *presentation){
    void *source=vgi_menu_source(presentation);
    return source?read_object(source,"_TtC10TelegramUI40ChatMessageContextExtractedContentSource",0xa,8):0;
}
void *vgi_menu_chat(void *presentation){
    void *source=vgi_menu_source(presentation);
    if(!source)return 0;
    void *storage=field(source,"_TtC10TelegramUI40ChatMessageContextExtractedContentSource",0xa,5,sizeof(void*));
    if(!storage)return 0;
    typedef void*(*weakload)(void*);
    weakload load=(weakload)dlsym(RTLD_DEFAULT,"swift_unknownObjectWeakLoadStrong");
    return load?load(storage):0; // retained
}
void *vgi_action_text(void *row){
    if(!ui())return 0;
    void *item=0;
    int kind=vgi_kind(row);
    if(kind==5)item=read_object(row,"_TtC21ContextControllerImpl17ContextActionNode",0xa,1);
    else if(kind==6)item=read_object(row,"_TtC21ContextControllerImpl42ContextControllerActionsListActionItemNode",0x4a,4);
    return field(item,"_TtC9ContextUI21ContextMenuActionItem",0xa,1,16);
}
void *vgi_action_label(void *row){
    if(!ui())return 0;
    int kind=vgi_kind(row);
    if(kind==5)return read_object(row,"_TtC21ContextControllerImpl17ContextActionNode",0xa,8);
    if(kind==6)return read_object(row,"_TtC21ContextControllerImpl42ContextControllerActionsListActionItemNode",0x4a,5);
    return 0;
}
static double *accessory_width(void *obj){
    if(!ui())return NULL;
    return field(obj,"_TtC22ChatTextInputPanelNode23AccessoryItemIconButton",0x16,3,sizeof(double));
}
double vgi_width(void *obj){double *p=accessory_width(obj);return p?*p:0;}
int vgi_set_width(void *obj,double expected,double value){
    double *p=accessory_width(obj);
    if(!p||*p!=expected||!(expected>=12&&expected<=125)||!(value>=12&&value<=125))return 0;
    *p=value;return 1;
}
// A verified call site passes ContainedViewLayoutTransition.immediate in an
// indirect 41-byte value and the native panel receiver in Swift's x20.
extern void vgi_layout_call(const void *transition, void *panel, void *fn);
__asm__(".text\n"
        ".p2align 2\n"
        "_vgi_layout_call:\n"
        "stp x20, x30, [sp, #-16]!\n"
        "mov x20, x1\n"
        "blr x2\n"
        "ldp x20, x30, [sp], #16\n"
        "ret\n");
int vgi_relayout(void *panel){
    const struct mach_header_64 *h=ui();
    if(!h||!exact_class(panel,"_TtC22ChatTextInputPanelNode22ChatTextInputPanelNode"))return 0;
    const uint8_t *base=(const void*)h;
    if(*(const uint32_t*)(base+0x29c3eec)!=0xaa1e03e1||
       *(const uint32_t*)(base+0x29c3f0c)!=0x38686a88||
       *(const uint32_t*)(base+0x29c3f10)!=0x37000828||
       *(const uint32_t*)(base+0x29d21a4)!=0x97ffc752)return 0;
    uint8_t *updating=field(panel,"_TtC22ChatTextInputPanelNode22ChatTextInputPanelNode",0x23,60,1);
    if(!updating||*updating)return 0;
    _Alignas(16) uint8_t transition[48]={0};
    transition[40]=0xff;
    vgi_layout_call(transition,panel,(void*)(base+0x29c3eec));
    return 1;
}
void *vgi_archive(void *presentation,void *message,void *chat,void *row){
    const struct mach_header_64 *h=ui(); if(!h||!pb())return NULL;
    const uint8_t *base=(const void*)h;
    // Exact implementation fingerprint: frame prologue, allocation call, storing the 24-byte ID and optional tag.
    if(*(const uint32_t*)(base+0xd85104)!=0xa9bb67fa||
       *(const uint32_t*)(base+0xd85138)!=0x94000663||
       *(const uint32_t*)(base+0xd85448)!=0xa9006119||
       *(const uint32_t*)(base+0xd8544c)!=0xf9000917||
       *(const uint32_t*)(base+0xd85450)!=0x39006116)return NULL;
    uintptr_t *ctx=vgi_read_is_edit(row)?field(read_item(row),READ_ITEM,0xa,0,16):0;
    if(!ctx||!ctx[0]||!ctx[1])ctx=field(presentation,"_TtC21ContextControllerImpl42ContextControllerExtractedPresentationNode",0xa,2,16);
    if(!ctx||!ctx[0]||!ctx[1])ctx=field(chat,"_TtC10TelegramUI18ChatControllerImpl",0x115,8,16);
    uintptr_t *mid=field(message,"_TtC7Postbox7Message",0xa,2,24);
    if(!ctx||!ctx[0]||!ctx[1]||!mid)return NULL;
    uintptr_t args[3]; memcpy(args,mid,24);
    // The two final Int32 fields are namespace and message id. Use only persisted cloud messages.
    if((uint32_t)args[2]!=0||(int32_t)(args[2]>>32)<=0)return NULL;
    typedef void*(*archive_fn)(uintptr_t,uintptr_t,uintptr_t,uintptr_t,uintptr_t,uintptr_t);
    return ((archive_fn)(base+0xd85104))(ctx[0],ctx[1],args[0],args[1],args[2],0);
}
extern void vgi_views_changed(void);
static IMP bar_original=0, accessory_original=0, display_original=0, editor_layout_original=0, accessory_layout_original=0;
static void bar_moved(id self, SEL cmd){if(bar_original)((void(*)(id,SEL))bar_original)(self,cmd); vgi_views_changed();}
static void accessory_moved(id self, SEL cmd){if(accessory_original)((void(*)(id,SEL))accessory_original)(self,cmd); vgi_views_changed();}
static void display_moved(id self, SEL cmd){
    if(display_original)((void(*)(id,SEL))display_original)(self,cmd);
    extern void *vgi_node_for_view(void *);
    void *node=vgi_node_for_view((void*)self);
    int kind=vgi_kind(node);
    if(kind==3||kind==4||kind==5||kind==6||kind==8||kind==9||kind==10)vgi_views_changed();
}
#include <objc/message.h>
// Optional Kira integration: use its own scoped, persisted edit history if
// available. No dependence on Kira when the standalone IPA is installed.
int vgi_kira_has_history(void *key) {
    Class c=objc_lookUpClass("TLParser");
    SEL sel=sel_registerName("editHistoryForKey:");
    if(!c||!key||!class_getClassMethod(c,sel))return 0;
    id array=((id(*)(id,SEL,id))objc_msgSend)((id)c,sel,(id)key);
    SEL count=sel_registerName("count");
    return array && class_getInstanceMethod(object_getClass(array),count) &&
        ((unsigned long(*)(id,SEL))objc_msgSend)(array,count)>0;
}
int vgi_kira_show_history(void *key,void *host) {
    Class c=objc_lookUpClass("LeadEditHistoryViewController");
    SEL sel=sel_registerName("presentForKey:mediaReplaced:from:");
    if(!c||!key||!host||!class_getClassMethod(c,sel)||!vgi_kira_has_history(key))return 0;
    ((void(*)(id,SEL,id,BOOL,id))objc_msgSend)((id)c,sel,(id)key,NO,(id)host);
    return 1;
}

void *vgi_node_for_view(void *view){
    if(!view)return 0;
    SEL sel=sel_registerName("asyncdisplaykit_node");
    Class c=object_getClass((id)view);
    Method m=class_getInstanceMethod(c,sel);
    if(!m)return 0;
    return ((void*(*)(id,SEL))objc_msgSend)((id)view,sel);
}
static void install_moved(const char *className, IMP hook, IMP *original){
    Class c=objc_lookUpClass(className); if(!c||*original)return;
    SEL sel=sel_registerName("didMoveToWindow");
    Method m=class_getInstanceMethod(c,sel); if(!m)return;
    *original=method_getImplementation(m);
    if(!class_addMethod(c,sel,hook,method_getTypeEncoding(m))){
        Method own=class_getInstanceMethod(c,sel);
        *original=method_setImplementation(own,hook);
    }
}
static void editor_did_layout(id self,SEL cmd){
    if(editor_layout_original)((void(*)(id,SEL))editor_layout_original)(self,cmd);
    vgi_views_changed();
}
static void install_editor_layout(void){
    Class c=objc_lookUpClass("_TtC19RichTextEditorUIKit18RichTextEditorView");
    if(!c||editor_layout_original)return;
    SEL sel=sel_registerName("layoutSubviews");
    Method m=class_getInstanceMethod(c,sel);
    if(!m)return;
    editor_layout_original=method_getImplementation(m);
    if(!class_addMethod(c,sel,(IMP)editor_did_layout,method_getTypeEncoding(m))){
        editor_layout_original=method_setImplementation(class_getInstanceMethod(c,sel),(IMP)editor_did_layout);
    }
}
static void accessory_did_layout(id self,SEL cmd){
    if(accessory_layout_original)((void(*)(id,SEL))accessory_layout_original)(self,cmd);
    vgi_views_changed();
}
static void install_accessory_layout(void){
    Class c=objc_lookUpClass("_TtC22ChatTextInputPanelNode23AccessoryItemIconButton");
    if(!c||accessory_layout_original)return;
    SEL sel=sel_registerName("layoutSubviews");
    Method m=class_getInstanceMethod(c,sel);
    if(!m)return;
    accessory_layout_original=method_getImplementation(m);
    if(!class_addMethod(c,sel,(IMP)accessory_did_layout,method_getTypeEncoding(m))){
        accessory_layout_original=method_setImplementation(class_getInstanceMethod(c,sel),(IMP)accessory_did_layout);
    }
}
void vgi_install_hooks(void){
    install_accessory_layout();
    install_editor_layout();
    install_moved("_TtC10TelegramUI14AyuComposerBar",(IMP)bar_moved,&bar_original);
    install_moved("_TtC22ChatTextInputPanelNode23AccessoryItemIconButton",(IMP)accessory_moved,&accessory_original);
    install_moved("_ASDisplayView",(IMP)display_moved,&display_original);
}
static void activate(void *unused){ (void)unused; vgi_start(); }
__attribute__((constructor)) static void initialize(void){
    dispatch_async_f(dispatch_get_main_queue(),NULL,activate);
}
