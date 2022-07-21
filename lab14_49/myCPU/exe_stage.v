`include "mycpu.h"

module exe_stage(
    input                          clk                  ,
    input                          reset                ,
    // allowin
    input                          ms_allowin           ,
    output                         es_allowin           ,
    // from ds
    input                          ds_to_es_valid       ,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus         ,
    // to ms
    output                         es_to_ms_valid       ,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus         ,
    // data sram interface
    output                         data_sram_req        ,
    output                         data_sram_wr         ,
    output [ 1:0]                  data_sram_size       ,
    output [31:0]                  data_sram_addr       ,
    output [ 3:0]                  data_sram_wstrb      ,
    output [31:0]                  data_sram_wdata      ,
    input                          data_sram_addr_ok    ,
    // forward: to ds
    output [`FORWARD_ES_TO_DS-1:0] forward_es_to_ds_bus ,
    // from ws
    input  [`WS_TO_ES_BUS_WD -1:0] ws_to_es_bus         ,
    // from ms
    input  [`MS_TO_ES_BUS_WD -1:0] ms_to_es_bus   		,

    output                         tlbsrch_valid        ,
    output [`TLB_VPPN_WD     -1:0] s1_vppn              ,
    output                         s1_va_bit12          ,
    output [`TLB_ASID_WD     -1:0] s1_asid              ,
    input                          s1_found             ,
    input  [`TLB_LOG_NUM     -1:0] s1_index             ,
    input  [`TLB_PPN_WD      -1:0] s1_ppn               ,
    input  [`TLB_PS_WD       -1:0] s1_ps                ,
    input  [`TLB_PLV_WD      -1:0] s1_plv               ,
    input  [`TLB_MAT_WD      -1:0] s1_mat               ,
    input                          s1_d                 ,
    input                          s1_v                 ,

    output                         invtlb_valid         ,
    output [`TLB_INV_OP_WD   -1:0] invtlb_op            ,
	input  [`CSR_TO_EXE      -1:0] csr_to_exe_bus
);

    reg         es_valid      ;
	wire        es_ready_go   ;
	wire        ws_cancel_es  ;
	wire        ms_cancel_es  ;

	//data sram
    reg         es_addr_ok;
    wire        es_mem_valid;
    wire [ 2:0] wstrb_bits;
    wire [ 3:0] es_sram_wstrb;
    
    wire        maddr_unalign;
	wire        store_error;
	wire        load_error;
	wire        es_addr_error;
	wire        es_load_valid;
	wire        es_store_valid;
	
	reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
	wire [6:0]  es_mul_div_op ;
	wire [11:0] es_alu_op     ;
	wire        es_src1_is_pc ;
	wire        es_src2_is_imm; 
	wire        es_gr_we      ;
	wire        es_mem_we     ;
	wire [ 4:0] es_dest       ;
	wire [31:0] es_imm        ;
	wire [31:0] es_rj_value   ;
	wire [31:0] es_rkd_value  ;
	wire [31:0] es_pc         ;

	wire        es_res_from_mem;
	wire        es_load_sign;
	wire        es_op_b;
	wire        es_op_h;
    wire        es_op_w;
	wire        op_st_b;
	wire        op_st_h;
	wire        op_st_w;
	
	wire        csr_re;
	wire        csr_we;
	wire [31:0] csr_wmask;
	wire [13:0] csr_num;
	wire [ 8:0] ds_esubcode;
	wire [ 5:0] ds_ecode;
	wire        ds_ex;
	wire [ 8:0] es_esubcode;
	wire [ 5:0] es_ecode;
	wire        es_ex;
	wire [31:0] es_vaddr;
	wire        inst_ertn;
    wire [ 4:0] tlb_op;
    wire        tlbsrch_revised;
    wire        memmap_revised;
    wire [31:0] remap_vpc;
    wire        rd_counter_high;
    wire        rd_counter_low;
	
	assign {remap_vpc      ,  //267:236
            memmap_revised ,  //235:235
            tlbsrch_revised,  //234:234
            invtlb_op      ,  //233:229
            tlb_op         ,  //228:228
            rd_counter_high,  //227:227
			rd_counter_low ,  //226:226
			csr_re         ,  //225:225
	        csr_we         ,  //224:224
	        csr_wmask      ,  //223:192
	        csr_num        ,  //191:178
	        ds_esubcode    ,  //177:169
	        ds_ecode       ,  //168:163
	        ds_ex          ,  //162:162
	        inst_ertn      ,  //161:161
	        es_load_sign,     //160:160
	        es_op_b		   ,  //159:159
	        es_op_h		   ,  //158:158
            es_op_w        ,  //157:157
	        es_mul_div_op  ,  //156:150
	        es_alu_op      ,  //149:138
	        es_res_from_mem,  //137:137
	        es_src1_is_pc  ,  //136:136
	        es_src2_is_imm ,  //135:135
	        es_gr_we       ,  //134:134
	        es_mem_we      ,  //133:133
	        es_dest        ,  //132:128
	        es_imm         ,  //127:96
	        es_rj_value    ,  //95 :64
	        es_rkd_value   ,  //63 :32
	        es_pc             //31 :0
	       } = ds_to_es_bus_r;

    wire [`CSR_TLBIDX_IDX ] csr_tlbidx_idx;
    wire [`CSR_TLBEHI_VPPN] csr_tlbehi_vppn;
    wire [`CSR_ASID_ASID  ] csr_asid_asid;

    assign {csr_tlbidx_idx,
            csr_tlbehi_vppn,
            csr_asid_asid
            } = csr_to_exe_bus;
	
	wire [31:0] es_alu_src1   ;
	wire [31:0] es_alu_src2   ;
	wire [31:0] es_alu_result ;
	wire [31:0] es_result     ;
	wire [ 1:0] last_two;

	//assign es_res_from_mem = es_load_op;
	assign es_to_ms_bus = {remap_vpc      ,  //212:181
                           memmap_revised ,  //180:180
                           tlbsrch_revised,  //179:179
                           tlb_op         ,  //178:174
                           es_store_valid ,  //173:173
	                       csr_re         ,  //172:172
	                       csr_we         ,  //171:171
	                       csr_wmask      ,  //170:159
	                       csr_num        ,  //158:125
						   es_vaddr		  ,  //124:93
	                       es_esubcode    ,  //92:84
	                       es_ecode       ,  //83:78
	                       es_ex          ,  //77:77
	                       inst_ertn      ,  //76:76
	                       last_two       ,  //75:74
	                       es_load_sign   ,  //73:73
	                       es_op_b        ,  //72:72
	                       es_op_h        ,  //71:71
	                       es_load_valid  ,  //70:70
	                       es_gr_we       ,  //69:69
	                       es_dest        ,  //68:64
	                       es_result      ,  //63:32
	                       es_pc             //31:0
	                      };
	
	//mul module
	wire [63:0] unsigned_prod, signed_prod;
	assign unsigned_prod = es_rj_value          * es_rkd_value;
	assign signed_prod   = $signed(es_rj_value) * $signed(es_rkd_value);

	//div module
	reg         sfirst                 ;
	reg         usfirst                ;
	reg         s_axis_divisor_tvalid  ;
	wire        s_axis_divisor_tready  ;
	reg         s_axis_dividend_tvalid ;
	wire        s_axis_dividend_tready ;
	wire        m_axis_dout_tvalid     ;
	wire [63:0] m_axis_dout_tdata      ;
	
	reg         us_axis_divisor_tvalid ;
	wire        us_axis_divisor_tready ;
	reg         us_axis_dividend_tvalid;
	wire        us_axis_dividend_tready;
	wire        um_axis_dout_tvalid    ;
	wire [63:0] um_axis_dout_tdata     ;
	
	always @(posedge clk)
	begin
	    if (reset)
		begin
	        s_axis_divisor_tvalid <= 1'b0;
	    end
	    else if (s_axis_divisor_tvalid & s_axis_divisor_tready)
		begin
	        s_axis_divisor_tvalid <= 1'b0;
	    end
	    else if ((es_mul_div_op[2] | es_mul_div_op[3]) & ~sfirst & es_valid)
		begin
	        s_axis_divisor_tvalid <= 1'b1;
	    end
	
	    if (reset)
		begin
	        s_axis_dividend_tvalid <= 1'b0;
	    end
	    else if (s_axis_dividend_tvalid & s_axis_dividend_tready)
		begin
	        s_axis_dividend_tvalid <= 1'b0;
	    end
	    else if ((es_mul_div_op[2] | es_mul_div_op[3]) & ~sfirst & es_valid)
		begin
	        s_axis_dividend_tvalid <= 1'b1;
	    end

	    if (reset)
		begin
	        us_axis_divisor_tvalid <= 1'b0;
	    end
	    else if (us_axis_divisor_tvalid & us_axis_divisor_tready)
		begin
	        us_axis_divisor_tvalid <= 1'b0;
	    end
	    else if ((es_mul_div_op[0] | es_mul_div_op[1]) & ~usfirst & es_valid)
		begin
	        us_axis_divisor_tvalid <= 1'b1;
	    end 
	
	    if (reset)
		begin
	        us_axis_dividend_tvalid <= 1'b0;
	    end
	    else if (us_axis_dividend_tvalid & us_axis_dividend_tready)
		begin
	        us_axis_dividend_tvalid <= 1'b0;
	    end
	    else if ((es_mul_div_op[0] | es_mul_div_op[1]) & ~usfirst & es_valid)
		begin
	        us_axis_dividend_tvalid <= 1'b1;
	    end
	
	    if (reset)
		begin
	        sfirst <= 1'b0;
	    end 
	    else if ((es_mul_div_op[2] | es_mul_div_op[3]) & ~sfirst & es_valid)
		begin
	        sfirst <= 1'b1;
	    end
	    else if (m_axis_dout_tvalid)
		begin
	        sfirst <= 1'b0;
	    end
	 
	    if (reset)
		begin
	        usfirst <= 1'b0;
	    end 
	    else if ((es_mul_div_op[0] | es_mul_div_op[1]) & ~usfirst & es_valid)
		begin
	        usfirst <= 1'b1;
	    end
	    else if (um_axis_dout_tvalid)
		begin
	        usfirst <= 1'b0;
	    end

	end

	signed_div div(
	    .aclk                    (clk                    ),
	    .s_axis_divisor_tvalid   (s_axis_divisor_tvalid  ),
	    .s_axis_divisor_tready   (s_axis_divisor_tready  ),
	    .s_axis_divisor_tdata    (es_rkd_value           ),
	    .s_axis_dividend_tvalid  (s_axis_dividend_tvalid ),
	    .s_axis_dividend_tready  (s_axis_dividend_tready ),
	    .s_axis_dividend_tdata   (es_rj_value            ),
	    .m_axis_dout_tvalid      (m_axis_dout_tvalid     ),
	    .m_axis_dout_tdata       (m_axis_dout_tdata      )
	    );
	    
	unsigned_div udiv(
	    .aclk                    (clk                     ),
	    .s_axis_divisor_tvalid   (us_axis_divisor_tvalid  ),
	    .s_axis_divisor_tready   (us_axis_divisor_tready  ),
	    .s_axis_divisor_tdata    (es_rkd_value            ),
	    .s_axis_dividend_tvalid  (us_axis_dividend_tvalid ),
	    .s_axis_dividend_tready  (us_axis_dividend_tready ),
	    .s_axis_dividend_tdata   (es_rj_value             ),
	    .m_axis_dout_tvalid      (um_axis_dout_tvalid     ),
	    .m_axis_dout_tdata       (um_axis_dout_tdata      )
	    );
	
	//mul+div+mod result
	wire [31:0] HI;
	wire [31:0] LO;
	assign HI = es_mul_div_op[1] ? um_axis_dout_tdata[63:32] :
	            es_mul_div_op[3] ? m_axis_dout_tdata[63:32]  :
	            es_mul_div_op[4] ? unsigned_prod[63:32]      :
	            es_mul_div_op[5] ? signed_prod[63:32]        :
	            32'b0;
	
	assign LO = es_mul_div_op[0] ? um_axis_dout_tdata[31:0]  :
	            es_mul_div_op[2] ? m_axis_dout_tdata[31:0]   :
	            es_mul_div_op[6] ? signed_prod[31:0]         :
	            32'b0;
	
	reg [63:0] stable_cnt;
	always @(posedge clk)
	begin
    	if(reset)
    	begin
        	stable_cnt <= 64'b0;
    	end
    	else
    	begin
        	stable_cnt <= stable_cnt + 1'b1;
    	end
	end
	wire [31:0] counter_value = rd_counter_high ? stable_cnt[63:32] : stable_cnt[31:0];

	assign es_result=(es_mul_div_op[1] | es_mul_div_op[3] | es_mul_div_op[4] | es_mul_div_op[5]) ? HI :
	                 (es_mul_div_op[0] | es_mul_div_op[2] | es_mul_div_op[6])                    ? LO :
					 (rd_counter_high | rd_counter_low) ? counter_value :
					 csr_we ? es_rkd_value : es_alu_result;

    assign es_mem_valid   = (es_load_valid || es_store_valid) && es_valid;
	assign es_ready_go    = es_mem_valid ? (data_sram_req || ws_cancel_es) && data_sram_addr_ok
	                      : (es_mul_div_op[0] || es_mul_div_op[1]) ? um_axis_dout_tvalid || ws_cancel_es
	                      : (es_mul_div_op[2] || es_mul_div_op[3]) ? m_axis_dout_tvalid || ws_cancel_es
                          : (tlb_op[4]) ? (~ms_tlbsrch_revised || ~ws_tlbsrch_revised || ws_cancel_es)
                          : 1'b1;
	assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
	assign es_to_ms_valid =  es_valid && es_ready_go && !ws_cancel_es;
	always @(posedge clk)
	begin
	    if (reset)
	    begin
	        es_valid <= 1'b0;
	    end
	    else if (es_allowin)
		begin 
	        es_valid <= ds_to_es_valid;
	    end
	
	    if (ds_to_es_valid && es_allowin)
		begin
	        ds_to_es_bus_r <= ds_to_es_bus;
	    end
	end
	
	assign es_alu_src1 = es_src1_is_pc  ? es_pc[31:0] : 
	                                      es_rj_value;

	assign es_alu_src2 = es_src2_is_imm ? es_imm : 
	                                      es_rkd_value;

	alu u_alu(
	    .alu_op     (es_alu_op    ),
	    .alu_src1   (es_alu_src1  ),
	    .alu_src2   (es_alu_src2  ),
	    .alu_result (es_alu_result)
	    );

	assign op_st_b         = es_mem_we & es_op_b;
	assign op_st_h         = es_mem_we & es_op_h;
	assign op_st_w         = es_mem_we & es_op_w;
	assign last_two        = es_alu_result[1:0];
	
    // data sram
    always @(posedge clk) 
    begin
        if (reset) 
        begin
            es_addr_ok <= 1'b0;
        end
        else if (data_sram_req && data_sram_addr_ok) 
        begin
            es_addr_ok <= 1'b0;
        end
        else if ((es_mem_we || es_res_from_mem) && es_valid && ms_allowin) 
        begin
            es_addr_ok <= 1'b1;
        end
    end
    
	assign es_sram_wstrb = op_st_b ? (last_two==2'b00 ? 4'b0001:
	                                  last_two==2'b01 ? 4'b0010:
	                                  last_two==2'b10 ? 4'b0100:
	                                                    4'b1000):
	                       op_st_h ? (last_two==2'b00 ? 4'b0011 :
	                                                    4'b1100):
	                       4'b1111;

    assign data_sram_req   = es_addr_ok && es_mem_valid;
	assign data_sram_wstrb = es_store_valid  ? es_sram_wstrb : 4'b0000;
    assign data_sram_wr    = |data_sram_wstrb;
    assign wstrb_bits      = data_sram_wstrb[0] + data_sram_wstrb[1] + data_sram_wstrb[2] + data_sram_wstrb[3];
	assign data_sram_size  = wstrb_bits == 3'h1 ? 2'h0
	                       : wstrb_bits == 3'h2 ? 2'h1
	                       : 2'h2;
	assign data_sram_addr  = es_alu_result;
	assign data_sram_wdata = es_op_b ? {4{es_rkd_value[ 7:0]}}:
	                         es_op_h ? {2{es_rkd_value[15:0]}}:
	                                      es_rkd_value[31:0];

	// forward module
	wire   forward_es_valid;
	wire   block_es_valid;
	assign forward_es_valid     = (es_dest == 5'b0 ? 1'b0 : es_gr_we) && es_valid;
	assign block_es_valid       = (es_load_valid | csr_re) & es_valid;
	assign forward_es_to_ds_bus = {block_es_valid   ,   //38:38
	                               es_result        ,   //37:6
	                               forward_es_valid ,   //5:5
	                               es_dest              //4:0
	                               };

    wire   ws_tlbsrch_revised;
    wire   ms_tlbsrch_revised;
	assign {ws_tlbsrch_revised, ws_cancel_es} = ws_to_es_bus;
	assign {ms_tlbsrch_revised, ms_cancel_es} = ms_to_es_bus;

    //exception
	assign maddr_unalign = es_op_w & (last_two[1] | last_two[0]) | es_op_h & last_two[0] & (es_res_from_mem | es_mem_we);
	assign store_error   = maddr_unalign & es_mem_we;
	assign load_error    = maddr_unalign & es_res_from_mem;
	assign es_addr_error = store_error | load_error;
	
	assign es_load_valid = es_res_from_mem & !ws_cancel_es & !ms_cancel_es & !load_error;
	assign es_store_valid= es_mem_we       & !ws_cancel_es & !ms_cancel_es & !store_error;
	
	assign es_ex         = (ds_ex | es_addr_error) & es_valid;
	assign es_ecode      = ds_ex ? ds_ecode:
						   es_addr_error ? `ECODE_ALE:
						   `ECODE_UNKNOWN;
	assign es_esubcode	 = ds_ex ? ds_esubcode:`ESUBCODE_UNKNOWN;
	assign es_vaddr		 = es_alu_result;

    wire [`TLB_ASID_WD-1:0] invtlb_asid;
    wire [`TLB_VPPN_WD-1:0] invtlb_vppn;
    //wire [`TLB_VPPN_WD-1:0] invtlb_va;

    assign invtlb_asid   = es_rj_value [ 9: 0];
    assign invtlb_vppn   = es_rkd_value[31:13];

    assign tlbsrch_valid = tlb_op[4] & es_valid & ~ms_tlbsrch_revised & ~ws_tlbsrch_revised & ~ws_cancel_es & ~ms_cancel_es;
    assign s1_vppn       = tlb_op[4] ? csr_tlbehi_vppn :
                           tlb_op[0] ? invtlb_vppn :
                           es_vaddr[`CSR_TLBEHI_VPPN];
    assign s1_va_bit12   = es_vaddr[12];
    //NOTE: for INVTLB, bit 12 is not necessary
    assign s1_asid       = tlb_op[0] ? invtlb_asid : csr_asid_asid;

    assign invtlb_valid  = tlb_op[0] & es_valid & ~ws_cancel_es & ~ms_cancel_es;

endmodule
