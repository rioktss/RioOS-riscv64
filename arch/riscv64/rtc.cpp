#include "rtc.h"

/* QEMU virt's Goldfish RTC exposes nanoseconds since the Unix epoch. */
#define RTC_BASE 0x00101000ULL
#define RTC_TIME_LOW  0x00ULL
#define RTC_TIME_HIGH 0x04ULL

#ifndef HOST_TEST
static volatile uint32_t* const RTC_LOW =
    reinterpret_cast<volatile uint32_t*>(RTC_BASE + RTC_TIME_LOW);
static volatile uint32_t* const RTC_HIGH =
    reinterpret_cast<volatile uint32_t*>(RTC_BASE + RTC_TIME_HIGH);
#endif

uint64_t rtc_get_epoch()
{
#ifdef HOST_TEST
    return 0;
#else
    uint32_t hi1, lo, hi2;
    do {
        hi1 = *RTC_HIGH;
        lo = *RTC_LOW;
        hi2 = *RTC_HIGH;
    } while (hi1 != hi2);
    uint64_t nanoseconds = (static_cast<uint64_t>(hi2) << 32) | lo;
    return nanoseconds / 1000000000ULL;
#endif
}

int rtc_set_epoch(uint64_t epoch)
{
    (void)epoch;
    /* The Goldfish RTC is read-only from S-mode on QEMU virt. */
    return -1;
}
