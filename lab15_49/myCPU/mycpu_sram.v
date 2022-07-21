module mycpu_sram(
    input         clk              ,
    input         resetn           ,
    // inst sram interface
    output        inst_sram_req    ,
    output        inst_sram_wr     ,
    output [ 1:0] inst_sram_size   ,
    output [31:0] inst_sram_addr   ,
    output [ 3:0] inst_sram_wstrb  ,
    output [31:0] inst_sram_wdata  ,
    input         inst_sram_addr_ok,
    input         inst_sram_data_ok,
    input  [31:0] inst_sram_rdata  ,
    // data sram interface
    output        data_sram_req    ,
    output        data_sram_wr     ,
    output [ 1:0] data_sram_size   ,
    output [31:0] data_sram_addr   ,
    output [ 3:0] data_sram_wstrb  ,
    output [31:0] data_sram_wdata  ,
    input         data_sram_addr_ok,
    input         data_sram_data_ok,
    input  [31:0] data_sram_rdata  ,
    // trace debug interface
    output [31:0] debug_wb_pc      ,
    output [ 3:0] debug_wb_rf_wen  ,
    output [ 4:0] debug_wb_rf_wnum ,
    output [31:0] debug_wb_rf_wdata
);

    reg                           reset;
	
	always @(posedge clk)
	begin
	    reset <= ~resetn; 
	end

	wire                          ds_allowin;
	wire                          es_allowin;
	wire                          ms_allowin;
	wire                          ws_allowin;
	wire                          fs_to_ds_valid;
	wire                          ds_to_es_valid;
	wire                          es_to_ms_valid;
	wire                          ms_to_ws_valid;
	
	wire [`FS_TO_DS_BUS_WD  -1:0] fs_to_ds_bus;
	wire [`DS_TO_ES_BUS_WD  -1:0] ds_to_es_bus;
	wire [`BR_BUS_WD        -1:0] br_bus;
	wire [`ES_TO_MS_BUS_WD  -1:0] es_to_ms_bus;
	
	wire [`MS_TO_ES_BUS_WD  -1:0] ms_to_es_bus;
	wire [`MS_TO_WS_BUS_WD  -1:0] ms_to_ws_bus;
	
	wire [`WS_TO_RF_BUS_WD  -1:0] ws_to_rf_bus;
	wire [`WS_TO_FS_BUS_WD  -1:0] ws_to_fs_bus;
	wire [`WS_TO_DS_BUS_WD  -1:0] ws_to_ds_bus;
	
	wire [`FORWARD_ES_TO_DS -1:0] forward_es_to_ds_bus;
	wire [`FORWARD_MS_TO_DS -1:0] forward_ms_to_ds_bus;
	wire [`FORWARD_WS_TO_DS -1:0] forward_ws_to_ds_bus;
	
    wire [`WS_TO_ES_BUS_WD  -1:0] ws_to_es_bus;
    wire [`WS_TO_MS_BUS_WD  -1:0] ws_to_ms_bus;

    // tlb interface
    // search port 0 (for fetch)
    wire [`TLB_VPPN_WD      -1:0] s0_vppn;
    wire                          s0_va_bit12;
    wire [`TLB_ASID_WD      -1:0] s0_asid;
    wire                          s0_found;
    wire [`TLB_LOG_NUM      -1:0] s0_index;
    wire [`TLB_PPN_WD       -1:0] s0_ppn;
    wire [`TLB_PS_WD        -1:0] s0_ps;
    wire [`TLB_PLV_WD       -1:0] s0_plv;
    wire [`TLB_MAT_WD       -1:0] s0_mat;
    wire                          s0_d;
    wire                          s0_v;

    // search port 1 (for load/store)
    wire                          tlbsrch_valid;
    wire                          tlbsrch_done;
    wire [`TLB_VPPN_WD      -1:0] s1_vppn;
    wire                          s1_va_bit12;  
    wire [`TLB_ASID_WD      -1:0] s1_asid;
    wire                          s1_found;
    wire [`TLB_LOG_NUM      -1:0] s1_index;
    wire [`TLB_PPN_WD       -1:0] s1_ppn;
    wire [`TLB_PS_WD        -1:0] s1_ps;
    wire [`TLB_PLV_WD       -1:0] s1_plv;
    wire [`TLB_MAT_WD       -1:0] s1_mat;
    wire                          s1_d;
    wire                          s1_v;

    // invtlb opcode
    wire                          invtlb_valid;
    wire [`TLB_INV_OP_WD    -1:0] invtlb_op;

    // write port
    wire                          tlbwr_valid;
    wire                          tlbfill_valid;
    wire [`TLB_LOG_NUM      -1:0] w_index;
    wire                          w_e;
    wire [`TLB_VPPN_WD      -1:0] w_vppn;
    wire [`TLB_PS_WD        -1:0] w_ps;
    wire [`TLB_ASID_WD      -1:0] w_asid;
    wire                          w_g;
    wire [`TLB_PPN_WD       -1:0] w_ppn0;
    wire [`TLB_PLV_WD       -1:0] w_plv0;
    wire [`TLB_MAT_WD       -1:0] w_mat0;
    wire                          w_d0;
    wire                          w_v0;
    wire [`TLB_PPN_WD       -1:0] w_ppn1;
    wire [`TLB_PLV_WD       -1:0] w_plv1;
    wire [`TLB_MAT_WD       -1:0] w_mat1;
    wire                          w_d1;
    wire                          w_v1;

    // read port
    wire                          tlbrd_valid;
    wire                          tlbrd_done;
    wire [`TLB_LOG_NUM      -1:0] r_index;
    wire                          r_e;
    wire [`TLB_VPPN_WD      -1:0] r_vppn;
    wire [`TLB_PS_WD        -1:0] r_ps;
    wire [`TLB_ASID_WD      -1:0] r_asid;
    wire                          r_g;
    wire [`TLB_PPN_WD       -1:0] r_ppn0;
    wire [`TLB_PLV_WD       -1:0] r_plv0;
    wire [`TLB_MAT_WD       -1:0] r_mat0;
    wire                          r_d0;
    wire                          r_v0;
    wire [`TLB_PPN_WD       -1:0] r_ppn1;
    wire [`TLB_PLV_WD       -1:0] r_plv1;
    wire [`TLB_MAT_WD       -1:0] r_mat1;
    wire                          r_d1;
    wire                          r_v1;

    wire [`TLB_TO_CSR_BUS_WD-1:0] tlb_to_csr_bus;

	// IF stage
	if_stage if_stage(
	    .clk              (clk               ),
	    .reset            (reset             ),
	    //allowin
	    .ds_allowin       (ds_allowin        ),
	    //brbus
	    .br_bus           (br_bus            ),
	    //outputs
	    .fs_to_ds_valid   (fs_to_ds_valid    ),
	    .fs_to_ds_bus     (fs_to_ds_bus      ),
	    // inst sram interface
        .inst_sram_req    (inst_sram_req     ),
        .inst_sram_wr     (inst_sram_wr      ),
        .inst_sram_size   (inst_sram_size    ),
        .inst_sram_addr   (inst_sram_addr    ),
        .inst_sram_wstrb  (inst_sram_wstrb   ),
        .inst_sram_wdata  (inst_sram_wdata   ),
        .inst_sram_addr_ok(inst_sram_addr_ok ),
        .inst_sram_data_ok(inst_sram_data_ok ),
        .inst_sram_rdata  (inst_sram_rdata   ),
	    //from ws
	    .ws_to_fs_bus     (ws_to_fs_bus      ),
        .s0_vppn          (s0_vppn           ),
        .s0_va_bit12      (s0_va_bit12       ),
        .s0_asid          (s0_asid           ),
        .s0_found         (s0_found          ),
        .s0_index         (s0_index          ),
        .s0_ppn           (s0_ppn            ),
        .s0_ps            (s0_ps             ),
        .s0_plv           (s0_plv            ),
        .s0_mat           (s0_mat            ),
        .s0_d             (s0_d              ),
        .s0_v             (s0_v              )
	);
	
	// ID stage
	id_stage id_stage(
	    .clk                 (clk                      ),
	    .reset               (reset                    ),
	    // allowin
	    .es_allowin          (es_allowin               ),
	    .ds_allowin          (ds_allowin               ),
	    // from fs
	    .fs_to_ds_valid      (fs_to_ds_valid           ),
	    .fs_to_ds_bus        (fs_to_ds_bus             ),
	    // to es
	    .ds_to_es_valid      (ds_to_es_valid           ),
	    .ds_to_es_bus        (ds_to_es_bus             ),
	    // to fs
	    .br_bus              (br_bus                   ),
	    // to rf: for write back
	    .ws_to_rf_bus        (ws_to_rf_bus             ),
	    // forward: from es,ms,ws
	    .forward_es_to_ds_bus(forward_es_to_ds_bus     ),
	    .forward_ms_to_ds_bus(forward_ms_to_ds_bus     ),
	    .forward_ws_to_ds_bus(forward_ws_to_ds_bus     ),
	    // from ws
	    .ws_to_ds_bus        (ws_to_ds_bus             )
	);
	
	// EXE stage
	exe_stage exe_stage(
	    .clk                 (clk                      ),
	    .reset               (reset                    ),
	    //allowin
	    .ms_allowin          (ms_allowin               ),
	    .es_allowin          (es_allowin               ),
	    //from ds
	    .ds_to_es_valid      (ds_to_es_valid           ),
	    .ds_to_es_bus        (ds_to_es_bus             ),
	    //to ms
	    .es_to_ms_valid      (es_to_ms_valid           ),
	    .es_to_ms_bus        (es_to_ms_bus             ),
	    // data sram interface
        .data_sram_req       (data_sram_req            ),
        .data_sram_wr        (data_sram_wr             ),
        .data_sram_size      (data_sram_size           ),
        .data_sram_addr      (data_sram_addr           ),
        .data_sram_wstrb     (data_sram_wstrb          ),
        .data_sram_wdata     (data_sram_wdata          ),
        .data_sram_addr_ok   (data_sram_addr_ok        ),
	    //forward: to ds
	    .forward_es_to_ds_bus(forward_es_to_ds_bus     ),
	    //from ws
	    .ws_to_es_bus        (ws_to_es_bus             ),
	    //from ms
	    .ms_to_es_bus        (ms_to_es_bus             ),
        // tlb interface
        // search port 1
        .tlbsrch_valid       (tlbsrch_valid            ),
        .s1_vppn             (s1_vppn                  ),
        .s1_va_bit12         (s1_va_bit12              ),
        .s1_asid             (s1_asid                  ),
        .s1_found            (s1_found                 ),
        .s1_index            (s1_index                 ),
        .s1_ppn              (s1_ppn                   ),
        .s1_ps               (s1_ps                    ),
        .s1_plv              (s1_plv                   ),
        .s1_mat              (s1_mat                   ),
        .s1_d                (s1_d                     ),
        .s1_v                (s1_v                     ),
        // invtlb
        .invtlb_valid        (invtlb_valid             ),
        .invtlb_op           (invtlb_op                )
	);

	// MEM stage
	mem_stage mem_stage(
	    .clk                 (clk                      ),
	    .reset               (reset                    ),
	    // allowin
	    .ws_allowin          (ws_allowin               ),
	    .ms_allowin          (ms_allowin               ),
	    // from es
	    .es_to_ms_valid      (es_to_ms_valid           ),
	    .es_to_ms_bus        (es_to_ms_bus             ),
	    // to ws
	    .ms_to_ws_valid      (ms_to_ws_valid           ),
	    .ms_to_ws_bus        (ms_to_ws_bus             ),
	    // data sram interface
	    .data_sram_data_ok   (data_sram_data_ok        ),
	    .data_sram_rdata     (data_sram_rdata          ),
	    // forward: to ds
	    .forward_ms_to_ds_bus(forward_ms_to_ds_bus     ),
	    // from ws
	    .ws_to_ms_bus        (ws_to_ms_bus             ),
	    // to es
	    .ms_to_es_bus        (ms_to_es_bus             )
	);

	// WB stage
	wb_stage wb_stage(
	    .clk                 (clk                 ),
	    .reset               (reset               ),
	    // allowin
	    .ws_allowin          (ws_allowin          ),
	    // from ms
	    .ms_to_ws_valid      (ms_to_ws_valid      ),
	    .ms_to_ws_bus        (ms_to_ws_bus        ),
	    // to rf: for write back
	    .ws_to_rf_bus        (ws_to_rf_bus        ),
	    // trace debug interface
	    .debug_wb_pc         (debug_wb_pc         ),
	    .debug_wb_rf_wen     (debug_wb_rf_wen     ),
	    .debug_wb_rf_wnum    (debug_wb_rf_wnum    ),
	    .debug_wb_rf_wdata   (debug_wb_rf_wdata   ),
	    // forward: to ds
	    .forward_ws_to_ds_bus(forward_ws_to_ds_bus),
	    // reflush
	    .ws_to_fs_bus        (ws_to_fs_bus        ),
	    .ws_to_ds_bus        (ws_to_ds_bus        ),
        .ws_to_es_bus        (ws_to_es_bus        ),
        .ws_to_ms_bus        (ws_to_ms_bus        ),

        .tlbsrch_done        (tlbsrch_done        ),
        .s1_found            (s1_found            ),
        .s1_index            (s1_index            ),

        .tlbwr_valid         (tlbwr_valid         ),
        .tlbfill_valid       (tlbfill_valid       ),
        .w_index             (w_index             ),
        .w_e                 (w_e                 ),
        .w_vppn              (w_vppn              ),
        .w_ps                (w_ps                ),
        .w_asid              (w_asid              ),
        .w_g                 (w_g                 ),
        .w_ppn0              (w_ppn0              ),
        .w_plv0              (w_plv0              ),
        .w_mat0              (w_mat0              ),
        .w_d0                (w_d0                ),
        .w_v0                (w_v0                ),
        .w_ppn1              (w_ppn1              ),
        .w_plv1              (w_plv1              ),
        .w_mat1              (w_mat1              ),
        .w_d1                (w_d1                ),
        .w_v1                (w_v1                ),

        .tlbrd_valid         (tlbrd_valid         ),
        .tlbrd_done          (tlbrd_done          ),
        .r_index             (r_index             ),
        .r_e                 (r_e                 ),
        .r_vppn              (r_vppn              ),
        .r_ps                (r_ps                ),
        .r_asid              (r_asid              ),
        .r_g                 (r_g                 ),
        .r_ppn0              (r_ppn0              ),
        .r_plv0              (r_plv0              ),
        .r_mat0              (r_mat0              ),
        .r_d0                (r_d0                ),
        .r_v0                (r_v0                ),
        .r_ppn1              (r_ppn1              ),
        .r_plv1              (r_plv1              ),
        .r_mat1              (r_mat1              ),
        .r_d1                (r_d1                ),
        .r_v1                (r_v1                )
	);

	tlb tlb(
		.clk                 (clk                 ),
        .rst                 (reset               ),
        // search port 0
        .s0_vppn             (s0_vppn             ),
        .s0_va_bit12         (s0_va_bit12         ),
        .s0_asid             (s0_asid             ),
        .s0_found            (s0_found            ),
        .s0_index            (s0_index            ),
        .s0_ppn              (s0_ppn              ),
        .s0_ps               (s0_ps               ),
        .s0_plv              (s0_plv              ),
        .s0_mat              (s0_mat              ),
        .s0_d                (s0_d                ),
        .s0_v                (s0_v                ),
        // search port 1
        .tlbsrch_valid       (tlbsrch_valid       ),
        .tlbsrch_done        (tlbsrch_done        ),
        .s1_vppn             (s1_vppn             ),
        .s1_va_bit12         (s1_va_bit12         ),
        .s1_asid             (s1_asid             ),
        .s1_found            (s1_found            ),
        .s1_index            (s1_index            ),
        .s1_ppn              (s1_ppn              ),
        .s1_ps               (s1_ps               ),
        .s1_plv              (s1_plv              ),
        .s1_mat              (s1_mat              ),
        .s1_d                (s1_d                ),
        .s1_v                (s1_v                ),
        // invtlb
        .invtlb_valid        (invtlb_valid        ),
        .invtlb_op           (invtlb_op           ),
        // write port
        .tlbwr_valid         (tlbwr_valid         ),
        .tlbfill_valid       (tlbfill_valid       ),
        .w_index             (w_index             ),
        .w_e                 (w_e                 ),
        .w_vppn              (w_vppn              ),
        .w_ps                (w_ps                ),
        .w_asid              (w_asid              ),
        .w_g                 (w_g                 ),
        .w_ppn0              (w_ppn0              ),
        .w_plv0              (w_plv0              ),
        .w_mat0              (w_mat0              ),
        .w_d0                (w_d0                ),
        .w_v0                (w_v0                ),
        .w_ppn1              (w_ppn1              ),
        .w_plv1              (w_plv1              ),
        .w_mat1              (w_mat1              ),
        .w_d1                (w_d1                ),
        .w_v1                (w_v1                ),
        // read port
        .tlbrd_valid         (tlbrd_valid         ),
        .tlbrd_done          (tlbrd_done          ),
        .r_index             (r_index             ),
        .r_e                 (r_e                 ),
        .r_vppn              (r_vppn              ),
        .r_ps                (r_ps                ),
        .r_asid              (r_asid              ),
        .r_g                 (r_g                 ),
        .r_ppn0              (r_ppn0              ),
        .r_plv0              (r_plv0              ),
        .r_mat0              (r_mat0              ),
        .r_d0                (r_d0                ),
        .r_v0                (r_v0                ),
        .r_ppn1              (r_ppn1              ),
        .r_plv1              (r_plv1              ),
        .r_mat1              (r_mat1              ),
        .r_d1                (r_d1                ),
        .r_v1                (r_v1                )
	);

endmodule
