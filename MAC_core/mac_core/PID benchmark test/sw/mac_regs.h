#ifndef KINETIC_MAC_REGS_H
#define KINETIC_MAC_REGS_H
/* Register constants only. CPU integration/firmware execution is deferred. */
#define MAC_A        0x00u
#define MAC_B        0x04u
#define MAC_LOAD     0x08u
#define MAC_MODE     0x0cu
#define MAC_COMMAND  0x10u
#define MAC_STATUS   0x14u
#define MAC_RESULT   0x18u
#define MAC_OP_MAC   0u
#define MAC_OP_CLEAR 1u
#define MAC_OP_LOAD  2u
#define MAC_SIGNED   1u
#define MAC_SATURATE 2u
#define MAC_ROUND    4u
#define MAC_SHIFT(n) (((n) & 255u) << 3)
#define MAC_BUSY     1u
#define MAC_DONE     2u
#endif
