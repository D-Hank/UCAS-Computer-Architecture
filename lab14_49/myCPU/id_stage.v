`include "mycpu.h"

module id_stage(
    input                          clk                 ,
    input                          reset               ,
	input						   has_int			   ,
    //allowin
    input                          es_allowin          ,
    output                         ds_allowin          ,
    //from fs
    input                          fs_to_ds_valid      ,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus        ,
    //to es
    output                         ds_to_es_valid      ,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus        ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus              ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus        ,
    //forward: from es,ms,ws
    input  [`FORWARD_ES_TO_DS-1:0] forward_es_to_ds_bus,
    input  [`FORWARD_MS_TO_DS-1:0] forward_ms_to_ds_bus,
    input  [`FORWARD_WS_TO_DS-1:0] forward_ws_to_ds_bus,
    //from ws
    input  [`WS_TO_DS_BUS_WD -1:0] ws_to_ds_bus
);

	reg         ds_valid;
	wire        ds_ready_go;
	wire        ws_cancel_ds;
	assign      {ws_cancel_ds, has_int} = ws_to_ds_bus;
	reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;

	wire [31:0] ds_inst;
	wire [31:0] ds_pc;
    wire        fs_ex;
    wire [31:0] remap_vpc;
    wire [`ECODE_WD-1   :0] fs_ecode;
    wire [`ESUBCODE_WD-1:0] fs_esubcode;
	assign {remap_vpc, fs_ex, fs_ecode, fs_esubcode, ds_inst, ds_pc} = fs_to_ds_bus_r;

	wire        rf_we;
	wire [ 4:0] rf_waddr;
	wire [31:0] rf_wdata;
	assign {rf_we   ,  //37:37
	        rf_waddr,  //36:32
	        rf_wdata   //31:0
	       } = ws_to_rf_bus;

    wire        br_stall;
	wire        br_taken;
	wire [31:0] br_target;
	
	wire [6:0]  mul_div_op;
	wire [11:0] alu_op;
	wire        load_op;
	wire        load_sign;
	wire        op_b;
	wire        op_h;
	wire        op_w;
	wire        src1_is_pc;
	wire        src2_is_imm;
	wire        res_from_mem;
	wire        dst_is_r1;
	wire   		dst_is_rj;
	wire        rd_counter_low;
	wire    	rd_counter_high;
	wire        gr_we;
	wire        mem_we;
	wire        src_reg_is_rd;
	wire [4: 0] dest;
	wire [31:0] rj_value;
	wire [31:0] rkd_value;
	wire [31:0] ds_imm;
	wire [31:0] br_offs;
	wire [31:0] jirl_offs;
	
	wire [ 5:0] op_31_26;
	wire [ 1:0] op_25_24;
	wire [ 3:0] op_25_22;
	wire [ 1:0] op_21_20;
	wire [ 4:0] op_19_15;
	wire [ 4:0] op_14_10;
	wire [ 4:0] op_09_05;
	wire [ 4:0] op_04_00;
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
	wire [31:0] op_14_10_d;
	wire [31:0] op_09_05_d;
	wire [31:0] op_04_00_d;

	wire        inst_rdcntid_w;
	wire   		inst_rdcntvl_w;
	wire   		inst_rdcntvh_w;
	wire        inst_add_w;
	wire        inst_sub_w;
	wire        inst_slt;
	wire        inst_sltu;
	wire        inst_nor;
	wire        inst_and;
	wire        inst_or;
	wire        inst_xor;
	wire        inst_sll_w;
	wire        inst_srl_w;
	wire        inst_sra_w;
	wire        inst_mul_w;
	wire        inst_mulh_w;
	wire        inst_mulh_wu;
	wire        inst_div_w;
	wire        inst_mod_w;
	wire        inst_div_wu;
	wire        inst_mod_wu;
	wire        inst_break;
	wire        inst_syscall;
	wire        inst_slli_w;
	wire        inst_srli_w;
	wire        inst_srai_w;
	wire        inst_slti;
	wire        inst_sltui;
	wire        inst_addi_w;
	wire        inst_andi;
	wire        inst_ori;
	wire        inst_xori;
	wire        inst_csrrd;
	wire        inst_csrwr;
	wire        inst_csrxchg;
	wire		inst_tlbsrch;
	wire 		inst_tlbrd;
	wire  		inst_tlbwr;
	wire  		inst_tlbfill;
	wire        inst_ertn;
	wire  		inst_invtlb;
	wire        inst_lu12i_w;
	wire        inst_pcaddu12i;
	wire        inst_ld_b;
	wire        inst_ld_h;
	wire        inst_ld_w;
	wire        inst_st_b;
	wire        inst_st_h;
	wire        inst_st_w;
	wire        inst_ld_bu;
	wire        inst_ld_hu;
	wire        inst_jirl;
	wire        inst_b;
	wire        inst_bl;
	wire        inst_beq;
	wire        inst_bne;
	wire        inst_blt;
	wire        inst_bge;
	wire        inst_bltu;
	wire        inst_bgeu;
	wire  		inst_no_existing;

    wire        illegal_opcode;

	wire        need_ui5;
	wire        need_ui12;
	wire        need_si12;
	wire        need_si16;
	wire        need_si20;
	wire        need_si26;  
	wire        src2_is_4;
	
	wire [ 4:0] rf_raddr1;
	wire [31:0] rf_rdata1;
	wire [ 4:0] rf_raddr2;
	wire [31:0] rf_rdata2;

	wire        rj_eq_rd;
	wire        rj_lt_rd;
	wire        rj_ltu_rd;

	wire        csr_re;
	wire        csr_we;
	wire [31:0] csr_wmask;
	wire [13:0] csr_num;
	wire [ 8:0] ds_esubcode;
	wire [ 5:0] ds_ecode;
	wire        ds_ex;
	wire [ 4:0] tlb_op;
    wire        tlbsrch_revised;
    wire        memmap_revised;
    wire [`TLB_INV_OP_WD-1:0] invtlb_op;

	assign br_bus       = {br_stall,br_taken,br_target};

	assign ds_to_es_bus = {remap_vpc       ,  //270:239
                           memmap_revised ,  //238:238
                           tlbsrch_revised,  //237:237
                           invtlb_op      ,  //236:232
                           tlb_op         ,  //231:228
						   rd_counter_high,  //227:227
						   rd_counter_low ,  //226:226
						   csr_re         ,  //225:225
	                       csr_we         ,  //224:224
	                       csr_wmask      ,  //223:192
	                       csr_num        ,  //191:178
	                       ds_esubcode    ,  //177:169
	                       ds_ecode       ,  //168:163
	                       ds_ex	      ,  //162:162
	                       inst_ertn      ,  //161:161
	                       load_sign      ,  //160:160
	                       op_b           ,  //159:159
	                       op_h           ,  //158:158
						   op_w		      ,  //157:157
	                       mul_div_op     ,  //156:150
	                       alu_op         ,  //149:138
	                       load_op        ,  //137:137
	                       src1_is_pc     ,  //136:136
	                       src2_is_imm    ,  //135:135
	                       gr_we          ,  //134:134
	                       mem_we         ,  //133:133
	                       dest           ,  //132:128
	                       ds_imm         ,  //127:96
	                       rj_value       ,  //95 :64
	                       rkd_value      ,  //63 :32
	                       ds_pc             //31 :0
	                      };

	assign load_op        = inst_ld_b | inst_ld_h | inst_ld_w | inst_ld_bu | inst_ld_hu;
	assign load_sign      = inst_ld_b | inst_ld_h;
	assign op_b           = inst_ld_b | inst_ld_bu | inst_st_b;
	assign op_h           = inst_ld_h | inst_ld_hu | inst_st_h;
	assign op_w  		  = inst_ld_w | inst_st_w;
	assign csr_re         = inst_csrrd | inst_csrwr | inst_csrxchg | inst_rdcntid_w;
	assign csr_we         = inst_csrwr | inst_csrxchg;
	assign csr_num        = inst_ertn ? `CSR_ERA :
							inst_rdcntid_w ? `CSR_TID :
							ds_inst[23:10];
	assign csr_wmask      = inst_csrwr ? 32'hffffffff: inst_csrxchg ? rj_value : 32'b0;
    assign tlb_op         = {inst_tlbsrch, inst_tlbfill, inst_tlbwr, inst_tlbrd, inst_invtlb};
    assign invtlb_op      = ds_inst[4:0];
    assign tlbsrch_revised= ((inst_csrwr || inst_csrxchg) && (csr_num==`CSR_ASID || csr_num==`CSR_TLBEHI)) || inst_tlbrd;
	assign rd_counter_high= inst_rdcntvh_w;
	assign rd_counter_low = inst_rdcntvl_w;
    // NOTICE: here da/pg bit revision is IGNORED (by csrwr or csrxchg) !!!
    assign memmap_revised = inst_tlbwr | inst_tlbfill | inst_tlbrd | inst_invtlb;

	// forward module                                                                                                           
	wire 	to_block_ds;
	wire 	has_src1;
	wire 	has_src2;
	assign 	has_src1 = ~inst_lu12i_w   & ~inst_b      & ~inst_bl     & ~inst_pcaddu12i & ~inst_csrrd  & ~inst_csrwr
                     & ~inst_ertn      & ~inst_syscall& ~inst_tlbsrch& ~inst_tlbfill   & ~inst_tlbwr  & ~inst_tlbrd;

	assign 	has_src2 = ~inst_lu12i_w   & ~inst_b      & ~inst_bl     & ~inst_jirl      & ~inst_addi_w & ~inst_slli_w 
	                 & ~inst_srli_w    & ~inst_srai_w & ~inst_ld_b   & ~inst_ld_h      & ~inst_ld_w   & ~inst_ld_bu
	                 & ~inst_ld_hu     & ~inst_slti   & ~inst_sltui  & ~inst_andi      & ~inst_ori    & ~inst_xori  
	                 & ~inst_pcaddu12i & ~inst_csrrd  & ~inst_ertn   & ~inst_syscall;

	wire 	rs_is_x0;
	wire 	rt_is_x0;
	assign 	rs_is_x0 = (rf_raddr1 == 5'b0) ? 1'b1 : 1'b0;
	assign 	rt_is_x0 = (rf_raddr2 == 5'b0) ? 1'b1 : 1'b0;

	wire 	rs_valid;
	wire 	rt_valid;
	assign 	rs_valid = has_src1 & ~rs_is_x0;  //rs_valid=1 when addr1 is from rj and greater than 0                         
	assign 	rt_valid = has_src2 & ~rt_is_x0;  //rt_valid=1 when addr2 is from rk/rd and greater than 0                      

	wire 	rs_es_conflict, rs_ms_conflict, rs_ws_conflict;
	wire 	rt_es_conflict, rt_ms_conflict, rt_ws_conflict;
	//the value=1 when there has writing back and the dest is equal to any valid source which is not zero                     
	wire    [31:0] forward_es_data;
	wire    [31:0] forward_ms_data;
	wire    [31:0] forward_ws_data;
	wire 	[4:0]  forward_es_dest;
	wire    [4:0]  forward_ms_dest;
	wire    [4:0]  forward_ws_dest;
	wire   	forward_es_valid;
	wire    forward_ms_valid;
	wire    forward_ws_valid;
	wire    forward_es_blocked;
	wire   	forward_ms_blocked;

	assign  {forward_es_blocked,forward_es_data,forward_es_valid,forward_es_dest} = forward_es_to_ds_bus;
	assign  {forward_ms_blocked,forward_ms_data,forward_ms_valid,forward_ms_dest} = forward_ms_to_ds_bus;
	assign  {forward_ws_data,forward_ws_valid,forward_ws_dest} = forward_ws_to_ds_bus;

	assign 	rs_es_conflict = forward_es_valid & (rf_raddr1 == forward_es_dest) & rs_valid;                                 
	assign 	rs_ms_conflict = forward_ms_valid & (rf_raddr1 == forward_ms_dest) & rs_valid;                                 
	assign 	rs_ws_conflict = forward_ws_valid & (rf_raddr1 == forward_ws_dest) & rs_valid;                                 
	assign 	rt_es_conflict = forward_es_valid & (rf_raddr2 == forward_es_dest) & rt_valid;                                 
	assign 	rt_ms_conflict = forward_ms_valid & (rf_raddr2 == forward_ms_dest) & rt_valid;                                 
	assign 	rt_ws_conflict = forward_ws_valid & (rf_raddr2 == forward_ws_dest) & rt_valid;                                 
	assign 	to_block_ds    = (forward_es_blocked & (rs_es_conflict | rt_es_conflict)) |
						     (forward_ms_blocked & (rs_ms_conflict | rt_ms_conflict)); //block_valid=1 when the dest in load/csr instruction matches any valid source

	assign ds_ready_go    = !to_block_ds || ws_cancel_ds;
	assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
	assign ds_to_es_valid =  ds_valid && ds_ready_go && !ws_cancel_ds;
	always @(posedge clk)
	begin
	    if (reset)
	    begin
	        ds_valid <= 1'b0;
	    end
	    else if (ds_allowin)
	    begin
	        ds_valid <= fs_to_ds_valid;
	    end

	    if (fs_to_ds_valid && ds_allowin)
	    begin
	        fs_to_ds_bus_r <= fs_to_ds_bus;
	    end
	end

	assign op_31_26  = ds_inst[31:26];
	assign op_25_24  = ds_inst[25:24];
	assign op_25_22  = ds_inst[25:22];
	assign op_21_20  = ds_inst[21:20];
	assign op_19_15  = ds_inst[19:15];
	assign op_14_10  = ds_inst[14:10];
	assign op_09_05  = ds_inst[ 9: 5];
	assign op_04_00  = ds_inst[ 4: 0];

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
	decoder_5_32 u_dec4(.in(op_14_10 ), .out(op_14_10_d ));
	decoder_5_32 u_dec5(.in(op_09_05 ), .out(op_09_05_d ));
	decoder_5_32 u_dec6(.in(op_04_00 ), .out(op_04_00_d ));
	//to revise data path(rj/rd included)

	assign inst_rdcntid_w= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & op_14_10_d[5'h18] & op_04_00_d[5'h00];
	assign inst_rdcntvl_w= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & op_14_10_d[5'h18] & op_09_05_d[5'h00];
	assign inst_rdcntvh_w= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & op_14_10_d[5'h19] & op_09_05_d[5'h00];

	assign inst_add_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
	assign inst_sub_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
	assign inst_slt      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
	assign inst_sltu     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
	assign inst_nor      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
	assign inst_and      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
	assign inst_or       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
	assign inst_xor      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
	assign inst_sll_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
	assign inst_srl_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
	assign inst_sra_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
	
	assign inst_mul_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
	assign inst_mulh_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
	assign inst_mulh_wu  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
	assign inst_div_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
	assign inst_mod_w    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
	assign inst_div_wu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
	assign inst_mod_wu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];

	assign inst_break	 = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
	assign inst_syscall  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];

	assign inst_slli_w   = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
	assign inst_srli_w   = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
	assign inst_srai_w   = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
	
	assign inst_slti     = op_31_26_d[6'h00] & op_25_22_d[4'h8];
	assign inst_sltui    = op_31_26_d[6'h00] & op_25_22_d[4'h9];
	assign inst_addi_w   = op_31_26_d[6'h00] & op_25_22_d[4'ha];
	assign inst_andi     = op_31_26_d[6'h00] & op_25_22_d[4'hd];
	assign inst_ori      = op_31_26_d[6'h00] & op_25_22_d[4'he];
	assign inst_xori     = op_31_26_d[6'h00] & op_25_22_d[4'hf];
	
	assign inst_csrrd    = op_31_26_d[6'h01] & op_25_24==2'b0 & op_09_05_d[5'h00];
	assign inst_csrwr    = op_31_26_d[6'h01] & op_25_24==2'b0 & op_09_05_d[5'h01];
	assign inst_csrxchg  = op_31_26_d[6'h01] & op_25_24==2'b0 & rj!=5'b00 & rj!=5'b01;

	assign inst_tlbsrch  = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & op_14_10_d[5'h0a];
	assign inst_tlbrd	 = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & op_14_10_d[5'h0b];
	assign inst_tlbwr	 = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & op_14_10_d[5'h0c];
	assign inst_tlbfill	 = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & op_14_10_d[5'h0d];
	assign inst_ertn     = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & op_14_10_d[5'h0e];
    assign inst_invtlb   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h13];

	assign inst_lu12i_w  = op_31_26_d[6'h05] & ~ds_inst[25];
	assign inst_pcaddu12i= op_31_26_d[6'h07] & ~ds_inst[25];
	
	assign inst_ld_b     = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
	assign inst_ld_h     = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
	assign inst_ld_w     = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
	assign inst_st_b     = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
	assign inst_st_h     = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
	assign inst_st_w     = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
	assign inst_ld_bu    = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
	assign inst_ld_hu    = op_31_26_d[6'h0a] & op_25_22_d[4'h9];

	assign inst_jirl     = op_31_26_d[6'h13];
	assign inst_b        = op_31_26_d[6'h14];
	assign inst_bl       = op_31_26_d[6'h15];
	assign inst_beq      = op_31_26_d[6'h16];
	assign inst_bne      = op_31_26_d[6'h17];
	assign inst_blt      = op_31_26_d[6'h18];
	assign inst_bge      = op_31_26_d[6'h19];
	assign inst_bltu     = op_31_26_d[6'h1a];
	assign inst_bgeu     = op_31_26_d[6'h1b];

	//NOTICE: here subcode error is IGNORED !!!
	assign inst_no_existing = ~inst_rdcntid_w & ~inst_rdcntvl_w & ~inst_rdcntvh_w & ~inst_add_w   &
							  ~inst_sub_w     & ~inst_slt       & ~inst_sltu	  & ~inst_nor	  &
							  ~inst_and	      & ~inst_or		& ~inst_xor		  & ~inst_sll_w   &
							  ~inst_srl_w	  & ~inst_sra_w	    & ~inst_mul_w 	  & ~inst_mulh_w  &
							  ~inst_mulh_wu   & ~inst_div_w	    & ~inst_mod_w	  & ~inst_div_wu  &
							  ~inst_mod_wu    & ~inst_break	    & ~inst_syscall   & ~inst_slli_w  &
                              ~inst_srli_w    & ~inst_srai_w    & ~inst_slti	  & ~inst_sltui	  &
                              ~inst_addi_w    & ~inst_andi	    & ~inst_ori		  & ~inst_xori	  &
                              ~inst_csrrd	  & ~inst_csrwr	    & ~inst_csrxchg	  & ~inst_tlbsrch &
                              ~inst_tlbrd     & ~inst_tlbwr     & ~inst_tlbfill   & ~inst_ertn	  &
                              ~inst_invtlb    & ~inst_lu12i_w   & ~inst_pcaddu12i & ~inst_ld_b	  &
                              ~inst_ld_h	  & ~inst_ld_w      & ~inst_st_b	  & ~inst_st_h	  &
                              ~inst_st_w	  & ~inst_ld_bu     & ~inst_ld_hu	  & ~inst_jirl	  &
                              ~inst_b		  & ~inst_bl	    & ~inst_beq		  & ~inst_bne	  &
                              ~inst_blt       & ~inst_bge	    & ~inst_bltu	  & ~inst_bgeu    | illegal_opcode;

    assign illegal_opcode = inst_invtlb && invtlb_op!= 5'd0 && invtlb_op!= 5'd1 && invtlb_op!= 5'd2 &&
                            invtlb_op!= 5'd3 && invtlb_op!= 5'd4 && invtlb_op!= 5'd5 && invtlb_op!= 5'd6;

	assign mul_div_op = {inst_mul_w   , 
	                     inst_mulh_w  , 
	                     inst_mulh_wu , 
	                     inst_div_w   , 
	                     inst_mod_w   , 
	                     inst_div_wu  , 
	                     inst_mod_wu
	                     };

	assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_b | inst_ld_h | inst_ld_w
	                    | inst_st_b | inst_st_h | inst_st_w | inst_ld_bu | inst_ld_hu
	                    | inst_jirl | inst_bl | inst_pcaddu12i;
	assign alu_op[ 1] = inst_sub_w;
	assign alu_op[ 2] = inst_slt | inst_slti;
	assign alu_op[ 3] = inst_sltu | inst_sltui;
	assign alu_op[ 4] = inst_and | inst_andi;
	assign alu_op[ 5] = inst_nor;
	assign alu_op[ 6] = inst_or | inst_ori;
	assign alu_op[ 7] = inst_xor | inst_xori;
	assign alu_op[ 8] = inst_slli_w | inst_sll_w;
	assign alu_op[ 9] = inst_srli_w | inst_srl_w;
	assign alu_op[10] = inst_srai_w | inst_sra_w;
	assign alu_op[11] = inst_lu12i_w;

	assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
	assign need_ui12  =  inst_andi | inst_ori | inst_xori;
	assign need_si12  =  inst_addi_w | inst_ld_b | inst_ld_h | inst_ld_w
	                    | inst_st_b | inst_st_h | inst_st_w | inst_ld_bu | inst_ld_hu
	                    | inst_slti | inst_sltui;
	assign need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
	assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;
	assign need_si26  =  inst_b | inst_bl;
	assign src2_is_4  =  inst_jirl | inst_bl;

	assign ds_imm = src2_is_4 ? 32'h4                      :
	        		need_si20 ? {i20[19:0]    , 12'b0    } :  //i20[16:5]==i12[11:0]
	        		need_ui12 ? {20'b0        , i12[11:0]} :
	                  			{{20{i12[11]}}, i12[11:0]} ;

	assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} : 
	                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

	assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

	assign src_reg_is_rd = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu
	                    | inst_st_b | inst_st_h | inst_st_w | inst_csrwr | inst_csrxchg;

	assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

	assign src2_is_imm   = inst_slli_w | 
	                       inst_srli_w |
	                       inst_srai_w |
	                       inst_addi_w |
	                       inst_ld_b   |
	                       inst_ld_h   |
	                       inst_ld_w   |
	                       inst_st_b   |
	                       inst_st_h   |
	                       inst_st_w   |
	                       inst_ld_bu  |
	                       inst_ld_hu  |
	                       inst_lu12i_w|
	                       inst_jirl   |
	                       inst_bl     |
	                       inst_slti   |
	                       inst_sltui  |
	                       inst_andi   |
	                       inst_ori    |
	                       inst_xori   |
	                       inst_pcaddu12i;

	assign res_from_mem  = inst_ld_b | inst_ld_h | inst_ld_w | inst_ld_bu | inst_ld_hu;
	assign dst_is_r1     = inst_bl;
	assign dst_is_rj	 = inst_rdcntid_w;
	assign gr_we         = ~inst_st_b  & ~inst_st_h    & ~inst_st_w  & ~inst_beq     & ~inst_bne     &
						   ~inst_blt   & ~inst_bge     & ~inst_bltu  & ~inst_bgeu    & ~inst_b       &
						   ~inst_ertn  & ~inst_syscall & ~inst_break & ~inst_tlbsrch & ~inst_tlbfill &
                           ~inst_tlbwr & ~inst_tlbrd   & ~inst_invtlb;

	assign mem_we        = inst_st_b | inst_st_h | inst_st_w;
	assign dest          = dst_is_r1 ? 5'd1 :
						   dst_is_rj ? rj :
						   rd;

	assign rf_raddr1 = rj;
	assign rf_raddr2 = src_reg_is_rd ? rd : rk;
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

	//forward module
	assign rj_value  = rs_es_conflict ? forward_es_data:
	                   rs_ms_conflict ? forward_ms_data:
	                   rs_ws_conflict ? forward_ws_data:
	                   rf_rdata1;
	assign rkd_value = rt_es_conflict ? forward_es_data:
	                   rt_ms_conflict ? forward_ms_data:
	                   rt_ws_conflict ? forward_ws_data:
	                   rf_rdata2;

	assign rj_eq_rd = (rj_value == rkd_value);
	assign rj_lt_rd = ($signed(rj_value) < $signed(rkd_value));
	assign rj_ltu_rd= (rj_value < rkd_value);

    assign br_stall  = (forward_es_blocked || forward_ms_blocked) && ds_valid
                   && ((inst_beq || inst_bne || inst_blt || inst_bge || inst_bltu || inst_bgeu || inst_jirl) && rs_es_conflict 
                   ||  (inst_beq || inst_bne || inst_blt || inst_bge || inst_bltu || inst_bgeu)              && rt_es_conflict);
	assign br_taken = (   inst_beq  &&  rj_eq_rd
	                   || inst_bne  && !rj_eq_rd
	                   || inst_blt  &&  rj_lt_rd
	                   || inst_bge  && !rj_lt_rd
	                   || inst_bltu &&  rj_ltu_rd
	                   || inst_bgeu && !rj_ltu_rd
	                   || inst_jirl
	                   || inst_bl
	                   || inst_b
	                  ) && ds_valid && ds_ready_go; 
	assign br_target = (inst_beq || inst_bne || inst_blt || inst_bge || inst_bltu || inst_bgeu || inst_bl || inst_b) ? (ds_pc + br_offs) : (rj_value + jirl_offs);

	assign ds_ex          = (fs_ex | inst_break | inst_syscall | inst_no_existing) & ds_valid;
	assign ds_ecode       = has_int ? `ECODE_INT:
							fs_ex ? fs_ecode:
                                    ({6{inst_break}} & `ECODE_BRK | {6{inst_syscall}} & `ECODE_SYS | {6{inst_no_existing}} & `ECODE_INE);
	assign ds_esubcode    = fs_ex ? fs_esubcode : `ESUBCODE_UNKNOWN;

endmodule
