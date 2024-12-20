`include "mycpu_head.v"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  ,
    // from es ms ws
    input  [4                  :0] es_to_ds_dest ,
    input  [4                  :0] ms_to_ds_dest ,
    input  [4                  :0] ws_to_ds_dest ,
    // 处理ld阻塞
    input                          es_to_ds_load_op,
    // 处理exe ms ws前递结果
    input  [31                 :0] es_to_ds_result ,
    input  [31                 :0] ms_to_ds_result ,
    input  [31                 :0] ws_to_ds_result,

    output [31                 :0] debug_id_pc
);

wire        br_taken;
wire [31:0] br_target;

wire [31:0] ds_pc;
wire [31:0] ds_inst;

reg         ds_valid   ;
wire        ds_ready_go;

wire [18:0] alu_op;

wire        load_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire        mem_we;
wire        src_reg_is_rd;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;

wire        inst_add_w;
wire        inst_sub_w;
wire        inst_slt;
wire        inst_sltu;
wire        inst_nor;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_slli_w;
wire        inst_srli_w;
wire        inst_srai_w;
wire        inst_addi_w;
wire        inst_ld_w;
wire        inst_st_w;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_lu12i_w;
wire        inst_slti;
wire        inst_sltui;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_sll;
wire        inst_srl;
wire        inst_sra;
wire        inst_pcaddu12i;
wire        inst_blt;
wire        inst_bge;
wire        inst_bltu;
wire        inst_bgeu;
wire        inst_st_b;
wire        inst_st_h;
wire        inst_ld_b;
wire        inst_ld_h;
wire        inst_ld_bu;
wire        inst_ld_hu;
wire        inst_mul_w;
wire        inst_mulh_w;
wire        inst_mulh_wu;
wire        inst_div_w;
wire        inst_div_wu;
wire        inst_mod_w;
wire        inst_mod_wu;

wire        need_ui5;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        need_ui12;
wire        src2_is_4;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;

wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;

wire [31:0] mem_result;
wire [31:0] final_result;

wire        inst_no_dest;
wire        rj_wait;
wire        rk_wait;
wire        rd_wait;
wire        src_no_rj;
wire        src_no_rk;
wire        src_no_rd;
wire        no_wait;
wire [1:0]  st_type;
wire [2:0]  ld_type;

wire        load_stall;

wire        div_or_mod_op;

assign op_31_26  = ds_inst[31:26];
assign op_25_22  = ds_inst[25:22];
assign op_21_20  = ds_inst[21:20];
assign op_19_15  = ds_inst[19:15];

assign rd   = ds_inst[ 4: 0];
assign rj   = ds_inst[ 9: 5];
assign rk   = ds_inst[14:10];

assign i12  = ds_inst[21:10];
assign i20  = ds_inst[24: 5];
assign i16  = ds_inst[25:10];
assign i26  = {ds_inst[ 9: 0], ds_inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

// 当前ID支持的所有指令，后续新指令将在此扩充
assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~ds_inst[25];
assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hf];
assign inst_sll    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_srl    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign inst_pcaddu12i= op_31_26_d[6'h07] & ~ds_inst[25];
assign inst_blt     = op_31_26_d[6'h18];
assign inst_bge     = op_31_26_d[6'h19];
assign inst_bltu    = op_31_26_d[6'h1a];
assign inst_bgeu    = op_31_26_d[6'h1b];
assign inst_st_b    = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h    = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
assign inst_ld_b    = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_h    = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_bu   = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu   = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
assign inst_mul_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulh_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
assign inst_div_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_div_wu  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mod_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_mod_wu  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | 
                    inst_st_w  | inst_jirl   | inst_bl   |
                    inst_pcaddu12i | inst_st_b | inst_st_h |
                    inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu;

assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt  | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltui;
assign alu_op[ 4] = inst_and  | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or     | inst_ori;
assign alu_op[ 7] = inst_xor    | inst_xori;
assign alu_op[ 8] = inst_slli_w | inst_sll;
assign alu_op[ 9] = inst_srli_w | inst_srl;
assign alu_op[10] = inst_srai_w | inst_sra;
assign alu_op[11] = inst_lu12i_w;
assign alu_op[12] = inst_mul_w;
assign alu_op[13] = inst_mulh_w;
assign alu_op[14] = inst_mulh_wu;
assign alu_op[15] = inst_div_w;
assign alu_op[16] = inst_div_wu;
assign alu_op[17] = inst_mod_w;
assign alu_op[18] = inst_mod_wu;

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w   | inst_st_w |
                     inst_slti   | inst_sltui  | inst_st_b | 
                     inst_st_h   | inst_ld_b   | inst_ld_h | 
                     inst_ld_bu  | inst_ld_hu;

assign need_ui12  =  inst_andi   | inst_ori    | inst_xori;

assign need_si16  =  inst_jirl   | inst_beq    | inst_bne |
                     inst_blt    | inst_bge    | inst_bltu|
                     inst_bgeu;

assign need_si20  =  inst_lu12i_w| inst_pcaddu12i;
assign need_si26  =  inst_b      | inst_bl;
assign src2_is_4  =  inst_jirl   | inst_bl;

assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
             need_ui5  ? {27'b0, i12[4:0]}          :
             need_ui12 ? {20'b0, i12[11:0]}         :
            /*need_si12*/{{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w | inst_blt |
                       inst_bge | inst_bltu | inst_bgeu| inst_st_b| 
                       inst_st_h;

assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     |
                       inst_pcaddu12i |
                       inst_slti   |
                       inst_sltui  |
                       inst_andi   |
                       inst_ori    |
                       inst_xori   |
                       inst_st_b   |
                       inst_st_h   |
                       inst_ld_b   |
                       inst_ld_h   |
                       inst_ld_bu  |
                       inst_ld_hu;

assign res_from_mem  = inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b &
                       ~inst_blt & ~inst_bge & ~inst_bltu & ~inst_bgeu &
                       ~inst_st_b & ~inst_st_h;
assign mem_we        = inst_st_w | inst_st_b | inst_st_h;
assign dest          = dst_is_r1 ? 5'd1 : rd;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;

assign inst_no_dest = inst_beq  | inst_bne | inst_st_w | inst_b | 
                      inst_blt  | inst_bge | inst_bltu | inst_bgeu|
                      inst_st_b | inst_st_h;

assign src_no_rj    = inst_b      | inst_bl     | inst_lu12i_w| inst_pcaddu12i;

assign src_no_rk    = inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w |
                      inst_ld_w   | inst_st_w   | inst_jirl   | inst_b      |
                      inst_bl     | inst_beq    | inst_bne    | inst_lu12i_w|
                      inst_blt    | inst_bge    | inst_bltu   | inst_bgeu   |
                      inst_pcaddu12i| inst_andi | inst_ori    | inst_xori   |
                      inst_st_b   | inst_st_h   | inst_ld_b   | inst_ld_h   |
                      inst_ld_bu  | inst_ld_hu;
assign src_no_rd    = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_blt & 
                      ~inst_bge & ~inst_bltu & ~inst_bgeu &
                      ~inst_st_b & ~inst_st_h;

assign rj_wait = ~src_no_rj && (rj != 5'b00000) && (rj == es_to_ds_dest || rj == ms_to_ds_dest || rj == ws_to_ds_dest);
assign rk_wait = ~src_no_rk && (rk != 5'b00000) && (rk == es_to_ds_dest || rk == ms_to_ds_dest || rk == ws_to_ds_dest);
assign rd_wait = ~src_no_rd && (rd != 5'b00000) && (rd == es_to_ds_dest || rd == ms_to_ds_dest || rd == ws_to_ds_dest);

assign no_wait = ~rj_wait & ~rk_wait & ~rd_wait;

assign load_stall = (es_to_ds_load_op) && ((rj == es_to_ds_dest && rj_wait) 
                                       ||  (rk == es_to_ds_dest && rk_wait) 
                                       ||  (rd == es_to_ds_dest && rd_wait));

regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

assign rj_value  = rj_wait ? ((rj == es_to_ds_dest) ? es_to_ds_result :
                              (rj == ms_to_ds_dest) ? ms_to_ds_result :
                                                      ws_to_ds_result) :
                   rf_rdata1;

assign rkd_value = rk_wait ? ((rk == es_to_ds_dest) ? es_to_ds_result :
                              (rk == ms_to_ds_dest) ? ms_to_ds_result :
                                                      ws_to_ds_result) :
                   rd_wait ? ((rd == es_to_ds_dest) ? es_to_ds_result :
                              (rd == ms_to_ds_dest) ? ms_to_ds_result :
                                                      ws_to_ds_result) :
                   rf_rdata2;

wire        br_cin;
wire        br_cout;
wire [31:0] br_result;

assign {br_cout, br_result[31:0]} = rj_value[31:0] + ~rkd_value[31:0] + 1'b1;

assign rj_lt_rd  = (rj_value[31] & ~rkd_value[31]) 
                 | ((rj_value[31] ~^ rkd_value[31]) & br_result[31]);
assign rj_ltu_rd = br_cout;

assign rj_eq_rd = (rj_value == rkd_value);
assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_blt  &&  rj_lt_rd
                   || inst_bge  && ~rj_lt_rd
                   || inst_bltu &&  rj_ltu_rd
                   || inst_bgeu && ~rj_ltu_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                )  && ds_valid && ~load_stall; // 非阻塞情况下指定是否要跳转

assign br_target = (inst_beq || inst_bne || inst_bl || inst_b ||
                    inst_blt || inst_bge || inst_bltu || inst_bgeu) ? (ds_pc + br_offs) :
                                                        /*inst_jirl*/ (rj_value + jirl_offs);

assign br_bus = {br_taken, br_target};

reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;

assign {ds_inst,
        ds_pc  } = fs_to_ds_bus_r;

assign debug_id_pc = ds_pc;

assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

assign load_op = inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu;

assign st_type = inst_st_w ? 2'b00 :
                 inst_st_b ? 2'b01 :
                 inst_st_h ? 2'b10 : 2'b11;

assign ld_type = inst_ld_w ? 3'b000 :
                 inst_ld_b ? 3'b001 :
                 inst_ld_h ? 3'b010 :
                 inst_ld_bu ? 3'b011 :
                 inst_ld_hu ? 3'b100 : 3'b101;

assign div_or_mod_op = inst_div_w | inst_mod_w | inst_div_wu | inst_mod_wu;

assign ds_to_es_bus = {alu_op       ,   // 19
                       load_op      ,   // 1
                       ld_type      ,   // 3
                       src1_is_pc   ,   // 1
                       src2_is_imm  ,   // 1
                       gr_we        ,   // 1
                       st_type      ,   // 2
                       mem_we       ,   // 1
                       dest         ,   // 5
                       imm          ,   // 32
                       rj_value     ,   // 32
                       rkd_value    ,   // 32
                       ds_pc        ,    // 32
                       res_from_mem ,
                       inst_no_dest,
                       div_or_mod_op
                    };

assign ds_ready_go    = ds_valid && ~load_stall;
assign ds_allowin     = (!ds_valid) || (ds_ready_go && es_allowin);
assign ds_to_es_valid = ds_valid && ds_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
    end
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end

    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end


endmodule
