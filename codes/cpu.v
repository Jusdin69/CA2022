module cpu #( // Do not modify interface
	parameter ADDR_W = 12,
	parameter INST_W = 32,
	parameter DATA_W = 11
)(
    input                   i_clk,
    input                   i_rst_n,
    input                   i_i_valid_inst, // from instruction memory
    input  [ INST_W-1 : 0 ] i_i_inst,       // from instruction memory
    input                   i_d_valid_data, // from data memory
    input  [ DATA_W-1 : 0 ] i_d_data,       // from data memory
    output                  o_i_valid_addr, // to instruction memory
    output [ ADDR_W-1 : 0 ] o_i_addr,       // to instruction memory
    output [ DATA_W-1 : 0 ] o_d_w_data,     // to data memory
    output [ ADDR_W-1 : 0 ] o_d_w_addr,     // to data memory
    output [ ADDR_W-1 : 0 ] o_d_r_addr,     // to data memory
    output                  o_d_MemRead,    // to data memory
    output                  o_d_MemWrite,   // to data memory
    output                  o_finish
);

integer i;
reg [2:0] cs,ns;
reg [ADDR_W-1:0] bta;
reg [INST_W-1:0] i_i_inst_w, i_i_inst_r;
reg [ADDR_W-1:0] o_i_addr_r, o_i_addr_w;
reg [DATA_W-1:0]    rs1_value, rs2_value;
reg [DATA_W-1 : 0]  reg_file_r[31:0], reg_file_w[31:0];
reg                 o_i_valid_addr_r, o_i_valid_addr_w; 
reg [ADDR_W-1 : 0]  pc_r, pc_w;
reg [ADDR_W-1 : 0]  o_d_w_addr_r, o_d_w_addr_w;
reg [ADDR_W-1 : 0]  o_d_r_addr_r, o_d_r_addr_w;
reg [DATA_W-1 : 0]  o_d_data_r, o_d_data_w;
reg                 o_d_MemRead_r, o_d_MemRead_w;
reg                 o_d_MemWrite_r, o_d_MemWrite_w;
reg                 o_finish_r, o_finish_w;
//ins. decode
wire [6:0] opcode = i_i_inst_r[6:0];
wire [4:0] rs1 = i_i_inst_r[19:15];
wire [4:0] rs2 = i_i_inst_r[24:20];
wire [4:0] rd = i_i_inst_r[11:7];
wire [2:0] func_3 = i_i_inst_r[14:12];
wire [6:0] func_7 = i_i_inst_r[31:25];
wire       imm_1 = i_i_inst_r[7:7]; //branch imm[11]
wire [3:0] imm_2 = i_i_inst_r[11:8]; //branch imm[4:1]
wire [5:0] imm_3 = i_i_inst_r[30:25]; //branch imm [10:5]
wire       imm_4 = i_i_inst_r[31:31]; //branch [12]
reg [DATA_W-1 : 0] alu_in_1;
reg [DATA_W-1 : 0] alu_in_2;

//output
assign o_finish = o_finish_r;
assign o_i_addr = pc_r;
assign o_d_w_addr = o_d_w_addr_r;
assign o_d_r_addr = o_d_r_addr_r;
assign o_i_valid_addr = o_i_valid_addr_r;
assign o_d_w_data = o_d_data_r;
assign o_d_MemWrite = o_d_MemWrite_r;
assign o_d_MemRead = o_d_MemRead_r;

