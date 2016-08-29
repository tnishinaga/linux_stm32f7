/*
 *  linux/arch/arm/mm/cache-v7.S
 *
 *  Copyright (C) 2001 Deep Blue Solutions Ltd.
 *  Copyright (C) 2005 ARM Ltd.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 *
 *  This is the "shell" of the ARMv7 processor support.
*/
#include <linux/linkage.h>
#include <linux/init.h>
#include <asm/assembler.h>
#include <asm/errno.h>
#include <asm/unwind.h>
#include <asm/v7m.h>

#include "proc-macros.S"

/*
 * The secondary kernel init calls v7_flush_dcache_all before it enables
 * the L1; however, the L1 comes out of reset in an undefined state, so
 * the clean + invalidate performed by v7_flush_dcache_all causes a bunch
 * of cache lines with uninitialized data and uninitialized tags to get
 * written out to memory, which does really unpleasant things to the main
 * processor.  We fix this by performing an invalidate, rather than a
 * clean + invalidate, before jumping into the kernel.
 *
 * This function is cloned from arch/arm/mach-tegra/headsmp.S, and needs
 * to be called for both secondary cores startup and primary core resume
 * procedures.
 */
ENTRY(v7m_invalidate_l1)
       mov     r0, #0
       ldr     r7, =BASEADDR_V7M_SCS
       str     r0, [r7, #V7M_SCS_CSSELR] @ select L1 cache
       dsb
       ldr     r0, [r7, #V7M_SCS_CCSIDR] @ read data cache size information

       movw    r1, #0x7fff
       and     r2, r1, r0, lsr #13

       movw    r1, #0x3ff

       and     r3, r1, r0, lsr #3      @ NumWays - 1
       add     r2, r2, #1              @ NumSets

       and     r0, r0, #0x7
       add     r0, r0, #4      @ SetShift

       clz     r1, r3          @ WayShift
       add     r4, r3, #1      @ NumWays
1:     sub     r2, r2, #1      @ NumSets--
       mov     r3, r4          @ Temp = NumWays
2:     subs    r3, r3, #1      @ Temp--
       mov     r5, r3, lsl r1
       mov     r6, r2, lsl r0
       orr     r5, r5, r6      @ Reg = (Temp<<WayShift)|(NumSets<<SetShift)
       str     r5, [r7, #V7M_SCS_DCISW]
       bgt     2b
       cmp     r2, #0
       bgt     1b
       dsb     st
       isb
       ret     lr
ENDPROC(v7m_invalidate_l1)


/*
 *	v7_flush_icache_all()
 *
 *	Flush the whole I-cache.
 *
 *	Registers:
 *	r0 - set to 0
 *  r1 - set to ICIALLU address
 */
ENTRY(v7m_flush_icache_all)
  dsb
  ldr r1, =BASEADDR_V7M_SCS
  movs r0, #0
  /* Invalidate I-Cache */
  str r0, [r1, #V7M_SCS_ICIALLU]
  /* Invalidate branch predictor */
  str r0, [r1, #V7M_SCS_BPIALL]
  dsb
  isb
  ret lr
ENDPROC(v7m_flush_icache_all)

/*
 *	v7_flush_dcache_all()
 *
 *	Flush the whole D-cache.
 *
 *	Corrupted registers: r0-r7, r9-r11 (r6 only in Thumb mode)
 *
 *	- mm    - mm_struct describing address space
 */
@ENTRY(v7m_flush_dcache_all)
@  dmb
@ENDPROC(v7m_flush_dcache_all)

/*
 *	v7_flush_cache_all()
 *
 *	Flush the entire cache system.
 *  The data cache flush is now achieved using atomic clean / invalidates
 *  working outwards from L1 cache. This is done using Set/Way based cache
 *  maintenance instructions.
 *  The instruction cache can still be invalidated back to the point of
 *  unification in a single instruction.
 *
 */
ENTRY(v7m_flush_kern_cache_all)
  push {r4-r7, r9-r11, lr}

  dmb  @ ensure ordering with previous memory accesses
  ldr r0, =BASEADDR_V7M_SCS
  movs r1, #0
  /* Get D-cache configuration */
  str r1, [r0, #V7M_SCS_CSSELR]
  dsb
  /* r1: CCSIDR */
  ldr r1, [r0, #V7M_SCS_CCSIDR]
  /* Get NumSets from CCSIDR[27:13] */
  /* r2: NumSets */
  movw r2, #0x7fff
  ands r2, r2, r1, lsr #13
  /* Get Associativity from CCSIDR[12:3] */
  /* r3: Associativity */
  movw r3, #0x3ff
  ands r3, r3, r1, lsr #3
  /* Get LineSize from CCSIDR[2:0] */
  and r1, r1, #7
  /* r1: set_shift */
  add r1, r1, #4  @ add 4 (line length offset)
  /* r4: way_shift = 32 - log2(Associativity) */
  clz r4, r3  @ find bit position of way size increment

  /* Flush(clean and invalidate to PoC) all D-cache set/ways */
  mov r5, r2 @ Set set index number
set_loop:
  mov r6, r3 @ Set way index number
  lsl r9, r5, r1  @ set << set_shift
way_loop:
  lsl r7, r6, r4  @ way << way_shift
  orr r7, r7, r9
  str r7, [r0, #V7M_SCS_DCCISW]
  subs r6, r5, #1 @ decrement the way
  bge way_loop
  subs r5, r5, #1 @ decrement the set
  bge set_loop

  mov r1, #0
  /* Invalidate all I-Cache */
  str r1, [r0, #V7M_SCS_ICIALLU]

  /* Invalidate Branch predictor */
  str r1, [r0, #V7M_SCS_BPIALL]

  dsb
  isb


  pop {r4-r7, r9-r11, lr}
  ret lr
ENDPROC(v7m_flush_kern_cache_all)

/*
 *	v7m_flush_cache_all()
 *
 *	Flush all TLB entries in a particular address space
 *
 *	- mm    - mm_struct describing address space
 */
ENTRY(v7m_flush_user_cache_all)
	/*FALLTHROUGH*/

/*
 *	v7m_flush_cache_range(start, end, flags)
 *
 *	Flush a range of TLB entries in the specified address space.
 *
 *	- start - start address (may not be aligned)
 *	- end   - end address (exclusive, may not be aligned)
 *	- flags	- vm_area_struct flags describing address space
 *
 *	It is assumed that:
 *	- we have a VIPT cache.
 */
ENTRY(v7m_flush_user_cache_range)
	ret	lr
ENDPROC(v7m_flush_user_cache_all)
ENDPROC(v7m_flush_user_cache_range)


/*
 *	v7m_coherent_kern_range(start,end)
 *
 *	Ensure that the I and D caches are coherent within specified
 *	region.  This is typically used when code has been written to
 *	a memory region, and will be executed.
 *
 *	- start   - virtual start address of region
 *	- end     - virtual end address of region
 *
 *	It is assumed that:
 *	- the Icache does not read data from the write buffer
 */
ENTRY(v7m_coherent_kern_range)
	/* FALLTHROUGH */

/*
 * dcache_line_size - get the minimum D-cache line size from the CTR register
 * on ARMv7M.
 */
	.macro	v7m_dcache_line_size, reg, tmp
  ldr \reg, =BASEADDR_V7M_SCS
  ldr \tmp, [\reg, #V7M_SCS_CTR]
	lsr	\tmp, \tmp, #16
	and	\tmp, \tmp, #0xf		@ cache line size encoding
	mov	\reg, #4			@ bytes per word
	mov	\reg, \reg, lsl \tmp		@ actual cache line size
	.endm

/*
 * icache_line_size - get the minimum I-cache line size from the CTR register
 * on ARMv7.
 */
	.macro	v7m_icache_line_size, reg, tmp
  ldr \reg, =BASEADDR_V7M_SCS
  ldr \tmp, [\reg, #V7M_SCS_CTR]
	and	\tmp, \tmp, #0xf		@ cache line size encoding
	mov	\reg, #4			@ bytes per word
	mov	\reg, \reg, lsl \tmp		@ actual cache line size
	.endm

/*
 *	v7m_coherent_user_range(start,end)
 *
 *	Ensure that the I and D caches are coherent within specified
 *	region.  This is typically used when code has been written to
 *	a memory region, and will be executed.
 *
 *	- start   - virtual start address of region
 *	- end     - virtual end address of region
 *
 *	It is assumed that:
 *	- the Icache does not read data from the write buffer
 */
ENTRY(v7m_coherent_user_range)
 UNWIND(.fnstart		)
 push {r4}
 mov r4, r0 @ backup
 v7m_dcache_line_size r2, r3
 ldr r3, =BASEADDR_V7M_SCS
1:
  str r0, [r3, #V7M_SCS_DCCMVAC]
  add r0, r0, r2  @ start += minimum line size
  cmp r0, r1  @ if start < end
  blo 1b
  dsb

  mov r0, r4  @ restore
  v7m_icache_line_size r2, r4
2:
  str r0, [r3, #V7M_SCS_ICIMVAU]
  add r0, r0, r2  @ start += minimum line size
  cmp r0, r1  @ if start < end
  blo 2b

 dsb
 isb
 pop {r4}
 ret	lr
 UNWIND(.fnend		)
ENDPROC(v7m_coherent_kern_range)
ENDPROC(v7m_coherent_user_range)

/*
 *	v7m_flush_kern_dcache_area(void *addr, size_t size)
 *
 *	Ensure that the data held in the page kaddr is written back
 *	to the page in question.
 *
 *	- addr	- kernel address
 *	- size	- region size
 */
ENTRY(v7m_flush_kern_dcache_area)
  v7m_dcache_line_size r2, r3
  add	r1, r0, r1
  sub	r3, r2, #1
  bic	r0, r0, r3
  ldr r3, =BASEADDR_V7M_SCS
1:
  @ clean & invalidate D line / unified line
  str r0, [r3, #V7M_SCS_DCCIMVAC]
  add r0, r0, r2
  cmp r0, r1
  blo 1b
  dsb
  ret lr
ENDPROC(v7m_flush_kern_dcache_area)

/*
 *	v7m_dma_inv_range(start,end)
 *
 *	Invalidate the data cache within the specified region; we will
 *	be performing a DMA operation in this region and we want to
 *	purge old data in the cache.
 *
 *	- start   - virtual start address of region
 *	- end     - virtual end address of region
 */
v7m_dma_inv_range:
  push {r4}
  ldr r4, =BASEADDR_V7M_SCS

	v7m_dcache_line_size r2, r3
	sub	r3, r2, #1
	tst	r0, r3
	bic	r0, r0, r3
  str r0, [r4, #V7M_SCS_DCCIMVAC]    @ clean & invalidate D / U line

	tst	r1, r3
	bic	r1, r1, r3
	str r1, [r4, #V7M_SCS_DCCIMVAC]		@ clean & invalidate D / U line
1:
	str r0, [r4, #V7M_SCS_DCIMVAC]		@ invalidate D / U line
	add	r0, r0, r2
	cmp	r0, r1
	blo	1b
	dsb	st
  pop {r4}
	ret	lr
ENDPROC(v7m_dma_inv_range)


/*
 *	v7m_dma_clean_range(start,end)
 *	- start   - virtual start address of region
 *	- end     - virtual end address of region
 */
v7m_dma_clean_range:
  push {r4}
  ldr r4, =BASEADDR_V7M_SCS
	v7m_dcache_line_size r2, r3
	sub	r3, r2, #1
	bic	r0, r0, r3
1:
	str r0, [r4, #V7M_SCS_DCCISW]		@ clean D / U line
	add	r0, r0, r2
	cmp	r0, r1
	blo	1b
	dsb	st
  pop {r4}
	ret	lr
ENDPROC(v7m_dma_clean_range)

/*
 *	v7m_dma_flush_range(start,end)
 *	- start   - virtual start address of region
 *	- end     - virtual end address of region
 */
ENTRY(v7m_dma_flush_range)
  push {r4}
  ldr r4, =BASEADDR_V7M_SCS
	v7m_dcache_line_size r2, r3
	sub	r3, r2, #1
	bic	r0, r0, r3
1:
	str r0, [r4, #V7M_SCS_DCCMVAC]		@ clean & invalidate D / U line
	add	r0, r0, r2
	cmp	r0, r1
	blo	1b
	dsb	st
	ret	lr
ENDPROC(v7m_dma_flush_range)

/*
 *	dma_map_area(start, size, dir)
 *	- start	- kernel virtual start address
 *	- size	- size of region
 *	- dir	- DMA direction
 */
ENTRY(v7m_dma_map_area)
	add	r1, r1, r0
	teq	r2, #DMA_FROM_DEVICE
	beq	v7m_dma_inv_range
	b	v7m_dma_clean_range
ENDPROC(v7m_dma_map_area)

/*
 *	dma_unmap_area(start, size, dir)
 *	- start	- kernel virtual start address
 *	- size	- size of region
 *	- dir	- DMA direction
 */
ENTRY(v7m_dma_unmap_area)
	add	r1, r1, r0
	teq	r2, #DMA_TO_DEVICE
	bne	v7m_dma_inv_range
	ret	lr
ENDPROC(v7m_dma_unmap_area)



/*
*     v7_flush_dcache_louis()
*
*     Flush the D-cache up to the Level of Unification Inner Shareable
*
*     Corrupted registers: r0-r7, r9-r11 (r6 only in Thumb mode)
*/
@ENTRY(v7m_flush_dcache_louis)
@  dmb @ ensure ordering with previous memory accesses
@  ldr
@ENDPROC(v7m_flush_dcache_louis)

@ENTRY(v7m_flush_kern_cache_louis)
@ENDPROC(v7m_flush_kern_cache_louis)


.globl	v7m_flush_kern_cache_louis
.equ	v7m_flush_kern_cache_louis, v7m_flush_kern_cache_all

@ define struct cpu_cache_fns (see <asm/cacheflush.h> and proc-macros.S)
define_cache_functions v7m
