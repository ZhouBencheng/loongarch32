`include "csr_head.v"
`include "mycpu_head.v"

module csrfile(
    input  wire        clk,
    input  wire        reset,

    input  wire [13:0] csr_num,
    output wire [31:0] csr_rdata,

    input  wire        csr_we,
    input  wire [13:0] csr_wnum,
    input  wire [31:0] csr_wmask,
    input  wire [31:0] csr_wdata,

    input  wire        wb_ex,
    input  wire [5: 0] wb_ecode,
    input  wire [8: 0] wb_esubcode,
    input  wire [31:0] wb_pc,      // 触发例外的PC
    input  wire [31:0] wb_badv,    // 触发例外的BADV
    input  wire        ertn_flush, // from wb
    input  wire [7: 0] hw_int_in,  // 外部硬件中断
    input  wire        ipi_int_in, // 核间中断
    input  wire [31:0] coreid_in,  // 核ID
    
    output wire        has_int,    // 送往ID阶段的中断有效信号
    output wire [31:0] ex_entry,   // 送往IF阶段的异常处理入口地址
    output wire [31:0] ex_ra       // 异常返回地址
);

// CRMD寄存器
reg  [1: 0] csr_crmd_plv;
reg         csr_crmd_ie;
wire [31:0] csr_crmd;

// MMU不实现，仅使用直接地址翻译模式
assign csr_crmd = {27'b0, /*PG DA*/2'b01, csr_crmd_ie, csr_crmd_plv};

always @(posedge clk) begin
    if (reset) begin
        csr_crmd_plv <= 2'b0;
        csr_crmd_ie  <= 1'b0;
    end else if (wb_ex) begin
        csr_crmd_plv <= 2'b0;
        csr_crmd_ie  <= 1'b0;
    end else if (ertn_flush) begin
        csr_crmd_plv <= csr_prmd_pplv;
        csr_crmd_ie  <= csr_prmd_pie;
    end else if (csr_we && csr_wnum == `CSR_CRMD) begin
        csr_crmd_plv <= csr_wdata[`CSR_CRMD_PLV] & csr_wmask[`CSR_CRMD_PLV] |
                        csr_crmd_plv & ~csr_wmask[`CSR_CRMD_PLV];
        csr_crmd_ie  <= csr_wdata[`CSR_CRMD_IE]  & csr_wmask[`CSR_CRMD_IE] |
                        csr_crmd_ie  & ~csr_wmask[`CSR_CRMD_IE];
    end
end

// PRMD寄存器
reg  [1: 0] csr_prmd_pplv;
reg         csr_prmd_pie;
wire [31:0] csr_prmd;

assign csr_prmd = {28'b0, csr_prmd_pie, csr_prmd_pplv};

always @(posedge clk) begin
    if (wb_ex) begin
        csr_prmd_pplv <= csr_crmd_plv;
        csr_prmd_pie  <= csr_crmd_ie;
    end else if (csr_we && csr_wnum == `CSR_PRMD) begin
        csr_prmd_pplv <= csr_wdata[`CSR_PRMD_PPLV] & csr_wmask[`CSR_PRMD_PPLV] |
                        csr_prmd_pplv & ~csr_wmask[`CSR_PRMD_PPLV];
        csr_prmd_pie  <= csr_wdata[`CSR_PRMD_PIE]  & csr_wmask[`CSR_PRMD_PIE] |
                        csr_prmd_pie  & ~csr_wmask[`CSR_PRMD_PIE];
    end
end

// ECFG寄存器
reg  [12:0] csr_ecfg_lie;
wire [31:0] csr_ecfg;

