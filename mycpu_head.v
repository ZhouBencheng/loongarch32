`ifndef MYCPU_HEAD
    `define MYCPU_HEAD

    `define BR_BUS_WD       34
    `define FS_TO_DS_BUS_WD 80
    `define DS_TO_ES_BUS_WD 262
    `define ES_TO_MS_BUS_WD 206
    `define MS_TO_WS_BUS_WD 168
    `define WS_TO_RF_BUS_WD 38

    `define CSR_CRMD        14'h0
    `define CSR_PRMD        14'h1
    `define CSR_ECFG        14'h4
    `define CSR_ESTAT       14'h5
    `define CSR_ERA         14'h6
    `define CSR_BADV        14'h7
    `define CSR_EENTRY      14'hc
    `define CSR_SAVE0       14'h30
    `define CSR_SAVE1       14'h31
    `define CSR_SAVE2       14'h32
    `define CSR_SAVE3       14'h33
    `define CSR_TID         14'h40
    `define CSR_TCFG        14'h41
    `define CSR_TVAL        14'h42
    `define CSR_TICLR       14'h44

`endif