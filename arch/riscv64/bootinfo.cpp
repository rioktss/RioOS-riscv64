#include <stdint.h>

/* Set once by boot.S from the OpenSBI-provided a0/a1 boot arguments. */
extern "C" {
volatile uint64_t rioos_boot_hartid = 0;
volatile uint64_t rioos_boot_dtb = 0;
}
