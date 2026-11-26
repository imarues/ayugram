#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <objc/runtime.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <dispatch/dispatch.h>

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
static const struct mach_header_64 *ui(void){return image("/TelegramUIFramework",ui_uuid);}
int vgi_compatible(void){return ui()!=0&&image("/PostboxFramework",pb_uuid)!=0;}
static Class exact_class(void *obj,const char *name){
    if(!obj)return Nil;
    Class c=object_getClass((id)obj), expected=objc_lookUpClass(name);
    return expected&&c==expected?c:Nil;
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
static double *accessory_width(void *obj){
    if(!ui())return NULL;
    return field(obj,"_TtC22ChatTextInputPanelNode23AccessoryItemIconButton",0x16,3,sizeof(double));
}
double vgi_width(void *obj){double *p=accessory_width(obj);return p?*p:0;}
int vgi_set_width(void *obj,double expected,double value){
    double *p=accessory_width(obj);
    if(!p||*p!=expected||!(expected>=16&&expected<=120)||!(value>=16&&value<=120))return 0;
    *p=value;return 1;
}
void *vgi_archive(void *presentation,void *message){
    const struct mach_header_64 *h=ui(); if(!h||!image("/PostboxFramework",pb_uuid))return NULL;
    const uint8_t *base=(const void*)h;
    // Exact implementation fingerprint: frame prologue, allocation call, storing the 24-byte ID and optional tag.
    if(*(const uint32_t*)(base+0xd85104)!=0xa9bb67fa||
       *(const uint32_t*)(base+0xd85138)!=0x94000663||
       *(const uint32_t*)(base+0xd85448)!=0xa9006119||
       *(const uint32_t*)(base+0xd8544c)!=0xf9000917||
       *(const uint32_t*)(base+0xd85450)!=0x39006116)return NULL;
    uintptr_t *ctx=field(presentation,"_TtC21ContextControllerImpl42ContextControllerExtractedPresentationNode",0xa,2,16);
    uintptr_t *mid=field(message,"_TtC7Postbox7Message",0xa,2,24);
    if(!ctx||!ctx[0]||!ctx[1]||!mid)return NULL;
    uintptr_t args[3]; memcpy(args,mid,24);
    // The two final Int32 fields are namespace and message id. Use only persisted cloud messages.
    if((uint32_t)args[2]!=0||(int32_t)(args[2]>>32)<=0)return NULL;
    typedef void*(*archive_fn)(uintptr_t,uintptr_t,uintptr_t,uintptr_t,uintptr_t,uintptr_t);
    return ((archive_fn)(base+0xd85104))(ctx[0],ctx[1],args[0],args[1],args[2],0);
}
static void activate(void *unused){ (void)unused; vgi_start(); }
__attribute__((constructor)) static void initialize(void){
    dispatch_async_f(dispatch_get_main_queue(),NULL,activate);
}
