// SPDX-License-Identifier: GPL-2.0
/*
 * a75_lut_override.c — Override cpufreq HW LUT for MT6789 A75
 *
 * Writes custom frequency values into the perf-domain SRAM LUT
 * before mediatek-cpufreq-hw probes.  The kernel driver reads
 * this LUT at init and builds the cpufreq frequency table from it.
 *
 * INSTALL (builder patch, applied to kernel source at build time):
 *   scripts/apply-a75-lut-override.sh <workspace-dir>
 *
 * PHYSICAL LAYOUT (from DTB performance-controller@0011bc00):
 *   Domain 0 (LITTLE, 6× A55):  base = 0x11BC10, +0x120 bytes
 *   Domain 1 (BIG,    2× A76):  base = 0x11BD30, +0x120 bytes
 *
 * LUT register map (per domain):
 *   +0x00 … +0x7C: 32 LUT entries × 4 bytes, stride=4
 *     bottom 12 bits = frequency in MHz, top 20 = ignored
 *   +0x84: reg_freq_hpf  (current frequency index, read-only)
 *   +0x88: reg_freq_lpf  (target frequency index, write)
 *   +0x8C: reg_ctrl      (handshake with mcupm)
 *   +0x90: reg_power     (power/energy)
 *   +0x114: reg_info
 *
 * TIMING:
 *   arch_initcall → runs BEFORE mediatek-cpufreq-hw (device_initcall).
 *   LUT is written before the kernel driver reads it → no re-probe needed.
 *
 * USAGE:
 *   A75_LUT_OVERRIDE=1 ./scripts/build-kernel.sh android12-5.10-lts
 *
 *   Optionally override stock tables with comma-sep kHz via env vars:
 *     A75_LUT_BIG_TABLE=2600000,2400000,...,725000
 *     A75_LUT_LITTLE_TABLE=2200000,2000000,...,500000
 */

#include <linux/module.h>
#include <linux/io.h>

/* ── Physical address layout (from DTB) ────────────────────────── */
#define PERF_LITTLE_BASE    0x11BC10
#define PERF_BIG_BASE       0x11BD30
#define PERF_DOMAIN_STRIDE  0x120
#define PERF_TOTAL_SIZE     (PERF_DOMAIN_STRIDE * 2)
#define LUT_ENTRIES_MAX     32
#define LUT_ENTRY_STRIDE    4

/* ── Default stock tables (MT6789 A75, kHz, descending) ────────── */
#define BIG_STOCK    { 2200000, 2100000, 2000000, 1900000, \
                       1800000, 1700000, 1600000, 1500000, \
                       1400000, 1300000, 1200000, 1100000, \
                       1000000,  900000,  800000,  725000 }
#define LITTLE_STOCK { 2000000, 1900000, 1800000, 1700000, \
                       1600000, 1500000, 1450000, 1400000, \
                       1350000, 1300000, 1250000, 1200000, \
                       1150000, 1100000, 1050000, 1000000, \
                        950000,  900000,  850000,  800000, \
                        750000,  700000,  650000,  500000 }

/* ── EDIT THESE TABLES for your overclock ──
 * Keep values descending.  Max 32 entries per cluster.
 * Override at build time via env:
 *   A75_LUT_BIG_TABLE=val1,val2,...,valN
 *   A75_LUT_LITTLE_TABLE=val1,val2,...,valN
 */
static int big_freqs_khz[] = BIG_STOCK;
static int little_freqs_khz[] = LITTLE_STOCK;

#define BIG_NFREQ    ARRAY_SIZE(big_freqs_khz)
#define LITTLE_NFREQ ARRAY_SIZE(little_freqs_khz)

/* ── Write LUT entries to one perf-domain ──────────────────────── */
static void write_lut(void __iomem *base, const int *freqs, int count)
{
    int i;
    u32 last = 0;

    for (i = 0; i < min(count, LUT_ENTRIES_MAX); i++) {
        last = (freqs[i] / 1000) & 0xFFF;
        writel(last, base + i * LUT_ENTRY_STRIDE);
    }
    if (i < LUT_ENTRIES_MAX)
        writel(last, base + i * LUT_ENTRY_STRIDE);

    wmb();
}

/* ── ioremap + write both domains ──────────────────────────────── */
static int __init a75_lut_override_init(void)
{
    void __iomem *map_base;

    pr_info("a75_lut: BIG=%d steps, LITTLE=%d steps\n",
            BIG_NFREQ, LITTLE_NFREQ);

    map_base = ioremap(PERF_LITTLE_BASE, PERF_TOTAL_SIZE);
    if (!map_base) {
        pr_err("a75_lut: ioremap failed\n");
        return -ENOMEM;
    }

    write_lut(map_base + (PERF_BIG_BASE - PERF_LITTLE_BASE),
              big_freqs_khz, BIG_NFREQ);
    write_lut(map_base, little_freqs_khz, LITTLE_NFREQ);

    iounmap(map_base);
    return 0;
}

arch_initcall(a75_lut_override_init);

MODULE_LICENSE("GPL v2");
MODULE_AUTHOR("fenrir");
MODULE_DESCRIPTION("A75 MT6789 cpufreq HW LUT override");