//pipeline reg
reg stall_w,stall_r;
reg branch_r, branch_w;
reg signed [INST_W-1:0] pc_next;
//id
reg signed [DATA_W-1 : 0] sign_ext;
reg signed [DATA_W-1 : 0] addr_offset_w,addr_offset_r ;
reg [4:0] rs1_id_w,rs1_id_r;
reg [4:0] rs2_id_w, rs2_id_r;
reg [4:0] rd_id_w,rd_id_r;
reg [DATA_W-1 : 0] rs1_value_w, rs1_value_r;
reg [DATA_W-1 : 0] rs2_value_w, rs2_value_r;
reg o_id_MemRead_w, o_id_MemRead_r;
reg o_id_MemWrite_w, o_id_MemWrite_r;
reg rd_write_id_w,rd_write_id_r;
reg aluSrc_w, aluSrc_r;
//ex
reg [ADDR_W-1 : 0] alu_out_w, alu_out_r;
reg [4:0] rd_ex_w, rd_ex_r;
reg [DATA_W-1 : 0] data_to_be_store_w,data_to_be_store_r;
reg rd_write_ex_w,rd_write_ex_r;
//mem
reg [4:0] rd_mem_w, rd_mem_r;
reg rd_write_mem_w,rd_write_mem_r;
reg [ADDR_W-1 : 0] alu_out_mem_w, alu_out_mem_r;
//wb
reg [ADDR_W-1 : 0] write_back_data;
//forwarding
reg [2:0] alu_ctr_w, alu_ctr_r;

//#####################__pipeline__unit__###############################//
//if stage
/*
always @(*) begin

    if(~i_rst_n) begin 
        pc_w <=0;
        stall_w <= 0;
        branch_w <= 0;
    end

    if (i_i_valid_inst && !branch_r && !stall_r) begin
        i_i_inst_r = i_i_inst;
        pc_w = pc_r + 4;      
    end else begin
        if (branch_r) begin
            branch_w = 0;
            i_i_inst_r = 32'b0;
        end else if (stall_r) begin
            //o_i_valid_addr_w = 1;
            
            stall_w = 0;
        end
    end
end
*/

//id stage

