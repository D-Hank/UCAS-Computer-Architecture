module mycpu_top(
    input           aclk                ,
    input           aresetn             ,

    //read request interface
    output [ 3: 0]  arid                ,
    output [31: 0]  araddr              ,
    output [ 7: 0]  arlen               ,
    output [ 2: 0]  arsize              ,
    output [ 1: 0]  arburst             ,
    output [ 1: 0]  arlock              ,
    output [ 3: 0]  arcache             ,
    output [ 2: 0]  arprot              ,
    output          arvalid             ,
    input           arready             ,

    //read data interface
    input  [ 3: 0]  rid                 ,
    input  [31: 0]  rdata               ,
    input  [ 1: 0]  rresp               ,
    input           rlast               ,
    input           rvalid              ,
    output          rready              ,

    //write request interface
    output [ 3: 0]  awid                ,
    output [31: 0]  awaddr              ,
    output [ 7: 0]  awlen               ,
    output [ 2: 0]  awsize              ,
    output [ 1: 0]  awburst             ,
    output [ 1: 0]  awlock              ,
    output [ 3: 0]  awcache             ,
    output [ 2: 0]  awprot              ,
    output          awvalid             ,
    input           awready             ,

    //write data interface
    output [ 3: 0]  wid                 ,
    output [31: 0]  wdata               ,
    output [ 3: 0]  wstrb               ,
    output          wlast               ,
    output          wvalid              ,
    input           wready              ,

    //write response interface
    input  [ 3: 0]  bid                 ,
    input  [ 1: 0]  bresp               ,
    input           bvalid              ,
    output          bready              ,

    //debug interface
    output [31: 0]  debug_wb_pc         ,
    output [ 3: 0]  debug_wb_rf_wen     ,
    output [ 4: 0]  debug_wb_rf_wnum    ,
    output [31: 0]  debug_wb_rf_wdata
);

    // inst sram interface
    wire            inst_sram_req       ;
    wire            inst_sram_wr        ;
    wire   [ 1: 0]  inst_sram_size      ;
    wire   [31: 0]  inst_sram_addr      ;
    wire   [ 3: 0]  inst_sram_wstrb     ;
    wire   [31: 0]  inst_sram_wdata     ;
    wire            inst_sram_addr_ok   ;
    wire            inst_sram_data_ok   ;
    wire   [31: 0]  inst_sram_rdata     ;
    // data sram interface
    wire            data_sram_req       ;
    wire            data_sram_wr        ;
    wire   [ 1: 0]  data_sram_size      ;
    wire   [31: 0]  data_sram_addr      ;
    wire   [ 3: 0]  data_sram_wstrb     ;
    wire   [31: 0]  data_sram_wdata     ;
    wire            data_sram_addr_ok   ;
    wire            data_sram_data_ok   ;
    wire   [31: 0]  data_sram_rdata     ;
    // trace debug interface
    wire   [31: 0]  debug_wb_pc         ;
    wire   [ 3: 0]  debug_wb_rf_wen     ;
    wire   [ 4: 0]  debug_wb_rf_wnum    ;
    wire   [31: 0]  debug_wb_rf_wdata   ;

    mycpu_sram u_cpu_sram(
        .clk                (aclk               ),
        .resetn             (aresetn            ),

        .inst_sram_req      (inst_sram_req      ),
        .inst_sram_wr       (inst_sram_wr       ),
        .inst_sram_size     (inst_sram_size     ),
        .inst_sram_addr     (inst_sram_addr     ),
        .inst_sram_wstrb    (inst_sram_wstrb    ),
        .inst_sram_wdata    (inst_sram_wdata    ),
        .inst_sram_addr_ok  (inst_sram_addr_ok  ),
        .inst_sram_data_ok  (inst_sram_data_ok  ),
        .inst_sram_rdata    (inst_sram_rdata    ),

        .data_sram_req      (data_sram_req      ),
        .data_sram_wr       (data_sram_wr       ),
        .data_sram_size     (data_sram_size     ),
        .data_sram_addr     (data_sram_addr     ),
        .data_sram_wstrb    (data_sram_wstrb    ),
        .data_sram_wdata    (data_sram_wdata    ),
        .data_sram_addr_ok  (data_sram_addr_ok  ),
        .data_sram_data_ok  (data_sram_data_ok  ),
        .data_sram_rdata    (data_sram_rdata    ),

        .debug_wb_pc        (debug_wb_pc        ),
        .debug_wb_rf_wen    (debug_wb_rf_wen    ),
        .debug_wb_rf_wnum   (debug_wb_rf_wnum   ),
        .debug_wb_rf_wdata  (debug_wb_rf_wdata  )
    );

    sram_axi_bridge u_sram_axi_bridge(
        .clk                (aclk               ),
        .resetn             (aresetn            ),

        //cpu interface
        .inst_sram_req      (inst_sram_req      ),
        .inst_sram_wr       (inst_sram_wr       ),
        .inst_sram_size     (inst_sram_size     ),
        .inst_sram_addr     (inst_sram_addr     ),
        .inst_sram_wstrb    (inst_sram_wstrb    ),
        .inst_sram_wdata    (inst_sram_wdata    ),
        .inst_sram_addr_ok  (inst_sram_addr_ok  ),
        .inst_sram_data_ok  (inst_sram_data_ok  ),
        .inst_sram_rdata    (inst_sram_rdata    ),

        .data_sram_req      (data_sram_req      ),
        .data_sram_wr       (data_sram_wr       ),
        .data_sram_size     (data_sram_size     ),
        .data_sram_addr     (data_sram_addr     ),
        .data_sram_wstrb    (data_sram_wstrb    ),
        .data_sram_wdata    (data_sram_wdata    ),
        .data_sram_addr_ok  (data_sram_addr_ok  ),
        .data_sram_data_ok  (data_sram_data_ok  ),
        .data_sram_rdata    (data_sram_rdata    ),

        //axi interface
        .arid               (arid               ),
        .araddr             (araddr             ),
        .arlen              (arlen              ),
        .arsize             (arsize             ),
        .arburst            (arburst            ),
        .arlock             (arlock             ),
        .arcache            (arcache            ),
        .arprot             (arprot             ),
        .arvalid            (arvalid            ),
        .arready            (arready            ),

        .rid                (rid                ),
        .rdata              (rdata              ),
        .rresp              (rresp              ),
        .rlast              (rlast              ),
        .rvalid             (rvalid             ),
        .rready             (rready             ),

        .awid               (awid               ),
        .awaddr             (awaddr             ),
        .awlen              (awlen              ),
        .awsize             (awsize             ),
        .awburst            (awburst            ),
        .awlock             (awlock             ),
        .awcache            (awcache            ),
        .awprot             (awprot             ),
        .awvalid            (awvalid            ),
        .awready            (awready            ),

        .wid                (wid                ),
        .wdata              (wdata              ),
        .wstrb              (wstrb              ),
        .wlast              (wlast              ),
        .wvalid             (wvalid             ),
        .wready             (wready             ),

        .bid                (bid                ),
        .bresp              (bresp              ),
        .bvalid             (bvalid             ),
        .bready             (bready             )
    );

endmodule