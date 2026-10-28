#include "user_api.h"
#include "types.h"

static char filename[128];
static char buffer[4096];
static char input[64];
static uint64_t length = 0;

static uint64_t slen(const char* s) { uint64_t n=0; if (s) while(s[n]) ++n; return n; }
static void puts_u(const char* s) { if (s) user_write(s, slen(s)); }
static void putc_u(char c) { user_write(&c,1); }
static void redraw() {
    puts_u("\r\n--- RioOS nano (RV64) ---\r\nFile: "); puts_u(filename);
    puts_u("\r\nCTRL+S save | CTRL+X exit | Backspace erase\r\n--------------------------------\r\n");
    if (length) user_write(buffer,length);
    puts_u("\r\n--------------------------------\r\n");
}
extern "C" void _start() {
    int64_t argn = (int64_t)user_syscall2(USER_SYS_GETARG,(uint64_t)filename,sizeof(filename));
    if (argn <= 0) {
        const char* fallback="untitled.txt"; uint64_t i=0; while(fallback[i]) {filename[i]=fallback[i]; ++i;} filename[i]=0;
    }
    int64_t got = (int64_t)user_syscall3(USER_SYS_FILE_READ,(uint64_t)filename,(uint64_t)buffer,sizeof(buffer)-1);
    if (got > 0) length=(uint64_t)got; else if (got < 0 && got != -2) { puts_u("nano: could not read file (error "); putc_u('-'); putc_u((char)('0' + (-got)%10)); puts_u(")\r\n"); user_syscall1(USER_SYS_EXIT,1); }
    redraw();
    for (;;) {
        int64_t n=(int64_t)user_read(input,sizeof(input));
        if (n<=0) { user_syscall0(USER_SYS_UPTIME); continue; }
        for (int64_t j=0;j<n;++j) {
            unsigned char c=(unsigned char)input[j];
            if (c==24) { puts_u("\r\nLeaving nano.\r\n"); user_syscall1(USER_SYS_EXIT,0); for (;;) {} }
            if (c==19 || c==15) {
                int64_t wr=(int64_t)user_syscall3(USER_SYS_FILE_WRITE,(uint64_t)filename,(uint64_t)buffer,length);
                if (wr<0) puts_u("\r\nSave failed.\r\n"); else puts_u("\r\nSaved.\r\n");
                redraw(); continue;
            }
            if (c==8 || c==127) { if (length) --length; redraw(); continue; }
            if (c=='\r') c='\n';
            if (c=='\n' || (c>=32 && c<=126)) {
                if (length < sizeof(buffer)-1) buffer[length++]=(char)c;
                redraw();
            }
        }
    }
}
