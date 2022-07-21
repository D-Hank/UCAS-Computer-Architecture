module sram_axi_bridge(
    input           clk                 ,
    input           resetn              ,

    //cpu interface
    //inst ram
    input           inst_sram_req       ,
    input           inst_sram_wr        ,
    input  [ 1: 0]  inst_sram_size      ,
    input  [31: 0]  inst_sram_addr      ,
    input  [ 3: 0]  inst_sram_wstrb     ,
    input  [31: 0]  inst_sram_wdata     ,
    output          inst_sram_addr_ok   ,
    output          inst_sram_data_ok   ,
    output [31: 0]  inst_sram_rdata     ,

    //data ram
    input           data_sram_req       ,
    input           data_sram_wr        ,
    input  [ 1: 0]  data_sram_size      ,
    input  [31: 0]  data_sram_addr      ,
    input  [ 3: 0]  data_sram_wstrb     ,
    input  [31: 0]  data_sram_wdata     ,
    output          data_sram_addr_ok   ,
    output          data_sram_data_ok   ,
    output [31: 0]  data_sram_rdata     ,

    //axi interface
    //read request
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

    //read data & response
    input  [ 3: 0]  rid                 ,
    input  [31: 0]  rdata               ,
    input  [ 1: 0]  rresp               ,
    input           rlast               ,
    input           rvalid              ,
    output          rready              ,

    //write request
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

    //write data
    output [ 3: 0]  wid                 ,
    output [31: 0]  wdata               ,
    output [ 3: 0]  wstrb               ,
    output          wlast               ,
    output          wvalid              ,
    input           wready              ,

    //write response
    input  [ 3: 0]  bid                 ,
    input  [ 1: 0]  bresp               ,
    input           bvalid              ,
    output          bready
);

    localparam  RD_IDLE = 3'b001,
                RD_ADDR = 3'b010,
                RD_DATA = 3'b100,

                WR_IDLE = 4'b0001,
                WR_ADDR = 4'b0010,
                WR_DATA = 4'b0100,
                WR_RESP = 4'b1000;

    wire      rst;

    reg [2:0] rd_current;
    reg [2:0] rd_next;

    reg [3:0] wr_current;
    reg [3:0] wr_next;

    wire      has_read_request;
    wire      has_write_request;
    wire      has_raw_conflict;

    wire      from_RD_IDLE_to_RD_ADDR;
    wire      from_RD_ADDR_to_RD_DATA;
    wire      from_RD_DATA_to_RD_IDLE;

    wire      from_WR_IDLE_to_WR_ADDR;
    wire      from_WR_ADDR_to_WR_DATA;
    wire      from_WR_DATA_to_WR_RESP;
    wire      from_WR_RESP_to_WR_IDLE;

    assign    rst = ~resetn;

    always @(posedge clk)
    begin
        if (rst)
        begin
            rd_current <= RD_IDLE;
        end
        else
        begin
            rd_current <= rd_next;
        end
    end

    always @(*)
    begin
        case(rd_current)
        RD_IDLE:
        begin
            if(has_read_request)
            begin
                rd_next = RD_ADDR;//wait to send read request
            end
            else
            begin
                rd_next = RD_IDLE;
            end
        end

        RD_ADDR:
        begin
            if (arready & ~has_raw_conflict)
            begin
                rd_next = RD_DATA;//wait to receive read data
            end
            else
            begin
                rd_next = RD_ADDR;
            end
        end

        RD_DATA:
        begin
            if (rvalid)
            begin
                rd_next = RD_IDLE;//go back and wait for scheduling
            end
            else
            begin
                rd_next = RD_DATA;
            end
        end

        default:
            rd_next = RD_IDLE;

        endcase
    end

    always @(posedge clk)
    begin
        if (rst)
        begin
            wr_current <= WR_IDLE;
        end
        else
        begin
            wr_current <= wr_next;
        end
    end

    always @(*)
    begin
        case(wr_current)
        WR_IDLE:
        begin
            if(has_write_request)
            begin
                wr_next = WR_ADDR;//wait to send read request
            end
            else
            begin
                wr_next = WR_IDLE;
            end
        end

        WR_ADDR:
        begin
            if (awready)
            begin
                wr_next = WR_DATA;//wait to receive read data
            end
            else
            begin
                wr_next = WR_ADDR;
            end
        end

        WR_DATA:
        begin
            if (wready)
            begin
                wr_next = WR_RESP;//wait for feedback
            end
            else
            begin
                wr_next = WR_DATA;
            end
        end

        WR_RESP:
        begin
            if (bvalid)
            begin
                wr_next = WR_IDLE;
            end
            else
            begin
                wr_next = WR_RESP;
            end
        end

        default:
            wr_next = WR_IDLE;

        endcase
    end

    assign arlen    = 8'b00000000;
    assign arburst  = 2'b01;
    assign arlock   = 2'b00;
    assign arcache  = 4'b0000;
    assign arprot   = 3'b000;

    assign awid     = 4'b0001;
    assign awlen    = 8'b00000000;
    assign awburst  = 2'b01;
    assign awlock   = 2'b00;
    assign awcache  = 4'b0000;
    assign awprot   = 3'b000;

    assign wid      = 4'b0001;
    assign wlast    = 1'b1;

    wire inst_or_data;//0 for inst, 1 for data
    reg  inst_or_data_r;//data first

    assign inst_or_data = data_sram_req & ~data_sram_wr;
    always @(posedge clk)
    begin
        if (rd_current[0])
        begin
            inst_or_data_r <= inst_or_data;
        end
    end

    assign has_read_request  = inst_sram_req & ~inst_sram_wr | data_sram_req & ~data_sram_wr;
    assign has_write_request = data_sram_req & data_sram_wr;

    assign from_RD_IDLE_to_RD_ADDR = rd_current[0] & has_read_request;
    assign from_RD_ADDR_to_RD_DATA = rd_current[1] & arready & ~has_raw_conflict;
    assign from_RD_DATA_to_RD_IDLE = rd_current[2] & rvalid;

    assign from_WR_IDLE_to_WR_ADDR = wr_current[0] & has_write_request;
    assign from_WR_ADDR_to_WR_DATA = wr_current[1] & awready;
    assign from_WR_DATA_to_WR_RESP = wr_current[2] & wready;
    assign from_WR_RESP_to_WR_IDLE = wr_current[3] & bvalid;

    //assume that an instruction cannot be revised
    //NOTICE: this 'valid' cannot rely on slave ready
    assign inst_sram_addr_ok = rd_current[0] & ~inst_or_data;//wait for a rd_request with no data writing
    assign data_sram_addr_ok = from_RD_IDLE_to_RD_ADDR | from_WR_IDLE_to_WR_ADDR;

    reg [31: 0] rd_addr;
    reg [ 2: 0] rd_size;
    reg [ 3: 0] rd_id;
    reg [31: 0] rd_data;
    always @(posedge clk)
    begin
        if(rst)
        begin
            rd_addr <= 32'b0;
        end
        else if(from_RD_IDLE_to_RD_ADDR & ~inst_or_data)
        begin
            rd_addr <= inst_sram_addr;
        end
        else if(from_RD_IDLE_to_RD_ADDR & inst_or_data)
        begin
            rd_addr <= data_sram_addr;
        end
    end

    always @(posedge clk)
    begin
        if(from_RD_IDLE_to_RD_ADDR & ~inst_or_data)
        begin
            rd_size <= inst_sram_size;
            rd_id   <= 4'b0000;
        end
        else if(from_RD_IDLE_to_RD_ADDR & inst_or_data)
        begin
            rd_size <= data_sram_size;
            rd_id   <= 4'b0001;
        end
    end
    assign araddr = rd_addr;
    assign arsize = rd_size;
    assign arid   = rd_id;

    always @(posedge clk)
    begin
        if(from_RD_DATA_to_RD_IDLE)
        begin
            rd_data <= rdata;
        end
    end
    assign inst_sram_rdata = from_RD_DATA_to_RD_IDLE ? rdata : rd_data;
    assign data_sram_rdata = from_RD_DATA_to_RD_IDLE ? rdata : rd_data;

    assign arvalid = rd_current[1] & ~has_raw_conflict;
    assign rready  = rd_current[2];

    //inst_sram_w*** is ignored here

    reg [31: 0] wr_addr;
    reg [31: 0] wr_data;
    reg [ 2: 0] wr_size;
    reg [ 3: 0] wr_strb;
    always @(posedge clk)
    begin
        if(rst)
        begin
            wr_addr <= 32'b1;
        end
        else if(from_WR_IDLE_to_WR_ADDR)
        begin
            wr_addr <= data_sram_addr;
        end
    end

    always @(posedge clk)
    begin
        if(from_WR_IDLE_to_WR_ADDR)
        begin
            wr_data <= data_sram_wdata;
            wr_size <= data_sram_size;
            wr_strb <= data_sram_wstrb;
        end
    end
    assign awaddr  = wr_addr;
    assign awsize  = wr_size;
    assign awvalid = wr_current[1];
    assign wdata   = wr_data;
    assign wstrb   = wr_strb;
    assign wvalid  = wr_current[2];
    assign bready  = wr_current[3];

    assign has_raw_conflict  = (rd_addr == wr_addr) & ~wr_current[0] & ~from_WR_RESP_to_WR_IDLE;

    assign inst_sram_data_ok = from_RD_DATA_to_RD_IDLE & ~inst_or_data_r;
    assign data_sram_data_ok = from_RD_DATA_to_RD_IDLE &  inst_or_data_r | from_WR_RESP_to_WR_IDLE;

endmodule