always @(*) begin
    if(~i_rst_n) begin 
        pc_w <=0;
        stall_w <= 0;
        branch_w <= 0;
        i_i_inst_r <=0;
        pc_next <= 4;
    end
    {rs1_id_w ,rs2_id_w,rd_id_w} = {rs1,rs2,rd};
    sign_ext = {{52{func_7[6]}},func_7,rs2};
    addr_offset_w = {{52{func_7[6]}},func_7,rd};
    bta = {{52{imm_4}},imm_4, imm_1, imm_3, imm_2}<<1;
    rs1_value = reg_file_r[rs1];
    rs2_value = reg_file_r[rs2];
    
    //control
    if(i_i_valid_inst) begin
        if (!branch_r && !stall_r) begin
            i_i_inst_r = i_i_inst;
            pc_w = pc_r + 4;      
        end else begin
            if (branch_r) begin
                branch_w = 0;
                i_i_inst_r = 32'b0;
            end else if (stall_r) begin
                stall_w = 0;
            end
        end
        case (opcode)
            7'b0000011: begin //ld
                alu_ctr_w = 0;
                rs1_value_w = reg_file_r[rs1];
                rs2_value_w = sign_ext;
                o_id_MemWrite_w = 0;
                o_id_MemRead_w = 1;
                rd_write_id_w = 1;
                aluSrc_w = 0;
        
            end
            7'b0100011: begin //sd
                alu_ctr_w = 3'b111;
                rs1_value_w = reg_file_r[rs1];
                rs2_value_w = reg_file_r[rs2];
                o_id_MemWrite_w = 1;
                o_id_MemRead_w = 0;
                rd_write_id_w = 0;
                aluSrc_w = 1;
            end
            7'b1100011: begin // branch
                case(func_3)
                //beq
                3'b000: begin 
                    if(rs1_value == rs2_value && !branch_r)begin
                        pc_w = pc_r +$signed(bta)-4;
                        //pc_next = bta;
                        branch_w = 1;
                    end 
                    o_id_MemWrite_w = 0;
                    o_id_MemRead_w = 0;
                    rd_write_id_w = 0;
                
                end
                //bne
                3'b001: begin 
                    if(rs1_value != rs2_value && !branch_r) begin
                        pc_w = pc_r +$signed(bta)-4;
                        //pc_next = bta;
                        branch_w = 1;
                    end 
                    o_id_MemWrite_w = 0;
                    o_id_MemRead_w = 0;
                    rd_write_id_w = 0;
                
                end 
                endcase
            end
            7'b0010011: begin // immediate , shift
                case (func_3)
                    
                    3'b000: begin //addi
                        alu_ctr_w = 0;
                        rs1_value_w = reg_file_r[rs1];
                        rs2_value_w = sign_ext;
                        o_id_MemWrite_w = 0;
                        o_id_MemRead_w = 0;
                        rd_write_id_w = 1;
                        aluSrc_w = 0;
                    end

                    3'b100: begin //xori
                        alu_ctr_w = 3'b010;
                        rs1_value_w = reg_file_r[rs1];
                        rs2_value_w = sign_ext;
                        o_id_MemWrite_w = 0;
                        o_id_MemRead_w = 0;
                        rd_write_id_w = 1;
                        aluSrc_w = 0;
                    end

                    3'b110: begin //ori
                        alu_ctr_w = 3'b011;
                        rs1_value_w = reg_file_r[rs1];
                        rs2_value_w = sign_ext;
                        o_id_MemWrite_w = 0;
                        o_id_MemRead_w = 0;
                        rd_write_id_w = 1;
                        aluSrc_w = 0;
                    end

                    3'b111: begin //andi
                        alu_ctr_w = 3'b100;
                        rs1_value_w = reg_file_r[rs1];
                        rs2_value_w = sign_ext;
                        o_id_MemWrite_w = 0;
                        o_id_MemRead_w = 0;
                        rd_write_id_w = 1;
                        aluSrc_w = 0;
                    end

                    3'b001: begin //slli
                    //rd_value = rs1_value << rs2;
                        alu_ctr_w = 3'b101;
                        rs1_value_w = reg_file_r[rs1];
                        rs2_value_w = rs2;
                        o_id_MemWrite_w = 0;
                        o_id_MemRead_w = 0;
                        rd_write_id_w = 1;
                        aluSrc_w = 0;
                    end

                    3'b101: begin //srli
                    //rd_value = rs1_value >> rs2;
                        alu_ctr_w = 3'b110;
                        rs1_value_w = reg_file_r[rs1];
                        rs2_value_w = rs2;
                        o_id_MemWrite_w = 0;
                        o_id_MemRead_w = 0;
                        rd_write_id_w = 1;
                        aluSrc_w = 0;
                    end     
                endcase 
            end
            7'b0110011: begin // r-type
                case(func_7) 
                7'b0000000: begin //
                    case(func_3)
                        3'b000: begin //add
                            //rd_value = rs1_value + rs2_value;
                            alu_ctr_w = 0;
                            rs1_value_w = reg_file_r[rs1];
                            rs2_value_w = reg_file_r[rs2];
                            o_id_MemWrite_w = 0;
                            o_id_MemRead_w = 0;
                            rd_write_id_w = 1; 
                            aluSrc_w = 1;                    
                        end
                        
                        3'b100: begin //XOR
                            //rd_value = rs1_value ^ rs2_value;
                            alu_ctr_w = 3'b010;
                            rs1_value_w = reg_file_r[rs1];
                            rs2_value_w = reg_file_r[rs2];
                            o_id_MemWrite_w = 0;
                            o_id_MemRead_w = 0;
                            rd_write_id_w = 1; 
                            aluSrc_w = 1;                 
                        end

                        3'b110: begin //OR
                            //rd_value = rs1_value | rs2_value;
                            alu_ctr_w = 3'b011;
                            rs1_value_w = reg_file_r[rs1];
                            rs2_value_w = reg_file_r[rs2];
                            o_id_MemWrite_w = 0;
                            o_id_MemRead_w = 0;
                            rd_write_id_w = 1;
                            aluSrc_w = 1;             
                        end

                        3'b111: begin //and
                            //rd_value = rs1_value & rs2_value;
                            alu_ctr_w = 3'b100;  
                            rs1_value_w = reg_file_r[rs1];
                            rs2_value_w = reg_file_r[rs2];
                            o_id_MemWrite_w = 0;
                            o_id_MemRead_w = 0;
                            rd_write_id_w = 1;
                            aluSrc_w = 1;                   
                        end
                        
                    endcase
                end

                7'b0100000: begin //sub
                    //rd_value = rs1_value - rs2_value;
                    alu_ctr_w = 3'b001;
                    rs1_value_w = reg_file_r[rs1];
                    rs2_value_w = reg_file_r[rs2]; 
                    o_id_MemWrite_w = 0;
                    o_id_MemRead_w = 0;
                    rd_write_id_w = 1;
                    aluSrc_w = 1;  
                end
                endcase 
            end
            7'b1111111:begin
                o_id_MemWrite_w = 0;
                o_id_MemRead_w = 0;
                rd_write_id_w = 0; 
            end                          
        endcase
    end
    //hazard (load use problem)ee
    if((rd_id_r == rs1 || rd_id_r == rs2) && o_id_MemRead_r && !stall_r) begin
        stall_w = 1;
        pc_w = pc_r-4;
        //pc_next = -4;
        o_id_MemWrite_w = 0;
        o_id_MemRead_w = 0;
        rd_write_id_w = 0; 
    end
    /*
    if (i_i_valid_inst && !branch_r && !stall_r) begin
        pc_w = pc_r + pc_next;
        pc_next = 4;
    end*/
