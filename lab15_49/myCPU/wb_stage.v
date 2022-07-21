`include "mycpu.h"

module wb_stage(
    input                           clk                 ,
    input                           reset               ,
    // allowin
    output                          ws_allowin          ,
    // from ms
    input                           ms_to_ws_valid      ,
    input  [`MS_TO_WS_BUS_WD -1 :0] ms_to_ws_bus        ,
    input  [31                  :0] mem_result          ,
    // to rf: for write back
    output [`WS_TO_RF_BUS_WD  -1:0] ws_to_rf_bus        ,
    // trace debug interface
    output [31                  :0] debug_wb_pc         ,
    output [ 3                  :0] debug_wb_rf_wen     ,
    output [ 4                  :0] debug_wb_rf_wnum    ,
    output [31                  :0] debug_wb_rf_wdata   ,
    // forward: to ds
    output [`FORWARD_WS_TO_DS -1:0] forward_ws_to_ds_bus,
    // reflush
    output [`WS_TO_FS_BUS_WD  -1:0] ws_to_fs_bus        ,
    output [`WS_TO_DS_BUS_WD  -1:0] ws_to_ds_bus        ,
    output [`WS_TO_ES_BUS_WD  -1:0] ws_to_es_bus        ,
    output [`WS_TO_MS_BUS_WD  -1:0] ws_to_ms_bus        ,
    // search port 1
    input                           tlbsrch_done        ,
    input                           s1_found            ,
    input  [`TLB_LOG_NUM      -1:0] s1_index            ,
    // write port
    output                          tlbwr_valid         ,
    output                          tlbfill_valid       ,
    output [`TLB_LOG_NUM      -1:0] w_index             ,
    output                          w_e                 ,
    output [`TLB_VPPN_WD      -1:0] w_vppn              ,
    output [`TLB_PS_WD        -1:0] w_ps                ,
    output [`TLB_ASID_WD      -1:0] w_asid              ,
    output                          w_g                 ,
    output [`TLB_PPN_WD       -1:0] w_ppn0              ,
    output [`TLB_PLV_WD       -1:0] w_plv0              ,
    output [`TLB_MAT_WD       -1:0] w_mat0              ,
    output                          w_d0                ,
    output                          w_v0                ,
    output [`TLB_PPN_WD       -1:0] w_ppn1              ,
    output [`TLB_PLV_WD       -1:0] w_plv1              ,
    output [`TLB_MAT_WD       -1:0] w_mat1              ,
    output                          w_d1                ,
    output                          w_v1                ,

    // read port
    output                          tlbrd_valid         ,
    input                           tlbrd_done          ,
    output [`TLB_LOG_NUM      -1:0] r_index             ,
    input                           r_e                 ,
    input  [`TLB_VPPN_WD      -1:0] r_vppn              ,
    input  [`TLB_PS_WD        -1:0] r_ps                ,
    input  [`TLB_ASID_WD      -1:0] r_asid              ,
    input                           r_g                 ,
    input  [`TLB_PPN_WD       -1:0] r_ppn0              ,
    input  [`TLB_PLV_WD       -1:0] r_plv0              ,
    input  [`TLB_MAT_WD       -1:0] r_mat0              ,
    input                           r_d0                ,
    input                           r_v0                ,
    input  [`TLB_PPN_WD       -1:0] r_ppn1              ,
    input  [`TLB_PLV_WD       -1:0] r_plv1              ,
    input  [`TLB_MAT_WD       -1:0] r_mat1              ,
    input                           r_d1                ,
    input                           r_v1                
);

    reg         ws_valid;
	wire        ws_ready_go;
	
	reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
	wire        ms_data_start;
	wire        csr_re;
	wire        csr_we;
	wire [31:0] csr_wmask;
	wire [13:0] csr_num;
    wire [ 4:0] tlb_op;
    wire        tlbsrch_revised;
    wire [31:0] remap_vpc;
    wire        memmap_revised;
	wire [ 8:0] wb_esubcode;
	wire [ 5:0] wb_ecode;
	wire        wb_ex;
	wire   		wb_ertn;
	wire [31:0] wb_vaddr;
    wire        ws_cancel;
	wire        ms_ex;
	wire [ 8:0] ms_esubcode;
	wire [ 5:0] ms_ecode;
	wire [31:0] ms_vaddr;
	wire        inst_ertn;
	wire        has_int;
	wire        ws_gr_we;
	wire [ 4:0] ws_dest;
	wire [31:0] ws_final_result;
	wire [31:0] ws_pc;

	assign {remap_vpc      ,  //205:174
            memmap_revised ,  //173:173
            tlbsrch_revised,  //172:172
            tlb_op         ,  //171:167
            csr_re         ,  //166:166
	        csr_we         ,  //165:165
	        csr_wmask      ,  //164:133
	        csr_num        ,  //132:119
			ms_vaddr	   ,  //118:87
	        ms_esubcode    ,  //86:78
	        ms_ecode       ,  //77:72
	        ms_ex          ,  //71:71
	        inst_ertn      ,  //70:70
	        ws_gr_we       ,  //69:69
	        ws_dest        ,  //68:64
	        ws_final_result,  //63:32
	        ws_pc             //31:0
	       } = ms_to_ws_bus_r;

	wire        rf_we;
	wire [4 :0] rf_waddr;
	wire [31:0] rf_wdata;
	assign ws_to_rf_bus = {rf_we   ,  //37:37
	                       rf_waddr,  //36:32
	                       rf_wdata   //31:0
	                      };
	
	assign ws_ready_go = 1'b1;
	assign ws_allowin  = !ws_valid || ws_ready_go ;
	always @(posedge clk)
	begin
	    if (reset)
		begin
			ws_valid <= 1'b0;
		end
	    else if (ws_allowin)
		begin
	        ws_valid <= ms_to_ws_valid;
	    end
	
	    if (ms_to_ws_valid && ws_allowin)
		begin
	        ms_to_ws_bus_r <= ms_to_ws_bus;
	    end
	end
	
	//csr module
	wire [ 7:0] hw_int_in; 
	wire        ipi_int_in; 
	wire        ertn_flush;
	wire [31:0] ex_entry;
    wire [31:0] tlb_entry;
	wire [31:0] csr_rvalue;
	wire [31:0] csr_wvalue;
    wire [`TLB_TO_CSR_BUS_WD -1:0] tlb_to_csr_bus;
    wire [`CSR_TO_TLB_BUS_WD -1:0] csr_to_tlb_bus;

	assign hw_int_in  = 8'b0;
	assign ipi_int_in = 1'b0;
	assign ertn_flush = inst_ertn;
	assign csr_wvalue = ws_final_result;
    assign tlb_to_csr_bus = {tlbsrch_done,  //104:104
                             s1_index    ,  //103:100
                             ~s1_found   ,  //99:99
                             tlbrd_done  ,  //98:98
                             r_vppn      ,  //97:79
                             r_v0        ,  //78:78
                             r_d0        ,  //77:77
                             r_plv0      ,  //76:75
                             r_mat0      ,  //74:73
                             r_g         ,  //72:72
                             r_ppn0      ,  //71:48
                             r_v1        ,  //47:47
                             r_d1        ,  //46:46
                             r_plv1      ,  //45:44
                             r_mat1      ,  //43:42
                             r_g         ,  //41:41
                             r_ppn1      ,  //40:17
                             r_asid      ,  //16:7
                             r_ps        ,  //6:1
                             ~r_e           //0:0
                             };
	
    wire [`ECODE_WD   -1:0] csr_estat_ecode;
    wire [`CSR_TLBIDX_IDX ] csr_tlbidx_idx;
    wire [`CSR_TLBIDX_PS  ] csr_tlbidx_ps;
    wire [`CSR_TLBIDX_NE  ] csr_tlbidx_ne;
    wire [`CSR_TLBEHI_VPPN] csr_tlbehi_vppn;
    wire [`CSR_TLBELO0_V  ] csr_tlbelo0_v;
    wire [`CSR_TLBELO0_D  ] csr_tlbelo0_d;
    wire [`CSR_TLBELO0_PLV] csr_tlbelo0_plv;
    wire [`CSR_TLBELO0_MAT] csr_tlbelo0_mat;
    wire [`CSR_TLBELO0_G  ] csr_tlbelo0_g;
    wire [`CSR_TLBELO0_PPN] csr_tlbelo0_ppn;
    wire [`CSR_TLBELO1_V  ] csr_tlbelo1_v;
    wire [`CSR_TLBELO1_D  ] csr_tlbelo1_d;
    wire [`CSR_TLBELO1_PLV] csr_tlbelo1_plv;
    wire [`CSR_TLBELO1_MAT] csr_tlbelo1_mat;
    wire [`CSR_TLBELO1_G  ] csr_tlbelo1_g;
    wire [`CSR_TLBELO1_PPN] csr_tlbelo1_ppn;
    wire [`CSR_ASID_ASID  ] csr_asid_asid;

    wire [31                  :0] csr_crmd;
    wire [31                  :0] csr_asid;
    wire [31                  :0] csr_dmw0;
    wire [31                  :0] csr_dmw1;
    wire [31                  :0] entry;
    wire [`CSR_TO_EXE_BUS_WD-1:0] csr_to_exe_bus;

    assign {csr_estat_ecode,    //107:102
            csr_tlbidx_idx ,    //101:98
            csr_tlbidx_ps  ,    //97:92
            csr_tlbidx_ne  ,    //91:91
            csr_tlbehi_vppn,    //90:72
            csr_tlbelo0_v  ,    //71:71
            csr_tlbelo0_d  ,    //70:70
            csr_tlbelo0_plv,    //69:68
            csr_tlbelo0_mat,    //67:66
            csr_tlbelo0_g  ,    //65:65
            csr_tlbelo0_ppn,    //64:41
            csr_tlbelo1_v  ,    //40:40
            csr_tlbelo1_d  ,    //39:39
            csr_tlbelo1_plv,    //38:37
            csr_tlbelo1_mat,    //36:35
            csr_tlbelo1_g  ,    //34:34
            csr_tlbelo1_ppn,    //33:10
            csr_asid_asid       //9:0
            } = csr_to_tlb_bus;

    assign tlbwr_valid   = tlb_op[2];
    assign tlbfill_valid = tlb_op[3];
    assign w_index       = csr_tlbidx_idx;
    assign w_e           = (csr_estat_ecode ==`ECODE_TLBR) ? 1'b1 : ~csr_tlbidx_ne;
    assign w_vppn        = csr_tlbehi_vppn;
    assign w_ps          = csr_tlbidx_ps;
    assign w_asid        = csr_asid_asid;
    assign w_g           = csr_tlbelo0_g & csr_tlbelo1_g;
    assign w_ppn0        = csr_tlbelo0_ppn;
    assign w_plv0        = csr_tlbelo0_plv;
    assign w_mat0        = csr_tlbelo0_mat;
    assign w_d0          = csr_tlbelo0_d;
    assign w_v0          = csr_tlbelo0_v;
    assign w_ppn1        = csr_tlbelo1_ppn;
    assign w_plv1        = csr_tlbelo1_plv;
    assign w_mat1        = csr_tlbelo1_mat;
    assign w_d1          = csr_tlbelo1_d;
    assign w_v1          = csr_tlbelo1_v;

    assign tlbrd_valid   = tlb_op[1];
    assign r_index       = csr_tlbidx_idx;

	csr u_csr(
	    .clock          (clk               ),
	    .reset          (reset             ),
	    .csr_we         (csr_we && ws_valid),
	    .csr_num        (csr_num           ),
	    .csr_wmask      (csr_wmask         ),
	    .csr_wvalue     (csr_wvalue        ),
	    .csr_rvalue     (csr_rvalue        ),
	    .wb_ex          (wb_ex             ),
	    .wb_ecode       (wb_ecode          ),
	    .wb_esubcode    (wb_esubcode       ),
	    .wb_pc          (ws_pc             ),
		.wb_vaddr	    (wb_vaddr          ),
	    .hw_int_in      (hw_int_in         ), 
	    .ipi_int_in     (ipi_int_in        ),
	    .ertn_flush     (ertn_flush        ),
		.has_int	    (has_int           ),
	    .ex_entry       (ex_entry          ),
        .tlb_entry      (tlb_entry         ),
        .we             (tlb_op[1]         ),
        .tlb_to_csr_bus (tlb_to_csr_bus    ),
        .csr_crmd_rvalue(csr_crmd          ),   
        .csr_asid_rvalue(csr_asid          ),   
        .csr_dmw0_rvalue(csr_dmw0          ),   
        .csr_dmw1_rvalue(csr_dmw1          ),
        .csr_to_exe_bus (csr_to_exe_bus    ),
        .csr_to_tlb_bus (csr_to_tlb_bus    )
	    );

	assign wb_ertn = inst_ertn & ws_valid;
    assign entry   = wb_ecode == `ECODE_TLBR ? tlb_entry : ex_entry;
	assign ws_to_fs_bus = {csr_crmd                 ,  //226:195
                           csr_asid                 ,  //194:132
                           csr_dmw0                 ,  //162:131
                           csr_dmw1                 ,  //130:99
                           memmap_revised & ws_valid,  //98:98
                           remap_vpc                ,  //97:66
	                       wb_ex                    ,  //65:65
	                       entry                    ,  //64:33
	                       wb_ertn                  ,  //32:32
	                       csr_rvalue                  //31:0
	                      };

	assign ws_cancel    = wb_ex | wb_ertn | memmap_revised & ws_valid;
	assign ws_to_ds_bus = {ws_cancel, has_int};

    assign ws_to_es_bus = {csr_crmd                  ,  //149:118
                           csr_asid                  ,  //117:86
                           csr_dmw0                  ,  //85:54
                           csr_dmw1                  ,  //53:22
                           csr_to_exe_bus            ,  //21:3
                           memmap_revised  & ws_valid,  //2:2
                           tlbsrch_revised & ws_valid,  //1:1
                           ws_cancel                    //0:0
                          };

    assign ws_to_ms_bus = ws_cancel;

	assign rf_we    = ws_gr_we && ws_valid && ~wb_ex;
	assign rf_waddr = ws_dest;
	assign rf_wdata = csr_re ? csr_rvalue : ws_final_result;

	// debug info generate
	assign debug_wb_pc       = ws_pc;
	assign debug_wb_rf_wen   = {4{rf_we}};
	assign debug_wb_rf_wnum  = ws_dest;
	assign debug_wb_rf_wdata = rf_wdata;

	// forward module
	wire        forward_ws_valid;
	wire [31:0] forward_ws_data;
	assign forward_ws_valid     = (ws_dest == 5'b0 ? 1'b0 : ws_gr_we) && ws_valid;
	assign forward_ws_data      = csr_re ? csr_rvalue : ws_final_result;
	assign forward_ws_to_ds_bus = {forward_ws_data   ,  //37:6
	                               forward_ws_valid  ,  //5:5
	                               ws_dest              //4:0
	                              };

	assign wb_ex       = (ms_ex | has_int) & ws_valid;
	assign wb_ecode    = ms_ecode;
	assign wb_esubcode = ms_esubcode;
	assign wb_vaddr	   = ms_vaddr;

endmodule