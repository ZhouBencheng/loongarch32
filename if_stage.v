`include "mycpu_head.v"
`include "csr_head.v"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   , // 32位指令和32位地址结合
    // from wb
    input                          wb_ex          ,
    input                          wb_ertn_flush  ,
    input  [31:0]                  ex_entry       ,
    input  [31:0]                  ex_ra          ,
    // inst sram interface
    output                         inst_sram_en   ,
    output [ 3:0]                  inst_sram_we   ,
    output [31:0]                  inst_sram_addr ,
    output [31:0]                  inst_sram_wdata,
    input  [31:0]                  inst_sram_rdata,

    output [31:0]                  debug_if_pc,
    output wire                    debug_if_br_taken,
    output wire                    debug_if_br_target
);

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;
reg         if_ex;
reg  [14: 0]if_ex_code;
wire        preif_ex;
wire [14: 0]preif_ex_code;

wire [31:0] seq_pc;
wire [31:0] nextpc;

wire         br_taken;
wire [ 31:0] br_target;
wire         br_taken_cancel;
assign {br_taken_cancel, br_taken, br_target} = br_bus;

wire [31:0] fs_inst;
reg  [31:0] fs_pc;
assign fs_to_ds_bus = {fs_inst, fs_pc, if_ex, if_ex_code};

// pre-IF stage
assign to_fs_valid  = ~reset;
// 根据异常信号选择下一个PC
assign seq_pc       = fs_pc + 3'h4;

assign nextpc = wb_ex        ? ex_entry :
                wb_ertn_flush? ex_ra    :
                br_taken     ? br_target: seq_pc;

// IF stage
assign fs_ready_go    = 1'b1;   // 准备发送
assign fs_allowin     = !fs_valid || (fs_ready_go && ds_allowin);
assign fs_to_ds_valid =  fs_valid && fs_ready_go;   
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;    // 数据有效
    end
    else if (br_taken_cancel) begin
        fs_valid <= 1'b0;
    end
end

always @(posedge clk) begin
    if (reset) begin
        fs_pc <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset 
    end
    else if (to_fs_valid && (fs_allowin)) begin
        fs_pc <= nextpc;
    end
end

assign preif_ex      = (nextpc[1:0] != 2'b00);
assign preif_ex_code = preif_ex ? {`ESUBCODE_ADEF, `ECODE_ADE} : 15'h0;

always @(posedge clk) begin
    if (reset) begin
        if_ex <= 1'b0;
    end
    else if (to_fs_valid && fs_allowin) begin
        if_ex      <= preif_ex;
        if_ex_code <= preif_ex_code;
    end
end

// IF模块的4个输出
assign inst_sram_en    = to_fs_valid && (fs_allowin);
assign inst_sram_we    = 4'h0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;

assign fs_inst         = inst_sram_rdata;

assign debug_if_pc     = fs_pc;
assign debug_if_br_taken = br_taken;
assign debug_if_br_target = br_target;
endmodule
