`include "mycpu_head.v"

module mycpu_top(
    input         clk,
    input         resetn,
    // inst sram interface
    output        inst_sram_en,
    output [ 3:0] inst_sram_we,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,
    // data sram interface
    output        data_sram_en,
    output [ 3:0] data_sram_we,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    input  [31:0] data_sram_rdata,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_we,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata,
    output [31:0] debug_if_pc,
    output [31:0] debug_id_pc,
    output [31:0] debug_es_pc,
    output [31:0] debug_ms_pc,
    output [31:0] debug_es_alu_result,
    output [31:0] debug_mem_result,
    output [31:0] debug_es_alu_src1,
    output [31:0] debug_es_alu_src2,
    output [31:0] debug_es_data_sram_wdata,
    output        debug_es_m_axis_dout_tvalid,
    output        debug_if_br_taken,
    output        debug_if_br_target,
    output        debug_id_br_taken,
    output        debug_id_br_target,
    output        debug_id_br_offset,
    output        debug_need_si26,
    output [31:0] debug_ds_inst,
    output [31:0] debug_i26
);
reg         reset;
always @(posedge clk) reset <= ~resetn;

wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;
wire [4                  :0] es_to_ds_dest;
wire [4                  :0] ms_to_ds_dest;
wire [4                  :0] ws_to_ds_dest;
wire                         es_to_ds_load_op;
wire [31                 :0] es_to_ds_result;
wire [31                 :0] ms_to_ds_result;
wire [31                 :0] ws_to_ds_result;
wire [31                 :0] ws_ex_entry;
wire                         es_to_ds_csr_we;
wire [13                 :0] es_to_ds_csr_num;
wire                         es_to_ds_valid;
wire                         ms_to_ds_csr_we;
wire [13                 :0] ms_to_ds_csr_num;
wire                         ms_to_ds_valid;
wire [31                 :0] wb_pc;
wire [31                 :0] wb_badv;
wire [ 5                 :0] wb_ecode;
wire [ 8                 :0] wb_esubcode;
wire                         wb_ex;
wire                         wb_ertn_flush;
wire [31                 :0] ex_entry;
wire [31                 :0] ex_ra;
wire                         has_int;
wire [31                 :0] csr_rdata;
wire [13                 :0] csr_num;
wire [13                 :0] csr_wnum;
wire                         csr_we;
wire [31                 :0] csr_wdata;
wire [31                 :0] csr_wmask;
wire                         mem_ertn_flush;
wire                         mem_ex;

// IF stage
if_stage if_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus         (br_bus         ),
    // from wb
    .wb_ex          (wb_ex          ),
    .wb_ertn_flush  (wb_ertn_flush  ),
    .ex_entry       (ex_entry    ),
    .ex_ra          (ex_ra       ),
    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // inst sram interface
    .inst_sram_en   (inst_sram_en   ),
    .inst_sram_we   (inst_sram_we  ),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata),
    //debug
    .debug_if_pc    (debug_if_pc     ),
    .debug_if_br_taken(debug_if_br_taken),
    .debug_if_br_target(debug_if_br_target)
);
// ID stage
id_stage id_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //from wb
    .wb_ex          (wb_ex          ),
    .wb_ertn_flush  (wb_ertn_flush  ),

    .has_int        (has_int        ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to fs
    .br_bus         (br_bus         ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    // to ds
    .es_to_ds_dest  (es_to_ds_dest  ),
    .es_to_ds_load_op(es_to_ds_load_op),
    .es_to_ds_result(es_to_ds_result),
    .es_to_ds_csr_we (es_to_ds_csr_we),
    .es_to_ds_csr_num(es_to_ds_csr_num),
    .es_to_ds_valid (es_to_ds_valid ),
    
    .ms_to_ds_dest  (ms_to_ds_dest  ),
    .ms_to_ds_result(ms_to_ds_result),
    .ms_to_ds_csr_we(ms_to_ds_csr_we),
    .ms_to_ds_csr_num(ms_to_ds_csr_num),
    .ms_to_ds_valid (ms_to_ds_valid ),

    .ws_to_ds_dest  (ws_to_ds_dest  ),
    .ws_to_ds_result(ws_to_ds_result),
    //debug
    .debug_id_pc    (debug_id_pc     ),
    .debug_id_br_taken(debug_id_br_taken),
    .debug_id_br_target(debug_id_br_target),
    .debug_id_br_offset(debug_id_br_offset),
    .debug_need_si26(debug_need_si26),
    .debug_ds_inst(debug_ds_inst),
    .debug_i26(debug_i26)
);
// EXE stage
exe_stage exe_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //from wb
    .wb_ex          (wb_ex          ),
    .wb_ertn_flush  (wb_ertn_flush  ),
    // from mem
    .mem_ertn_flush (mem_ertn_flush ),
    .mem_ex         (mem_ex         ),
    // read csr
    .csr_rdata      (csr_rdata      ),
    .csr_num        (csr_num        ),
    //to ds
    .es_to_ds_dest  (es_to_ds_dest  ),
    .es_to_ds_load_op(es_to_ds_load_op),
    .es_to_ds_result (es_to_ds_result ),
    .es_to_ds_csr_we (es_to_ds_csr_we),
    .es_to_ds_csr_num(es_to_ds_csr_num),
    .es_to_ds_valid (es_to_ds_valid ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    // data sram interface
    .data_sram_en   (data_sram_en   ),
    .data_sram_we   (data_sram_we  ),
    .data_sram_addr (data_sram_addr ),
    .data_sram_wdata(data_sram_wdata),
    //debug
    .debug_es_pc    (debug_es_pc     ),
    .debug_es_alu_result(debug_es_alu_result),
    .debug_es_alu_src1  (debug_es_alu_src1  ),
    .debug_es_alu_src2  (debug_es_alu_src2  ),
    .debug_es_data_sram_wdata(debug_es_data_sram_wdata),
    .debug_es_m_axis_dout_tvalid(debug_es_m_axis_dout_tvalid)
);
// MEM stage
mem_stage mem_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //from wb
    .wb_ex          (wb_ex          ),
    .wb_ertn_flush  (wb_ertn_flush  ),
    // to exe
    .mem_ertn_flush (mem_ertn_flush ),
    .mem_ex         (mem_ex         ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to ds
    .ms_to_ds_dest  (ms_to_ds_dest  ),
    .ms_to_ds_result(ms_to_ds_result),
    .ms_to_ds_csr_we(ms_to_ds_csr_we),
    .ms_to_ds_csr_num(ms_to_ds_csr_num),
    .ms_to_ds_valid (ms_to_ds_valid ),
    //from data-sram
    .data_sram_rdata(data_sram_rdata),
    //debug
    .debug_ms_pc    (debug_ms_pc     ),
    .debug_mem_result(debug_mem_result)
);
// WB stage
wb_stage wb_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    // to if
    .ws_ex_entry    (ws_ex_entry    ),
    //to ds
    .ws_to_ds_dest  (ws_to_ds_dest  ),
    .ws_to_ds_result(ws_to_ds_result),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),

    .wb_ex          (wb_ex          ),
    .wb_ertn_flush  (wb_ertn_flush  ),
    .wb_pc          (wb_pc          ),
    .wb_badv        (wb_badv        ),
    .wb_ecode       (wb_ecode       ),
    .wb_esubcode    (wb_esubcode    ),

    .csr_wnum       (csr_wnum       ),
    .csr_we         (csr_we         ),
    .csr_wdata      (csr_wdata      ),
    .csr_wmask      (csr_wmask      ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_we   (debug_wb_rf_we   ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

// 核间中断和硬件中断置为无效
wire [7: 0] hw_int_in;
wire        ipi_int_in;
wire [31:0] coreid_in;

assign coreid_in  = 32'b0;
assign hw_int_in  = 8'b0;
assign ipi_int_in = 1'b0;


csrfile u_csrfile(
    .clk            (clk            ),
    .reset          (reset          ),

    .csr_rdata      (csr_rdata      ),
    .csr_num        (csr_num        ),

    .csr_we         (csr_we         ),
    .csr_wnum       (csr_wnum       ),
    .csr_wdata      (csr_wdata      ),
    .csr_wmask      (csr_wmask      ),

    .wb_ex          (wb_ex          ),
    .wb_ecode       (wb_ecode       ),
    .wb_esubcode    (wb_esubcode    ),
    .wb_pc          (wb_pc          ),
    .wb_badv        (wb_badv        ),

    .ertn_flush     (wb_ertn_flush  ),
    .hw_int_in      (hw_int_in      ),
    .ipi_int_in     (ipi_int_in     ),
    .coreid_in      (coreid_in      ),

    .has_int        (has_int        ),
    .ex_entry       (ex_entry       ),
    .ex_ra          (ex_ra          )
);

endmodule