end
//ex stage
always @(*) begin
    
    //forwarding
    //rs1 in
    if(rs1_id_r == rd_ex_r && rd_write_ex_r)begin
        alu_in_1 = alu_out_r; // from alu out
    end else if(rs1_id_r == rd_mem_r && rd_write_mem_r) begin 
        alu_in_1 = write_back_data; // from mem out
    end  else alu_in_1 = rs1_value_r;;
    //rs2 in
    if(rs2_id_r == rd_ex_r && rd_write_ex_r)begin
        alu_in_2 = alu_out_r; // from alu out
    end else if(rs2_id_r == rd_mem_r && rd_write_mem_r) begin 
        alu_in_2 = write_back_data; // from mem out
    end  else alu_in_2 = rs2_value_r;


    case(alu_ctr_r)
        3'b000: alu_out_w = $signed(alu_in_1) + $signed(alu_in_2);
        3'b001: alu_out_w = $signed(alu_in_1) - $signed(alu_in_2);
        3'b010: alu_out_w = alu_in_1 ^ alu_in_2;
        3'b011: alu_out_w = alu_in_1 | alu_in_2;
        3'b100: alu_out_w = alu_in_1 & alu_in_2;
        3'b101: alu_out_w = alu_in_1 << alu_in_2;
        3'b110: alu_out_w = alu_in_1 >> alu_in_2;
        3'b111: alu_out_w = $signed(alu_in_1) + $signed(addr_offset_r);
    endcase

    rd_ex_w = rd_id_r;
    rd_write_ex_w = rd_write_id_r;
    //for ld sd
    o_d_r_addr_w = alu_out_w;
    o_d_w_addr_w = alu_out_w;
    o_d_MemRead_w = o_id_MemRead_r;
    o_d_MemWrite_w = o_id_MemWrite_r;
    o_d_data_w = alu_in_2;

end

//mem stage
always @(*) begin
    rd_mem_w = rd_ex_r;
    rd_write_mem_w = rd_write_ex_r;
    alu_out_mem_w = alu_out_r;
end

//wb stage
/*
always @(*) begin
    if(~)
    if(rd_write_mem_r)begin
        if(i_d_valid_data) begin
            write_back_data = i_d_data;
        end else begin
            write_back_data = alu_out_mem_r;
        end
    reg_file_w[rd_mem_r] = write_back_data;  
    end
end
*/

