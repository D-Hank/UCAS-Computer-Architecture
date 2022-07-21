`ifndef MYCPU_H
    `define MYCPU_H

    `define FS_TO_DS_BUS_WD   116
    `define DS_TO_ES_BUS_WD   271
    `define BR_BUS_WD         34
    `define ES_TO_MS_BUS_WD   213
    `define MS_TO_WS_BUS_WD   206
    `define MS_TO_ES_BUS_WD   2
    `define WS_TO_RF_BUS_WD   38
    `define WS_TO_FS_BUS_WD   99
    `define WS_TO_DS_BUS_WD   2
    `define WS_TO_ES_BUS_WD   2
    `define WS_TO_MS_BUS_WD   1

    `define FORWARD_ES_TO_DS  39
    `define FORWARD_MS_TO_DS  39
    `define FORWARD_WS_TO_DS  38

    `define CSR_CRMD          14'h0000
    `define CSR_PRMD          14'h0001
    `define CSR_EUEN          14'h0002
    `define CSR_ECFG          14'h0004
    `define CSR_ESTAT         14'h0005
    `define CSR_ERA           14'h0006
    `define CSR_BADV          14'h0007
    `define CSR_EENTRY        14'h000c
    `define CSR_TLBIDX        14'h0010
    `define CSR_TLBEHI        14'h0011
    `define CSR_TLBELO0       14'h0012
    `define CSR_TLBELO1       14'h0013
    `define CSR_ASID          14'h0018
    `define CSR_PGDL          14'h0019
    `define CSR_PGDH          14'h001a
    `define CSR_PGD           14'h001b
    `define CSR_CPUID         14'h0020
    `define CSR_SAVE0         14'h0030
    `define CSR_SAVE1         14'h0031
    `define CSR_SAVE2         14'h0032
    `define CSR_SAVE3         14'h0033
    `define CSR_TID           14'h0040
    `define CSR_TCFG          14'h0041
    `define CSR_TVAL          14'h0042
    `define CSR_TICLR         14'h0044
    `define CSR_LLBCTL        14'h0060
    `define CSR_TLBRENTRY     14'h0088
    `define CSR_CTAG          14'h0098
    `define CSR_DMW0          14'h0180
    `define CSR_DMW1          14'h0181

    `define CSR_CRMD_PLV      1:0
    `define CSR_CRMD_IE       2
    `define CSR_CRMD_DA       3
    `define CSR_CRMD_PG       4
    `define CSR_CRMD_DATF     6:5
    `define CSR_CRMD_DATM     8:7

    `define CSR_PRMD_PPLV     1:0
    `define CSR_PRMD_PIE      2
    `define CSR_ECFG_LIE      12:0
    `define CSR_ESTAT_IS      12:0
    `define CSR_ESTAT_IS10    1:0
    `define CSR_ERA_PC        31:0
    `define CSR_BADV_VADDR    31:0
    `define CSR_EENTRY_VA     31:6

    `define CSR_SAVE_DATA     31:0

    `define CSR_TLBIDX_IDX    3:0
    `define CSR_TLBIDX_PS     29:24
    `define CSR_TLBIDX_NE     31:31

    `define CSR_TLBEHI_VPPN   31:13

    `define CSR_TLBELO0_V     0:0
    `define CSR_TLBELO0_D     1:1
    `define CSR_TLBELO0_PLV   3:2
    `define CSR_TLBELO0_MAT   5:4
    `define CSR_TLBELO0_G     6:6
    `define CSR_TLBELO0_PPN   31:8
    //`define CSR_TLBELO0_PPN   31:12
    `define CSR_TLBELO1_V     0:0
    `define CSR_TLBELO1_D     1:1
    `define CSR_TLBELO1_PLV   3:2
    `define CSR_TLBELO1_MAT   5:4
    `define CSR_TLBELO1_G     6:6
    `define CSR_TLBELO1_PPN   31:8
    //`define CSR_TLBELO1_PPN   31:12
    //36 bit PA?

    `define CSR_ASID_ASID     9:0
    `define CSR_ASID_BITS     23:16

    `define CSR_TLBRENTRY_PA  31:6

    `define CSR_TID_TID       31:0
    `define CSR_TCFG_EN       0:0
    `define CSR_TCFG_PRDC     1:1
    `define CSR_TCFG_INIT     31:2

    `define CSR_TICLR_CLR     0:0

    `define ECODE_WD          6

    `define ECODE_UNKNOWN     6'h00
    `define ECODE_INT         6'h00
    `define ECODE_PIL         6'h01
    `define ECODE_PIS         6'h02
    `define ECODE_PIF         6'h03
    `define ECODE_PME         6'h04
    `define ECODE_PPI         6'h07
    `define ECODE_ADE         6'h08
    `define ECODE_ALE         6'h09
    `define ECODE_SYS         6'h0b
    `define ECODE_BRK         6'h0c
    `define ECODE_INE         6'h0d
    `define ECODE_IPE         6'h0e
    `define ECODE_FPD         6'h0f
    `define ECODE_FPE         6'h12
    `define ECODE_TLBR        6'h3f

    `define ESUBCODE_WD       13

    `define ESUBCODE_UNKNOWN  9'h000
    `define ESUBCODE_ADEF     9'h000
    `define ESUBCODE_ADEM     9'h001
    `define ESUBCODE_FPE      9'h000

    `define TLB_VPPN_WD       19
    `define TLB_ASID_WD       10
    `define TLB_PPN_WD        24
    `define TLB_PS_WD         6
    `define TLB_PLV_WD        2
    `define TLB_MAT_WD        2
    `define TLB_INV_OP_WD     5
    `define TLB_LOG_NUM       4

    `define CSR_TO_EXE        33
    `define TLB_TO_CSR        105
    `define CSR_TO_TLB        108

`endif