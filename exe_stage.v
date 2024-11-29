`include "mycpu_head.v"
`include "csr_head.v"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //from wb
    input                          wb_ex         ,
    input                          wb_ertn_flush ,
    //from mem
    input                          mem_ertn_flush,
    input                          mem_ex        ,
    // read csr
    input  [31                 :0] csr_rdata,
    output [13                 :0] csr_num,
    // to ds
    output [4                  :0] es_to_ds_dest ,
    output                         es_to_ds_load_op,
    output [31                 :0] es_to_ds_result,
    output                         es_to_ds_csr_we,
    output [13                 :0] es_to_ds_csr_num,
    output                         es_to_ds_valid,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,

    // data sram interface(write)
    output        data_sram_en   ,
    output [ 3:0] data_sram_we   ,
    output [31:0] data_sram_addr ,
    output reg [31:0] data_sram_wdata,
    //debug
    output [31:0] debug_es_pc,
    output [31:0] debug_es_alu_result,
    output [31:0] debug_es_alu_src1,
    output [31:0] debug_es_alu_src2,
    output [31:0] debug_es_data_sram_wdata,
    output        debug_es_m_axis_dout_tvalid
);

reg         es_valid      ;
wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;

wire [18:0] alu_op      ;
wire        es_load_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        gr_we;
wire        es_mem_we;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [31:0] es_pc;
wire        es_inst_no_dest;
wire [2:0]  ld_type;
wire [1:0]  st_type;
reg  [3:0]  st_data_mask;
wire        m_axis_dout_tvalid;
wire        div_or_mod_op;
wire        src_from_csr;
wire        csr_we;
wire [13:0] csr_num;
wire [31:0] csr_wdata;
wire [31:0] csr_wmask;
wire        exe_ex_in;
wire [14:0] exe_ex_code_in;
wire        inst_ertn;
wire        exe_ex_out;
wire [14:0] exe_ex_code_out;
wire        inst_ale;
wire        alu_division_tvalid;

assign {alu_op,
        es_load_op,
        ld_type,
        src1_is_pc,
        src2_is_imm,
        gr_we,
        st_type,
        es_mem_we,
        dest,
        imm,
        rj_value,
        rkd_value,
        es_pc,
        res_from_mem,
        es_inst_no_dest,
        div_or_mod_op,
        src_from_csr,
        csr_we,
        csr_num,
        csr_wdata,
        csr_wmask,
        exe_ex_in,
        exe_ex_code_in,
        inst_ertn
       } = ds_to_es_bus_r;

wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;


assign es_to_ds_load_op = es_load_op;
assign es_to_ds_csr_we = csr_we;
assign es_to_ds_csr_num = csr_num;
assign es_to_ds_valid = es_valid;

assign debug_es_pc = es_pc;

assign es_to_ms_bus = {res_from_mem,  //70:70 1
                       ld_type,       //69:67 3
                       gr_we       ,  //66:66 1
                       st_type,       //65:64 2
                       dest        ,  //63:59 5
                       alu_result  ,  //58:27 32
                       es_pc       ,  //26:0  32
                       es_inst_no_dest, //1
                       src_from_csr,   //1
                       csr_num,        //14
                       csr_we,         //1
                       csr_wdata,      //32
                       csr_wmask,      //32
                       exe_ex_out,     //1
                       exe_ex_code_out,//15
                       inst_ertn,      //1
                       csr_rdata       //32
                      };

assign es_ready_go    = div_or_mod_op ? m_axis_dout_tvalid : 1'b1;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
assign es_to_ds_dest  =  dest & {5{es_valid & ~es_inst_no_dest}};
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end
    else if (wb_ertn_flush || wb_ex) begin
        es_valid <= 1'b0;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

assign alu_src1 = src1_is_pc  ? es_pc  : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;
assign alu_division_tvalid = es_valid && !wb_ertn_flush && !wb_ex && !exe_ex_out && !mem_ertn_flush && !mem_ex;

alu u_alu(
    .clk        (clk       ),
    .reset      (reset     ),
    .alu_op     (alu_op    ),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .alu_division_tvalid(alu_division_tvalid),
    .alu_result (alu_result),
    .m_axis_dout_tvalid(m_axis_dout_tvalid)
    );
    
assign es_to_ds_result = alu_result;

assign data_sram_en    = (res_from_mem || es_mem_we) && es_valid && 
                         !(wb_ertn_flush || wb_ex || exe_ex_out || mem_ertn_flush || mem_ex);
assign data_sram_we    = {4{es_mem_we && es_valid}} & st_data_mask;
assign data_sram_addr  = alu_result;

assign debug_es_alu_result = alu_result;
assign debug_es_alu_src1   = alu_src1;
assign debug_es_alu_src2   = alu_src2;

always @(*) begin
    case (st_type) 
        2'b00: begin // inst_st_w
            st_data_mask    <= 4'hf;
            data_sram_wdata <= rkd_value;
        end
        2'b01: begin // inst_st_b
            case (alu_result[1:0])
                2'b00: begin st_data_mask <= 4'h1; data_sram_wdata <= {24'b0, rkd_value[7:0]}; end
                2'b01: begin st_data_mask <= 4'h2; data_sram_wdata <= {16'b0, rkd_value[7:0], 8'b0}; end
                2'b10: begin st_data_mask <= 4'h4; data_sram_wdata <= {8'b0, rkd_value[7:0], 16'b0}; end
                2'b11: begin st_data_mask <= 4'h8; data_sram_wdata <= {rkd_value[7:0], 24'b0}; end
            endcase
        end
        2'b10:  begin // inst_st_h
            case (alu_result[1:0])
                2'b00: begin st_data_mask <= 4'h3; data_sram_wdata <= {16'b0, rkd_value[15:0]}; end
                2'b10: begin st_data_mask <= 4'hc; data_sram_wdata <= {rkd_value[15:0], 16'b0}; end
            endcase
        end
        default: begin
            st_data_mask <= 4'b0;
            data_sram_wdata <= 32'b0;
            // $display("error: st_type = %d", st_type);
        end
    endcase
end

assign inst_ale = (es_mem_we    && ((st_type == 2'b00  && alu_result[1:0] != 2'b00)
                               ||  (st_type == 2'b10  && alu_result[0]   != 1'b0))) |
                  (res_from_mem && ((ld_type == 3'b000 && alu_result[1:0] != 2'b00) 
                               ||  (ld_type == 3'b010 && alu_result[0]   != 1'b0)
                               ||  (ld_type == 3'b100 && alu_result[0]   != 1'b0)));

assign exe_ex_out = exe_ex_in || inst_ale;
assign exe_ex_code_out = exe_ex_in ? exe_ex_code_in :
                         inst_ale  ? {9'h0, `ECODE_ALE} : 15'h0000;

assign debug_es_data_sram_wdata = data_sram_wdata;
assign debug_es_m_axis_dout_tvalid = m_axis_dout_tvalid;

endmodule
