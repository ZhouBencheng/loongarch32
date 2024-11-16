module alu(
  input  wire        clk,
  input  wire        reset,
  input  wire [18:0] alu_op,
  input  wire [31:0] alu_src1, //mod
  input  wire [31:0] alu_src2, //mod
  output wire [31:0] alu_result,
  output wire        m_axis_dout_tvalid
);

wire op_add;     //add operation
wire op_sub;     //sub operation
wire op_slt;     //signed compared and set less than
wire op_sltu;    //unsigned compared and set less than
wire op_and;     //bitwise and
wire op_nor;     //bitwise nor
wire op_or;      //bitwise or
wire op_xor;     //bitwise xor
wire op_sll;     //logic left shift
wire op_srl;     //logic right shift
wire op_sra;     //arithmetic right shift
wire op_lui;     //Load Upper Immediate 
wire op_mul;     //multiplication
wire op_mulh;    //multiplication high
wire op_mulhu;   //multiplication high unsigned
wire op_div;     //division
wire op_divu;    //division unsigned
wire op_mod;     //modulus
wire op_modu;    //modulus unsigned

// div IP
wire m_axis_dout_tvalid_signed;
wire m_axis_dout_tvalid_unsigned;

wire s_axis_div_tvalid_signed;
wire s_axis_div_tvalid_unsigned;

reg  div_status;
reg  next_div_status;

// control code decomposition
assign op_add   = alu_op[ 0];
assign op_sub   = alu_op[ 1];
assign op_slt   = alu_op[ 2];
assign op_sltu  = alu_op[ 3];
assign op_and   = alu_op[ 4];
assign op_nor   = alu_op[ 5];
assign op_or    = alu_op[ 6]; 
assign op_xor   = alu_op[ 7];
assign op_sll   = alu_op[ 8];
assign op_srl   = alu_op[ 9];
assign op_sra   = alu_op[10];
assign op_lui   = alu_op[11];
assign op_mul   = alu_op[12];
assign op_mulh  = alu_op[13];
assign op_mulhu = alu_op[14];
assign op_div   = alu_op[15];
assign op_divu  = alu_op[16];
assign op_mod   = alu_op[17];
assign op_modu  = alu_op[18];

wire [31:0] add_sub_result;
wire [31:0] slt_result;
wire [31:0] sr_result;
wire [31:0] sltu_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] lui_result;
wire [31:0] sll_result;
wire [64:0] sr64_result;
wire [64:0] mul64_result;
wire [31:0] mul_result;
wire [63:0] div64_result;
wire [63:0] divu64_result;

// 32-bit adder
wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [31:0] adder_result;
wire        adder_cout;

assign adder_a   = alu_src1;
assign adder_b   = adder_cin ? ~alu_src2 : alu_src2; // mod  //src1 - src2 rj-rk
assign adder_cin = op_sub | op_slt | op_sltu;
assign {adder_cout, adder_result[31: 0]} = adder_a[31: 0] + adder_b[31: 0] + adder_cin; 

// ADD, SUB result
assign add_sub_result = adder_result;

// SLT result
assign slt_result[31:1] = 31'b0;   //rj < rk 1
assign slt_result[0]    = (alu_src1[31] & ~alu_src2[31])
                        | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31]); 

// SLTU result
assign sltu_result[31:1] = 31'b0;
assign sltu_result[0]    = ~adder_cout;

// bitwise operation
assign and_result = alu_src1 & alu_src2;
assign or_result  = alu_src1 | alu_src2;
assign nor_result = ~or_result;
assign xor_result = alu_src1 ^ alu_src2;
assign lui_result = alu_src2;

// SLL result
assign sll_result = alu_src1 << alu_src2;   //mod //rj << i5  

// SRL, SRA result
assign sr64_result = {{32{op_sra & alu_src1[31]}}, alu_src1[31:0]} >> alu_src2; //rj >> i5 

assign sr_result = sr64_result[31:0];

// mul result
assign mul64_result = op_mul | op_mulh ? $signed(alu_src1) * $signed(alu_src2) :
                          /*op_mulhu*/   $unsigned(alu_src1) * $unsigned(alu_src2);

assign mul_result = op_mul ? mul64_result[31:0] : mul64_result[63:32];

always @(posedge clk) begin
  if (reset) begin
    div_status <= 1'b0;
  end else begin
    div_status <= next_div_status;
  end
end

always @(*) begin
  next_div_status = 1'b0;
  if (div_status) begin
    next_div_status = 1'b0;
  end else if (op_div | op_mod | op_divu | op_modu) begin
    next_div_status = 1'b1;
  end
end

assign s_axis_div_tvalid_signed = (op_div || op_mod) && !div_status;
assign s_axis_div_tvalid_unsigned = (op_divu || op_modu) && !div_status;

// div result
div_gen_signed u_div_gen_signed(
    .aclk(clk),
    .s_axis_divisor_tdata(alu_src2),
    .s_axis_divisor_tvalid(s_axis_div_tvalid_signed),
    .s_axis_dividend_tdata(alu_src1),
    .s_axis_dividend_tvalid(s_axis_div_tvalid_signed),
    .m_axis_dout_tdata(div64_result),
    .m_axis_dout_tvalid(m_axis_dout_tvalid_signed)
);

div_gen_unsigned u_div_gen_unsigned(
    .aclk(clk),
    .s_axis_divisor_tdata(alu_src2),
    .s_axis_divisor_tvalid(s_axis_div_tvalid_unsigned),
    .s_axis_dividend_tdata(alu_src1),
    .s_axis_dividend_tvalid(s_axis_div_tvalid_unsigned),
    .m_axis_dout_tdata(divu64_result),
    .m_axis_dout_tvalid(m_axis_dout_tvalid_unsigned)
);

assign m_axis_dout_tvalid = m_axis_dout_tvalid_signed | m_axis_dout_tvalid_unsigned;

// final result mux
assign alu_result = ({32{op_add|op_sub}} & add_sub_result)
                | ({32{op_slt       }} & slt_result)
                | ({32{op_sltu      }} & sltu_result)
                | ({32{op_and       }} & and_result)
                | ({32{op_nor       }} & nor_result)
                | ({32{op_or        }} & or_result)
                | ({32{op_xor       }} & xor_result)
                | ({32{op_lui       }} & lui_result)
                | ({32{op_sll       }} & sll_result)
                | ({32{op_srl | op_sra}} & sr_result)
                | ({32{op_mul | op_mulh | op_mulhu}} & mul_result)
                | ({32{op_div       }} & div64_result[63:32])
                | ({32{op_divu      }} & divu64_result[63:32])
                | ({32{op_mod       }} & div64_result[31:0])
                | ({32{op_modu      }} & divu64_result[31:0]);

endmodule
