`ifndef CSR_HEAD
    `define CSR_HEAD

    `define CSR_CRMD_PLV    1:0
    `define CSR_CRMD_IE     2
    `define CSR_CRMD_DA     3
    `define CSR_CRMD_PG     4
    `define CSR_CRMD_DATF   6:5
    `define CSR_CRMD_DATM   8:7

    `define CSR_PRMD_PPLV   1:0
    `define CSR_PRMD_PIE    2

    `define CSR_ECFG_LIE    12:0

    `define CSR_ESTAT_IS    12:0
    `define CSR_ESTAT_IS10  1:0
    `define CSR_ESTAT_ECODE 21:16
    `define CSR_ESTAT_ESUBCODE 30:22

    `define CSR_ERA_PC      31:0

    `define CSR_BADV_VA      31:0

    `define CSR_EENTRY_VA    31:6

    `define CSR_SAVE_DATA   31:0

    `define CSR_TID_TID     31:0

    `define CSR_TCFG_EN       0
    `define CSR_TCFG_PERIODIC 1
    `define CSR_TCFG_INITVAL  31:2

    `define CSR_TVAL_TIMEVAL  31:0

    `define CSR_TICLR_CLR     0

    `define ECODE_INT   6'h0
    `define ECODE_PIL   6'h1
    `define ECODE_PIS   6'h2
    `define ECODE_PIF   6'h3
    `define ECODE_PME   6'h4
    `define ECODE_PPI   6'h7
    `define ECODE_ADE   6'h8
    `define ECODE_ALE   6'h9
    `define ECODE_SYS   6'hb
    `define ECODE_BRK   6'hc
    `define ECODE_INE   6'hd
    `define ECODE_IPE   6'he
    `define ECODE_FPD   6'hf
    `define ECODE_FPE   6'h12
    `define ECODE_TLBR  6'h3f

    `define ESUBCODE_ADEF 9'b0
    `define ESUBCODE_ADEM 9'b1

`endif