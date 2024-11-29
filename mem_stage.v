`include "mycpu_head.v"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //from wb
    input                          wb_ex         ,
    input                          wb_ertn_flush ,
    // exe
    output                         mem_ertn_flush,
    output                         mem_ex,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //to ds
    output [4                  :0] ms_to_ds_dest ,
    output [31                 :0] ms_to_ds_result,
    output                         ms_to_ds_csr_we,
    output [13                 :0] ms_to_ds_csr_num,
    output                         ms_to_ds_valid,
    //from data-sram
    input  [31                 :0] data_sram_rdata,
    //debug
    output [31                 :0] debug_ms_pc,
    output [31                 :0] debug_mem_result
);

reg         ms_valid;
wire        ms_ready_go;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire        ms_res_from_mem;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;
wire        ms_inst_no_dest;

reg  [31:0] mem_result;
wire [31:0] ms_final_result;
wire [2:0]  ms_ld_type;
wire [1:0]  ms_st_type;
wire [13:0] ms_csr_num;
wire         ms_csr_we;
wire [31:0] ms_csr_wdata;
wire [31:0] ms_csr_wmask;
wire         ms_ex_in;
wire [14:0]  ms_ex_code_in;
wire         ms_inst_ertn;
wire         ms_ex_out;
wire [14:0]  ms_ex_code_out;
wire [31:0]  ms_csr_rdata;
wire         ms_src_from_csr;

assign {ms_res_from_mem,  //70:70
        ms_ld_type,       //69:67
        ms_gr_we       ,  //69:69
        ms_st_type,       //68:67
        ms_dest        ,  //63:59
        ms_alu_result  ,  //58:27
        ms_pc          ,  //26:0
        ms_inst_no_dest, //1
        ms_src_from_csr, //1
        ms_csr_num,      //14
        ms_csr_we,       //1
        ms_csr_wdata,    //32
        ms_csr_wmask,    //32
        ms_ex_in,        //1
        ms_ex_code_in,   //15
        ms_inst_ertn,    //1
        ms_csr_rdata     //32
       } = es_to_ms_bus_r;

assign ms_to_ws_bus = {ms_gr_we       ,  //69:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc          ,  //31:0
                       ms_inst_no_dest,  //1
                       ms_src_from_csr,  //1
                       ms_csr_num      ,  //14
                       ms_csr_we       ,  //1
                       ms_csr_wdata    ,  //32
                       ms_csr_wmask    ,  //32
                       ms_ex_out       ,  //1
                       ms_ex_code_out  ,  //15
                       ms_inst_ertn       //1
                      };

assign ms_ready_go    = 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
assign ms_to_ds_dest  = ms_dest & {5{ms_valid & ~ms_inst_no_dest}};
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end
    else if (wb_ex || wb_ertn_flush) begin
        ms_valid <= 1'b0;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r  = es_to_ms_bus;
    end
end

assign ms_ex_out = ms_ex_in;
assign ms_ex_code_out = ms_ex_code_in;
assign mem_ertn_flush = ms_inst_ertn;
assign mem_ex = ms_ex_in;

always @(*) begin
    case (ms_ld_type)
        3'b000: begin // inst_ld_w
            mem_result <= data_sram_rdata;
        end 
        3'b001: begin // inst_ld_b
            case (ms_alu_result[1:0])
                2'b00: mem_result <= {{24{data_sram_rdata[7]}}, data_sram_rdata[7:0]};
                2'b01: mem_result <= {{24{data_sram_rdata[15]}}, data_sram_rdata[15:8]};
                2'b10: mem_result <= {{24{data_sram_rdata[23]}}, data_sram_rdata[23:16]};
                2'b11: mem_result <= {{24{data_sram_rdata[31]}}, data_sram_rdata[31:24]};
            endcase
        end
        3'b010:begin // inst_ld_h
            case (ms_alu_result[1:0])
                2'b00: mem_result <= {{16{data_sram_rdata[15]}}, data_sram_rdata[15:0]};
                2'b10: mem_result <= {{16{data_sram_rdata[31]}}, data_sram_rdata[31:16]};
            endcase
        end
        3'b011: begin // inst_ld_bu
            case (ms_alu_result[1:0])
                2'b00: mem_result <= {24'b0, data_sram_rdata[7:0]};
                2'b01: mem_result <= {24'b0, data_sram_rdata[15:8]};
                2'b10: mem_result <= {24'b0, data_sram_rdata[23:16]};
                2'b11: mem_result <= {24'b0, data_sram_rdata[31:24]};
            endcase
        end
        3'b100: begin // inst_ld_hu
            case (ms_alu_result[1:0])
                2'b00: mem_result <= {16'b0, data_sram_rdata[15:0]};
                2'b10: mem_result <= {16'b0, data_sram_rdata[31:16]};
            endcase
        end
        default: begin
            mem_result <= ms_alu_result;
            // $display("error: ms_ld_type = %d", ms_ld_type);
        end
    endcase
end

assign ms_final_result = ms_src_from_csr ? ms_csr_rdata : (ms_res_from_mem ? mem_result : ms_alu_result);
assign ms_to_ds_result = ms_final_result;

assign debug_ms_pc = ms_pc;
assign debug_mem_result = ms_final_result;

endmodule