always @(*) begin
    if(~i_rst_n) ns<=0;
    case(cs)
        0: ns = (&(i_i_inst_r[31:0])) ? 1:0;
        1: ns =2;
        2: o_finish_w = 1;
    endcase
end


/////#########################################################################################/////


always @(posedge i_clk or negedge i_rst_n) begin
    if(~i_rst_n) begin
        cs<=0;
        //ns<=0;
        pc_r           <= 0;
        //pc_w           <= 0;     
        o_i_valid_addr_r <= 0;
        o_i_valid_addr_w <= 1;
        
        i_i_inst_w <=0;
        o_finish_r     <= 0;
        o_i_addr_r     <= 0;
        o_d_data_r     <= 0;
        o_d_r_addr_r     <= 0;
        o_d_w_addr_r     <= 0;
        o_d_MemWrite_r <= 0;
        o_d_MemRead_r  <= 0;
        
        //forwarding
        //if
        stall_r <= 0;
        //stall_w <= 0;
        branch_r <=0;
        //branch_w<=0;
        //id
        rs1_id_r <= 0;
        rs2_id_r <= 0;
        rd_id_r <= 0;
        alu_ctr_r <= 0;
        rs1_value_r <= 0;
        rs2_value_r <= 0;
        o_id_MemRead_r <= 0;
        o_id_MemWrite_r <= 0;
        rd_write_id_r <= 0;
        addr_offset_r <= 0;
        aluSrc_r <=0;
        //ex
        alu_out_r <= 0;
        rd_ex_r <= 0;
        data_to_be_store_r <= 0;
        rd_write_ex_r <= 0;
        //mem
        rd_mem_r <= 0;
        rd_write_mem_r <= 0;
        alu_out_mem_r <= 0;

    end else begin
        cs<=ns;
        pc_r           <= pc_w;
        o_i_valid_addr_r    <= o_i_valid_addr_w;
        //i_i_inst_r <= i_i_inst_w;
        o_finish_r     <= o_finish_w;
        o_d_data_r     <= o_d_data_w;
        o_d_r_addr_r     <= o_d_r_addr_w;
        o_d_w_addr_r     <= o_d_w_addr_w;
        o_d_MemWrite_r <= o_d_MemWrite_w;
        o_d_MemRead_r  <= o_d_MemRead_w;

        //if
        stall_r <= stall_w;
        branch_r <= branch_w;
        //id
        rs1_id_r <= rs1_id_w;
        rs2_id_r <= rs2_id_w;
        rd_id_r <= rd_id_w;
        alu_ctr_r <= alu_ctr_w;
        rs1_value_r <= rs1_value_w;
        rs2_value_r <= rs2_value_w;
        o_id_MemRead_r <= o_id_MemRead_w;
        o_id_MemWrite_r <= o_id_MemWrite_w;
        rd_write_id_r <= rd_write_id_w;
        addr_offset_r <= addr_offset_w;
        aluSrc_r <= aluSrc_w;
        //ex
        alu_out_r <= alu_out_w;
        rd_ex_r <= rd_ex_w;
        data_to_be_store_r <= data_to_be_store_w;
        rd_write_ex_r <= rd_write_ex_w;
        //mem
        rd_mem_r <= rd_mem_w;
        rd_write_mem_r <= rd_write_mem_w;
        alu_out_mem_r <= alu_out_mem_w;           
    end
end

always @( negedge i_rst_n or negedge i_clk) begin
    if(~i_rst_n) begin
        for (i=0; i < 32; i=i+1) begin
            reg_file_w[i] <= 0;
            reg_file_r[i] <= 0;
        end
    end else begin
        if(rd_write_mem_r)begin
        if(i_d_valid_data) begin
            write_back_data = i_d_data;
        end else begin
            write_back_data = alu_out_mem_r;
        end
    reg_file_w[rd_mem_r] = write_back_data;  
    end
        for (i=0; i < 32; i=i+1)
            reg_file_r[i] <= reg_file_w[i];        
    end
end



endmodule
