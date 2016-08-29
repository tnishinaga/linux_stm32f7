#ifndef __ARM_MPU_H
#define __ARM_MPU_H

#ifdef CONFIG_ARM_MPU

/* MPUIR layout */
#define MPUIR_nU		1
#define MPUIR_DREGION		8
#define MPUIR_IREGION		16
#define MPUIR_DREGION_SZMASK	(0xFF << MPUIR_DREGION)
#define MPUIR_IREGION_SZMASK	(0xFF << MPUIR_IREGION)

/* ID_MMFR0 data relevant to MPU */
#define MMFR0_PMSA		(0xF << 4)
#define MMFR0_PMSAv7		(3 << 4)

/* MPU D/I Size Register fields */
#define MPU_RSR_SZ		1
#define MPU_RSR_EN		0

/* The D/I RSR value for an enabled region spanning the whole of memory */
#define MPU_RSR_ALL_MEM		63

/* Individual bits in the DR/IR ACR */
#define MPU_ACR_XN		(1 << 12)
#define MPU_ACR_SHARED		(1 << 2)

/* C, B and TEX[2:0] bits only have semantic meanings when grouped */
#define MPU_RGN_CACHEABLE	0xB
#define MPU_RGN_SHARED_CACHEABLE (MPU_RGN_CACHEABLE | MPU_ACR_SHARED)
#define MPU_RGN_STRONGLY_ORDERED 0

/* Main region should only be shared for SMP */
#ifdef CONFIG_SMP
#define MPU_RGN_NORMAL		(MPU_RGN_CACHEABLE | MPU_ACR_SHARED)
#else
#define MPU_RGN_NORMAL		MPU_RGN_CACHEABLE
#endif

/* Access permission bits of ACR (only define those that we use)*/
#define MPU_AP_PL1RW_PL0RW	(0x3 << 8)
#define MPU_AP_PL1RW_PL0R0	(0x2 << 8)
#define MPU_AP_PL1RW_PL0NA	(0x1 << 8)

/* For minimal static MPU region configurations */
#define MPU_PROBE_REGION	0
#define MPU_BG_REGION		1
#define MPU_RAM_REGION		2
#define MPU_VECTORS_REGION	3

/* Maximum number of regions Linux is interested in */
#define MPU_MAX_REGIONS		16

#define MPU_DATA_SIDE		0
#define MPU_INSTR_SIDE		1

#ifndef __ASSEMBLY__

struct mpu_rgn {
	/* Assume same attributes for d/i-side  */
	u32 drbar;
	u32 drsr;
	u32 dracr;
};

struct mpu_rgn_info {
	u32 mpuir;
	struct mpu_rgn rgns[MPU_MAX_REGIONS];
};
extern struct mpu_rgn_info mpu_rgn_info;

#endif /* __ASSEMBLY__ */

#endif /* CONFIG_ARM_MPU */

#ifdef CONFIG_ARM_V7M_MPU

#define MPU_TYPE	0xE000ED90
#define MPU_CTRL	0xE000ED94
#define MPU_RNR	0xE000ED98
#define MPU_RBAR	0xE000ED9C
#define MPU_RASR	0xE000EDA0
#define MPU_RBAR_A1	0xE000EDA4
#define MPU_RASR_A1	0xE000EDA8
#define MPU_RBAR_A2	0xE000EDAC
#define MPU_RASR_A2	0xE000EDB0
#define MPU_RBAR_A3	0xE000EDB4
#define MPU_RASR_A3	0xE000EDB8

/* MPU_CTRL */
#define MPU_CTRL_PRIVDEFENA	(1 << 2)
#define MPU_CTRL_HFNMIENA	(1 << 1)
#define MPU_CTRL_ENABLE	(1 << 0)

/* MPU D/I Size Register fields */
#define MPU_RASR_SZ		1
#define MPU_RASR_EN		0
#define MPU_RSR_SZ		MPU_RASR_SZ
#define MPU_RSR_EN		MPU_RASR_EN

/* The RASR SIZE value for an enabled region spanning the whole of memory */
#define MPU_RASR_ALL_MEM	((0x1f << MPU_RASR_SZ) | (1 << MPU_RASR_EN))
/* The RASR SIZE value for an enabled region spanning the whole of vectors */
#define MPU_RASR_MAX_VEC	((0x11 << MPU_RASR_SZ) | (1 << MPU_RASR_EN))

#define MPU_RASR_XN		(1 << 28)

/* C, B and TEX[2:0] bits only have semantic meanings when grouped */
#define MPU_RASR_SHARED		(1 << 18)
#define MPU_RASR_CACHEABLE	(0xB << 16)
#define MPU_RASR_SHARED_CACHEABLE (MPU_RASR_CACHEABLE | MPU_RASR_SHARED)
#define MPU_RASR_STRONGLY_ORDERED 0

#define MPU_RASR_NORMAL		MPU_RASR_CACHEABLE
#define MPU_RASR_NORMAL_NOCACHE		(1 << 19)


/* Access permission bits of RASR (only define those that we use)*/
#define MPU_AP_PL1RW_PL0RW	(0x3 << 24)
#define MPU_AP_PL1RW_PL0R0	(0x2 << 24)
#define MPU_AP_PL1RW_PL0NA	(0x1 << 24)

/* For minimal static MPU region configurations */
#define MPU_PROBE_REGION	0
#define MPU_BG_REGION		1
#define MPU_RAM_REGION		2
#define MPU_VECTORS_REGION	3

#define MPU_RBAR_VALID	(1 << 4)

/* Maximum number of regions Linux is interested in */
#define MPU_MAX_REGIONS		16

#ifndef __ASSEMBLY__

struct mpu_rgn {
	/* Assume same attributes for d/i-side  */
	u32 rbar;
	u32 rsr;
	u32 racr;
};

struct mpu_rgn_info {
	u32 mpuir;
	struct mpu_rgn rgns[MPU_MAX_REGIONS];
};
extern struct mpu_rgn_info mpu_rgn_info;

#endif /* __ASSEMBLY__ */

#endif /* CONFIG_ARM_V7M_MPU */

#endif
