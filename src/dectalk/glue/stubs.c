/* DOS/host port glue: the ARM7 build maps printf in the PH stage to these, which must exist. */
#include <stdarg.h>
int error_func_printf(const char *fmt, ...) { (void)fmt; return 0; }
int error_func_WINprintf(const char *fmt, ...) { (void)fmt; return 0; }