assign csr_ecfg = {19'b0, csr_ecfg_lie};

always @(posedge clk) begin
    if (reset)
        csr_ecfg_lie <= 13'b0;
    else if (csr_we && csr_wnum == `CSR_ECFG) begin
        csr_ecfg_lie <= csr_wdata[`CSR_ECFG_LIE] & 13'h1bff & csr_wmask[`CSR_ECFG_LIE] |
                        csr_ecfg_lie & 13'h1bff & ~csr_wmask[`CSR_ECFG_LIE];
    end
end

// ESTAT寄存器
reg  [12:0] csr_estat_is;
reg  [5: 0] csr_estat_ecode;
reg  [8: 0] csr_estat_esubcode;
wire [31:0] csr_estat;

assign csr_estat = {1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b000, csr_estat_is};

always @(posedge clk) begin
    if (reset)
        csr_estat_is[1: 0] <= 2'b0;
    else if (csr_we && csr_wnum == `CSR_ESTAT) // 设置软中断
        csr_estat_is[1: 0] <= csr_wdata[`CSR_ESTAT_IS10] & csr_wmask[`CSR_ESTAT_IS10] |
                           csr_estat_is[1: 0] & ~csr_wmask[`CSR_ESTAT_IS10];
    
    csr_estat_is[9: 2] <= hw_int_in[7: 0];     // 设置硬件中断

    csr_estat_is[10]   <= 1'b0;

    if (timer_cnt == 32'd0)
        csr_estat_is[11] <= 1'b1;
    else if (csr_we && csr_wnum == `CSR_TICLR && csr_wmask[`CSR_TICLR_CLR] && csr_wdata[`CSR_TICLR_CLR])
        csr_estat_is[11] <= 1'b0;
    
    csr_estat_is[12] <= ipi_int_in;
end

always @(posedge clk) begin
    if (wb_ex) begin
        csr_estat_ecode    <= wb_ecode;
        csr_estat_esubcode <= wb_esubcode;
    end
end

assign has_int = ((csr_estat_is[12:0] & csr_ecfg_lie[12:0]) != 13'b0) && csr_crmd_ie;

// ERA寄存器
reg  [31:0] csr_era;

always @(posedge clk) begin
    if (reset)
        csr_era <= 32'b0;
    else if (wb_ex)
        csr_era <= wb_pc;
    else if (csr_we && csr_wnum == `CSR_ERA)
        csr_era <= csr_wdata[`CSR_ERA_PC] & csr_wmask[`CSR_ERA_PC] |
                   csr_era & ~csr_wmask[`CSR_ERA_PC];
end

// BADV寄存器
reg  [31:0] csr_badv;
wire        wb_ex_addr_err;
assign wb_ex_addr_err = wb_ex && (wb_ecode == `ECODE_ADE || wb_ecode == `ECODE_ALE);

always @(posedge clk) begin
    if (reset)
        csr_badv <= 32'b0;
    else if (wb_ex_addr_err)
        csr_badv <= wb_ecode == `ECODE_ADE && wb_esubcode == `ESUBCODE_ADEF ? wb_pc : wb_badv;
end

// EENTRY寄存器
reg  [25:0] csr_eentry_va;
wire [31:0] csr_eentry;

assign csr_eentry = {csr_eentry_va, 6'b0};

always @(posedge clk) begin
    if (reset)
        csr_eentry_va <= 26'b0;
    else if (csr_we && csr_wnum == `CSR_EENTRY)
        csr_eentry_va <= csr_wdata[`CSR_EENTRY_VA] & csr_wmask[`CSR_EENTRY_VA] |
                        csr_eentry_va & ~csr_wmask[`CSR_EENTRY_VA];
end

// SAVE0~3寄存器
reg  [31:0] csr_save0;
reg  [31:0] csr_save1;
reg  [31:0] csr_save2;
reg  [31:0] csr_save3;

always @(posedge clk) begin
    if (reset) begin
        csr_save0 <= 32'b0;
        csr_save1 <= 32'b0;
        csr_save2 <= 32'b0;
        csr_save3 <= 32'b0;
    end else if (csr_we && csr_wnum == `CSR_SAVE0) begin
        csr_save0 <= csr_wdata[`CSR_SAVE_DATA] & csr_wmask[`CSR_SAVE_DATA] |
                     csr_save0 & ~csr_wmask[`CSR_SAVE_DATA];
    end else if (csr_we && csr_wnum == `CSR_SAVE1) begin
        csr_save1 <= csr_wdata[`CSR_SAVE_DATA] & csr_wmask[`CSR_SAVE_DATA] |
                     csr_save1 & ~csr_wmask[`CSR_SAVE_DATA];
    end else if (csr_we && csr_wnum == `CSR_SAVE2) begin
        csr_save2 <= csr_wdata[`CSR_SAVE_DATA] & csr_wmask[`CSR_SAVE_DATA] |
                     csr_save2 & ~csr_wmask[`CSR_SAVE_DATA];
    end else if (csr_we && csr_wnum == `CSR_SAVE3) begin
        csr_save3 <= csr_wdata[`CSR_SAVE_DATA] & csr_wmask[`CSR_SAVE_DATA] |
                     csr_save3 & ~csr_wmask[`CSR_SAVE_DATA];
    end
end

// TID寄存器
wire  [31:0] csr_tid;
reg   [31:0] csr_tid_tid;

always @(posedge clk) begin
    if (reset)
        csr_tid_tid <= coreid_in;
    else if (csr_we && csr_wnum == `CSR_TID)
        csr_tid_tid <= csr_wdata[`CSR_TID_TID] & csr_wmask[`CSR_TID_TID] |
                       csr_tid_tid & ~csr_wmask[`CSR_TID_TID];
end

// TCFG寄存器
reg         csr_tcfg_en;
reg         csr_tcfg_periodic;
reg  [29:0] csr_tcfg_initval;
reg  [31:0] csr_tcfg;

always @(posedge clk) begin
    if (reset) begin
        csr_tcfg_en <= 1'b0;
    end else if (csr_we && csr_wnum == `CSR_TCFG) begin
        csr_tcfg_en       <= csr_wdata[`CSR_TCFG_EN] & csr_wmask[`CSR_TCFG_EN] |
                             csr_tcfg_en & ~csr_wmask[`CSR_TCFG_EN];
        csr_tcfg_periodic <= csr_wdata[`CSR_TCFG_PERIODIC] & csr_wmask[`CSR_TCFG_PERIODIC] |
                             csr_tcfg_periodic & ~csr_wmask[`CSR_TCFG_PERIODIC];
        csr_tcfg_initval  <= csr_wdata[`CSR_TCFG_INITVAL] & csr_wmask[`CSR_TCFG_INITVAL] |
                             csr_tcfg_initval & ~csr_wmask[`CSR_TCFG_INITVAL];
    end
end

// TVAL寄存器
reg  [31:0] timer_cnt;
wire [31:0] csr_tval;
wire [31:0] tcfg_next_value;
assign tcfg_next_value = csr_wmask[31: 0] & csr_wdata[31: 0] |
                         ~csr_wmask[31: 0] & {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};

always @(posedge clk) begin
    if (reset)
        timer_cnt <= 32'hffffffff;
    else if (csr_we && csr_wnum == `CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
        timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITVAL], 2'b00};
    else if (csr_tcfg_en && timer_cnt != 32'hffffffff) begin
        if (timer_cnt == 32'd0 && csr_tcfg_periodic)
            timer_cnt <= {csr_tcfg_initval, 2'b00};
        else
            timer_cnt <= timer_cnt - 32'd1;
    end
end

assign csr_tval = timer_cnt;

// TICLR寄存器
wire [31:0] csr_ticlr;
assign csr_ticlr = 32'b0;

assign csr_rdata = (csr_num == `CSR_CRMD)   ? csr_crmd  :
                   (csr_num == `CSR_PRMD)   ? csr_prmd  :
                   (csr_num == `CSR_ECFG)   ? csr_ecfg  :
                   (csr_num == `CSR_ESTAT)  ? csr_estat :
                   (csr_num == `CSR_ERA)    ? csr_era   :
                   (csr_num == `CSR_EENTRY) ? csr_eentry:
                   (csr_num == `CSR_BADV)   ? csr_badv  :
                   (csr_num == `CSR_TVAL)   ? csr_tval  :
                   (csr_num == `CSR_TICLR)  ? csr_ticlr :
                   (csr_num == `CSR_TID)    ? csr_tid   :
                   (csr_num == `CSR_TCFG)   ? csr_tcfg  :
                   (csr_num == `CSR_SAVE0)  ? csr_save0 :
                   (csr_num == `CSR_SAVE1)  ? csr_save1 :
                   (csr_num == `CSR_SAVE2)  ? csr_save2 :
                   (csr_num == `CSR_SAVE3)  ? csr_save3 :
                   32'b0;

assign ex_entry = csr_eentry;
assign ex_ra    = csr_era;

endmodule