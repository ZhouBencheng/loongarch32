`include "mycpu_head.v"

module wb_stage(
    input wire                          clk           ,
    input wire                          reset         ,
    //allowin
    output wire                         ws_allowin    ,
    //from ms
    input wire                          ms_to_ws_valid,
    input wire [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    // to if
    output wire [31                 :0]  ws_ex_entry,
    //to ds
    output wire [4                  :0]  ws_to_ds_dest ,
    output wire [31                 :0]  ws_to_ds_result,
    //to rf: for write back
    output wire [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,

    output wire                         wb_ex,
    output wire                         wb_ertn_flush,
    output wire [31                 :0] wb_pc,
    output wire [31                 :0] wb_badv,
    output wire [ 5                 :0] wb_ecode,
    output wire [ 8                 :0] wb_esubcode,

    output wire [13                 :0] csr_wnum,
    output wire                         csr_we,
    output wire [31                 :0] csr_wdata,
    output wire [31                 :0] csr_wmask,

    //trace debug interface
    output wire [31:0] debug_wb_pc     ,
    output wire [ 3:0] debug_wb_rf_we  ,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

reg         ws_valid;
wire        ws_ready_go;
wire        ws_inst_no_dest;
wire        ws_src_from_csr;
wire [13:0] ws_csr_num;
wire        ws_csr_we;
wire [31:0] ws_csr_wdata;
wire [31:0] ws_csr_wmask;
wire        ws_ex_in;
wire [14:0] ws_ex_code_in;
wire        ws_inst_ertn;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire        ws_gr_we;
wire [ 4:0] ws_dest;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;
assign {ws_gr_we       ,  //69:69
        ws_dest        ,  //68:64
        ws_final_result,  //63:32
        ws_pc            ,  //31:0
        ws_inst_no_dest  ,  //1
        ws_src_from_csr  ,  //1
        ws_csr_num       ,  //14
        ws_csr_we        ,  //1
        ws_csr_wdata     ,  //32
        ws_csr_wmask     ,  //32
        ws_ex_in         ,  //1
        ws_ex_code_in    ,  //15
        ws_inst_ertn     //1
       } = ms_to_ws_bus_r;

wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = {rf_we   ,  //37:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };

assign wb_ex          = ws_ex_in & ws_valid;
assign wb_ertn_flush  = ws_inst_ertn & ws_valid;
assign wb_pc          = ws_pc;
assign wb_ecode       = ws_ex_code_in[ 5:0];
assign wb_esubcode    = ws_ex_code_in[14:6];
assign wb_badv        = ws_final_result;

assign csr_wnum  = ws_csr_num;
assign csr_we    = ws_csr_we && ws_valid && !wb_ertn_flush && !wb_ex;
assign csr_wdata = ws_csr_wdata;
assign csr_wmask = ws_csr_wmask;

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
assign ws_to_ds_dest = ws_dest & {5{ws_valid & ~ws_inst_no_dest}};
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign rf_we    = ws_gr_we && ws_valid;
assign rf_waddr = ws_dest;
assign rf_wdata = ws_final_result;
assign ws_to_ds_result = ws_final_result;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_we    = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_final_result;

endmodule
