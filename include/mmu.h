/*
 * MIT License
 *
 * Copyright (c) 2026 Rio okta kusuma
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files, to deal in the Software
 * without restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies of the
 * Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#ifndef MMU_H
#define MMU_H

#include "types.h"


#define MMU_PAGE_SIZE        4096ULL
#define MMU_USER_BASE        0x47000000ULL
#define MMU_USER_LIMIT       0x47800000ULL
#define MMU_USER_STACK_BASE  0x47F00000ULL
#define MMU_USER_STACK_TOP   0x48000000ULL

/* Permission bits accepted by mmu_user_set_range(). */
#define MMU_USER_READ  1U
#define MMU_USER_WRITE 2U
#define MMU_USER_EXEC  4U

void mmu_init();
int mmu_enabled();
uint64_t mmu_read_sctlr();
uint64_t mmu_read_ttbr0();
uint64_t mmu_read_tcr();
void mmu_status();

int mmu_user_prepare();
int mmu_user_set_range(uint64_t start, uint64_t end, uint32_t flags);
int mmu_user_finish();
int mmu_user_pointer_ok(uint64_t address, uint64_t length, int write);
uint64_t mmu_user_stack_top();

#endif
