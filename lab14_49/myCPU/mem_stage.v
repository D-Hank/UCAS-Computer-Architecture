`include "mycpu.h"

module mem_stage(
    input                          clk                 ,
    input                          reset               ,
    //allowin
    input                          ws_allowin          ,
    output                         ms_allowin          ,
    //from es
    input                          es_to_ms_valid      ,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus        ,
    //to ws
    output                         ms_to_ws_valid      ,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus        ,
    // data sram interface
    input                          data_sram_data_ok   ,
    input  [31                 :0] data_sram_rdata     ,
    //forward: to ds
    output [`FORWARD_MS_TO_DS-1:0] forward_ms_to_ds_bus,
    //from ws
    input  [`WS_TO_MS_BUS_WD -1:0] ws_to_ms_bus        ,
    //to es
    output [`MS_TO_ES_BUS_WD -1:0] ms_to_es_bus
);

	reg         ms_valid;
	wire        ms_ready_go;
	wire        ws_cancel_ms;
	wire        ms_cancel_es;
    wire        tlbsrch_revised;
	assign      ws_cancel_ms = ws_to_ms_bus;
	assign      ms_to_es_bus = {tlbsrch_revised & ms_valid, ms_cancel_es};
	
	reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
	wire [ 1:0] ms_last_two;
	wire        ms_load_sign;
	wire        ms_op_b;
	wire        ms_op_h;
	wire        ms_gr_we;
	wire [ 4:0] ms_dest;
	wire [31:0] ms_alu_result;
	wire [31:0] ms_pc;

	wire        ms_load_valid;
	wire        ms_store_valid;
	wire        csr_re;
	wire        csr_we;
	wire [31:0] csr_wmask;
	wire [13:0] csr_num;
	wire [ 8:0] es_esubcode;
	wire [ 5:0] es_ecode;
	wire        es_ex;
	wire [31:0] es_vaddr;
	wire [ 8:0] ms_esubcode;
	wire [ 5:0] ms_ecode;
	wire        ms_ex;
	wire [31:0] ms_vaddr;
	wire        inst_ertn;
    wire [ 4:0] tlb_op;
    wire [31:0] remap_vpc;
    wire        memmap_revised;
	
	assign {remap_vpc      ,  //212:181
            memmap_revised ,  //180:180
            tlbsrch_revised,  //179:179
            tlb_op         ,  //178:174
			ms_store_valid ,  //173:173
	        csr_re         ,  //172:172
	        csr_we         ,  //171:171
	        csr_wmask      ,  //170:159
	        csr_num        ,  //158:125
			es_vaddr	   ,  //124:93
	        es_esubcode    ,  //92:84
	        es_ecode       ,  //83:78
	        es_ex     	   ,  //77:77
	        inst_ertn      ,  //76:76
	        ms_last_two    ,  //75:74
	        ms_load_sign   ,  //73:73
	        ms_op_b        ,  //72:72
	        ms_op_h        ,  //71:71
	        ms_load_valid  ,  //70:70
	        ms_gr_we       ,  //69:69
	        ms_dest        ,  //68:64
	        ms_alu_result  ,  //63:32
	        ms_pc             //31:0
	       } = es_to_ms_bus_r;
	
	wire [31:0] mem_result;
	wire [31:0] ms_final_result;
	wire [ 7:0] ms_byte;
	wire [15:0] ms_half;

	assign ms_to_ws_bus = {remap_vpc      ,  //205:174
                           memmap_revised ,  //173:173
                           tlbsrch_revised,  //172:172
                           tlb_op         ,  //171:167
                           csr_re         ,  //166:166
	                       csr_we         ,  //165:165
	                       csr_wmask      ,  //164:133
	                       csr_num        ,  //132:119
						   ms_vaddr		  ,  //118:87
	                       ms_esubcode    ,  //86:78
	                       ms_ecode       ,  //77:72
	                       ms_ex          ,  //71:71
	                       inst_ertn      ,  //70:70
	                       ms_gr_we       ,  //69:69
	                       ms_dest        ,  //68:64
	                       ms_final_result,  //63:32
	                       ms_pc             //31:0
	                      };
	assign ms_cancel_es   = (ms_ex | inst_ertn | memmap_revised) & ms_valid;
	assign ms_ready_go    = (ms_load_valid || ms_store_valid) && ms_valid ? data_sram_data_ok : 1'b1;
	assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
	assign ms_to_ws_valid = ms_valid && ms_ready_go && !ws_cancel_ms;
	always @(posedge clk)
	begin
	    if (reset)
	    begin
	        ms_valid <= 1'b0;
	    end
	    else if (ms_allowin)
	    begin
	        ms_valid <= es_to_ms_valid;
	    end
	
	    if (es_to_ms_valid && ms_allowin)
		begin
	        es_to_ms_bus_r  <= es_to_ms_bus;
	    end
	end
	
	assign ms_byte    = (ms_last_two==2'b00) ? data_sram_rdata[ 7: 0] :
	                    (ms_last_two==2'b01) ? data_sram_rdata[15: 8] :
	                    (ms_last_two==2'b10) ? data_sram_rdata[23:16] :
	                    data_sram_rdata[31:24];
	
	assign ms_half    = (ms_last_two==2'b00) ? data_sram_rdata[15: 0] : data_sram_rdata[31:16];
	
	assign mem_result = ms_op_b ? {{24{ms_byte[ 7] & ms_load_sign}},ms_byte}:
	                    ms_op_h ? {{16{ms_half[15] & ms_load_sign}},ms_half}:
	                    data_sram_rdata;
	
	assign ms_final_result = ms_load_valid ? mem_result
	                                       : ms_alu_result;
    
	// forward module
	wire   forward_ms_valid;
	wire   block_ms_valid;
	assign forward_ms_valid     = (ms_dest == 5'b0 ? 1'b0 : ms_gr_we) && ms_valid;
	assign block_ms_valid       = (csr_re || ms_load_valid) && ms_valid;
	assign forward_ms_to_ds_bus = {block_ms_valid   ,   //38:38
	                               ms_final_result  ,   //37:6
	                               forward_ms_valid ,   //5:5
	                               ms_dest              //4:0
	                               };

    //exception
	assign ms_ecode    = es_ecode;
	assign ms_esubcode = es_esubcode;
	assign ms_ex 	   = es_ex & ms_valid;
	assign ms_vaddr	   = es_vaddr;

endmodule
