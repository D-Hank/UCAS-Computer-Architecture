module cache( 
    input          clk_g,
    input          resetn,

    input          valid,
    input          op,
    input  [ 7:0]  index,
    input  [19:0]  tag,
    input  [ 3:0]  offset,
    output         addr_ok,
    output         data_ok,
    output [31:0]  rdata,

    input  [ 3:0]  wstrb,
    input  [31:0]  wdata,

    output         rd_req,
    output [ 2:0]  rd_type,
    output [31:0]  rd_addr,
    input          rd_rdy,
    input          ret_valid,
    input          ret_last,
    input  [31:0]  ret_data,

    input          wr_rdy,
    output         wr_req,
    output [ 2:0]  wr_type,
    output [31:0]  wr_addr,
    output [ 3:0]  wr_wstrb,
    output [127:0] wr_data
);

    localparam  IDLE    = 5'b00001,
                LOOKUP  = 5'b00010,
                MISS    = 5'b00100,
                REPLACE = 5'b01000,
                REFILL  = 5'b10000,

                S_IDLE  = 2'b01,
                S_WRITE = 2'b10;

    wire        rst;
    wire        clk;

    reg  [ 4:0] main_current;
    reg  [ 4:0] main_next;

    reg  [ 1:0] sub_current;
    reg  [ 1:0] sub_next;

    wire        hit_wr_conflict;

    wire        from_IDLE_to_IDLE;
    wire        from_IDLE_to_LOOKUP;
    wire        from_LOOKUP_to_LOOKUP;
    wire        from_LOOKUP_to_IDLE;
    wire        from_LOOKUP_to_MISS;
    wire        from_MISS_to_MISS;
    wire        from_MISS_to_REPLACE;
    wire        from_REPLACE_to_REFILL;
    wire        from_REPLACE_to_REPLACE;
    wire        from_REFILL_to_REFILL;
    wire        from_REFILL_to_IDLE;

    wire        from_S_IDLE_to_S_IDLE;
    wire        from_S_IDLE_to_S_WRITE;
    wire        from_S_WRITE_to_S_IDLE;
    wire        from_S_WRITE_to_S_WRITE;

    wire        way0_hit;
    wire        way1_hit;
    wire        cache_hit;

    wire        hit_write;
    wire        replace_way;
    wire [31:0] replace_addr;
    wire [127:0] replace_data;

    assign      clk = clk_g;
    assign      rst = ~resetn;

    always @(posedge clk)
    begin
        if (rst)
        begin
            main_current <= IDLE;
        end
        else
        begin
            main_current <= main_next;
        end
    end

    always @(*)
    begin
        case(main_current)
        IDLE:
        begin
            if(valid & ~hit_wr_conflict)
            begin
                main_next = LOOKUP;//to accept a request
            end
            else
            begin
                main_next = IDLE;
            end
        end

        LOOKUP:
        begin
            if(cache_hit & (~valid | valid & hit_wr_conflict))
            begin
                main_next = IDLE;//wait data written into cache
            end
            else if(~cache_hit)
            begin
                main_next = MISS;
            end
            else
            begin
                main_next = LOOKUP;//new request without conflict
            end
        end

        MISS:
        begin
            if(wr_rdy)
            begin
                main_next = REPLACE;
            end
            else
            begin
                main_next = MISS;
            end
        end

        REPLACE:
        begin
            if(rd_rdy)
            begin
                main_next = REFILL;
            end
            else
            begin
                main_next = REPLACE;
            end
        end

        REFILL:
        begin
            if(ret_valid & ret_last)
            begin
                main_next = IDLE;
            end
            else
            begin
                main_next = REFILL;
            end
        end

        default:
            main_next = IDLE;

        endcase
    end

    always @(posedge clk)
    begin
        if (rst)
        begin
            sub_current <= S_IDLE;
        end
        else
        begin
            sub_current <= sub_next;
        end
    end

    always @(*)
    begin
        case(sub_current)
        S_IDLE:
        begin
            if(hit_write)
            begin
                sub_next = S_WRITE;
            end
            else
            begin
                sub_next = S_IDLE;
            end
        end

        S_WRITE:
        begin
            if(~hit_write)
            begin
                sub_next = S_IDLE;
            end
            else//accept a request at the same time
            begin
                sub_next = S_WRITE;
            end
        end

        default:
            sub_next = S_IDLE;

        endcase
    end

    //Request Buffer
    reg         op_req;
    reg  [ 7:0] index_req;
    reg  [19:0] tag_req;
    reg  [ 3:0] offset_req;
    reg  [ 3:0] wstrb_req;
    reg  [31:0] wdata_req;

    //Refill Buffer
    reg  [ 1:0] ret_count;
    wire [31:0] refill_data;

    always @(posedge clk)
    begin
        if(from_IDLE_to_LOOKUP | from_LOOKUP_to_LOOKUP)
        //just accepted a request
        begin
            op_req     <= op;
            tag_req    <= tag;
            offset_req <= offset;
            wstrb_req  <= wstrb;
            wdata_req  <= wdata;
        end
    end

    always @(posedge clk)
    begin
        if(rst)
        begin
            index_req <= 8'b0;//assign a initial value
        end
        else if(from_IDLE_to_LOOKUP | from_LOOKUP_to_LOOKUP)
        begin
            index_req  <= index;
        end
    end

    //tag_v_0
    wire        tag_v_0_we;
    wire [ 7:0] tag_v_0_addr;
    wire [20:0] tag_v_0_wdata;
    wire [20:0] tag_v_0_rdata;

    tag_v tag_v_0(
        .clka   (clk            ),
        .wea    (tag_v_0_we     ),
        .addra  (tag_v_0_addr   ),
        .dina   (tag_v_0_wdata  ),
        .douta  (tag_v_0_rdata  )
    );

    //tag_v_1
    wire        tag_v_1_we;
    wire [ 7:0] tag_v_1_addr;
    wire [20:0] tag_v_1_wdata;
    wire [20:0] tag_v_1_rdata;
    
    tag_v tag_v_1(
        .clka   (clk            ),
        .wea    (tag_v_1_we     ),
        .addra  (tag_v_1_addr   ),
        .dina   (tag_v_1_wdata  ),
        .douta  (tag_v_1_rdata  )
    );

    reg [255:0] dirty_0;
    reg [255:0] dirty_1;

    always @(posedge clk)
    begin
        if(rst)
        begin
            dirty_0 <= 256'b0;
        end
        else if(from_REFILL_to_IDLE & replace_way == 1'b0)
        begin
            dirty_0[index_req] <= op_req;
        end

        if(rst)
        begin
            dirty_1 <= 256'b0;
        end
        else if(from_REFILL_to_IDLE & replace_way == 1'b1)
        begin
            dirty_1[index_req] <= op_req;
        end
    end

    wire [ 3:0] data_way0_bank0_we      ;
    wire [ 7:0] data_way0_bank0_addr    ;//0 ~ 255
    wire [31:0] data_way0_bank0_wdata   ;
    wire [31:0] data_way0_bank0_rdata   ;

    data data_way0_bank0(
        .clka   (clk                    ),
        .wea    (data_way0_bank0_we     ),
        .addra  (data_way0_bank0_addr   ),
        .dina   (data_way0_bank0_wdata  ),
        .douta  (data_way0_bank0_rdata  )
    );

    wire [ 3:0] data_way0_bank1_we      ;
    wire [ 7:0] data_way0_bank1_addr    ;
    wire [31:0] data_way0_bank1_wdata   ;
    wire [31:0] data_way0_bank1_rdata   ;

    data data_way0_bank1(
        .clka   (clk                    ),
        .wea    (data_way0_bank1_we     ),
        .addra  (data_way0_bank1_addr   ),
        .dina   (data_way0_bank1_wdata  ),
        .douta  (data_way0_bank1_rdata  )
    );

    wire [ 3:0] data_way0_bank2_we      ;
    wire [ 7:0] data_way0_bank2_addr    ;
    wire [31:0] data_way0_bank2_wdata   ;
    wire [31:0] data_way0_bank2_rdata   ;

    data data_way0_bank2(
        .clka   (clk                    ),
        .wea    (data_way0_bank2_we     ),
        .addra  (data_way0_bank2_addr   ),
        .dina   (data_way0_bank2_wdata  ),
        .douta  (data_way0_bank2_rdata  )
    );

    wire [ 3:0] data_way0_bank3_we      ;
    wire [ 7:0] data_way0_bank3_addr    ;
    wire [31:0] data_way0_bank3_wdata   ;
    wire [31:0] data_way0_bank3_rdata   ;

    data data_way0_bank3(
        .clka   (clk                    ),
        .wea    (data_way0_bank3_we     ),
        .addra  (data_way0_bank3_addr   ),
        .dina   (data_way0_bank3_wdata  ),
        .douta  (data_way0_bank3_rdata  )
    );

    wire [ 3:0] data_way1_bank0_we      ;
    wire [ 7:0] data_way1_bank0_addr    ;
    wire [31:0] data_way1_bank0_wdata   ;
    wire [31:0] data_way1_bank0_rdata   ;

    data data_way1_bank0(
        .clka   (clk                    ),
        .wea    (data_way1_bank0_we     ),
        .addra  (data_way1_bank0_addr   ),
        .dina   (data_way1_bank0_wdata  ),
        .douta  (data_way1_bank0_rdata  )
    );

    wire [ 3:0] data_way1_bank1_we      ;
    wire [ 7:0] data_way1_bank1_addr    ;
    wire [31:0] data_way1_bank1_wdata   ;
    wire [31:0] data_way1_bank1_rdata   ;

    data data_way1_bank1(
        .clka   (clk                    ),
        .wea    (data_way1_bank1_we     ),
        .addra  (data_way1_bank1_addr   ),
        .dina   (data_way1_bank1_wdata  ),
        .douta  (data_way1_bank1_rdata  )
    );

    wire [ 3:0] data_way1_bank2_we      ;
    wire [ 7:0] data_way1_bank2_addr    ;
    wire [31:0] data_way1_bank2_wdata   ;
    wire [31:0] data_way1_bank2_rdata   ;

    data data_way1_bank2(
        .clka   (clk                    ),
        .wea    (data_way1_bank2_we     ),
        .addra  (data_way1_bank2_addr   ),
        .dina   (data_way1_bank2_wdata  ),
        .douta  (data_way1_bank2_rdata  )
    );

    wire [ 3:0] data_way1_bank3_we      ;
    wire [ 7:0] data_way1_bank3_addr    ;
    wire [31:0] data_way1_bank3_wdata   ;
    wire [31:0] data_way1_bank3_rdata   ;

    data data_way1_bank3(
        .clka   (clk                    ),
        .wea    (data_way1_bank3_we     ),
        .addra  (data_way1_bank3_addr   ),
        .dina   (data_way1_bank3_wdata  ),
        .douta  (data_way1_bank3_rdata  )
    );

    assign from_IDLE_to_IDLE       = main_current[0] & (~valid | valid & hit_wr_conflict);
    assign from_IDLE_to_LOOKUP     = main_current[0] & valid & ~hit_wr_conflict;
    assign from_LOOKUP_to_IDLE     = main_current[1] & cache_hit & (~valid | valid & hit_wr_conflict);
    assign from_LOOKUP_to_LOOKUP   = main_current[1] & cache_hit & valid & ~hit_wr_conflict;
    assign from_LOOKUP_to_MISS     = main_current[1] & ~cache_hit;
    assign from_MISS_to_MISS       = main_current[2] & ~wr_rdy;
    assign from_MISS_to_REPLACE    = main_current[2] & wr_rdy;
    assign from_REPLACE_to_REPLACE = main_current[3] & ~rd_rdy;
    assign from_REPLACE_to_REFILL  = main_current[3] & rd_rdy;
    assign from_REFILL_to_REFILL   = main_current[4] & ~(ret_valid & ret_last);
    assign from_REFILL_to_IDLE     = main_current[4] & ret_valid & ret_last;

    assign from_S_IDLE_to_S_IDLE   = sub_current[0] & ~hit_write;
    assign from_S_IDLE_to_S_WRITE  = sub_current[0] & hit_write;
    assign from_S_WRITE_to_S_WRITE = sub_current[1] & hit_write;
    assign from_S_WRITE_to_S_IDLE  = sub_current[1] & ~hit_write;

    wire [127:0] way0_data;
    wire [127:0] way1_data;
    wire [31: 0] way0_addr;
    wire [31: 0] way1_addr;
    wire [31: 0] way0_load_word;
    wire [31: 0] way1_load_word;
    wire [31: 0] load_res;
    wire [31: 0] pa;

    wire [19: 0] way0_tag;
    wire [19: 0] way1_tag;
    wire         way0_v;
    wire         way1_v;

    assign way0_data      = {data_way0_bank3_rdata,
                             data_way0_bank2_rdata,
                             data_way0_bank1_rdata,
                             data_way0_bank0_rdata};
    assign way1_data      = {data_way1_bank3_rdata,
                             data_way1_bank2_rdata,
                             data_way1_bank1_rdata,
                             data_way1_bank0_rdata};

    assign way0_load_word = way0_data[pa[3:2]*32 +: 32];
    assign way1_load_word = way1_data[pa[3:2]*32 +: 32];
    assign load_res       = {32{way0_hit}} & way0_load_word
                          | {32{way1_hit}} & way1_load_word;
    assign replace_data   = replace_way ? way1_data : way0_data;
    assign replace_addr   = replace_way ? way1_addr : way0_addr;
    assign pa             = {tag, offset};

    assign way0_v    = tag_v_0_rdata[0];
    assign way1_v    = tag_v_1_rdata[0];
    assign way0_tag  = tag_v_0_rdata[20:1];
    assign way1_tag  = tag_v_1_rdata[20:1];
    assign way0_addr = {way0_tag, index_req, offset_req};
    assign way1_addr = {way1_tag, index_req, offset_req};

    assign way0_hit  = way0_v && (way0_tag == tag_req);
    assign way1_hit  = way1_v && (way1_tag == tag_req);
    assign cache_hit = way0_hit || way1_hit;

    assign refill_data[ 7: 0] = (ret_count==offset_req[3:2] && wstrb_req[0]) ? wdata_req[ 7: 0] : ret_data[ 7: 0];
    assign refill_data[15: 8] = (ret_count==offset_req[3:2] && wstrb_req[1]) ? wdata_req[15: 8] : ret_data[15: 8];
    assign refill_data[23:16] = (ret_count==offset_req[3:2] && wstrb_req[2]) ? wdata_req[23:16] : ret_data[23:16];
    assign refill_data[31:24] = (ret_count==offset_req[3:2] && wstrb_req[3]) ? wdata_req[31:24] : ret_data[31:24];

    assign tag_v_0_we    = from_REFILL_to_IDLE && (replace_way == 1'b0);
    assign tag_v_1_we    = from_REFILL_to_IDLE && (replace_way == 1'b1);
    assign tag_v_0_addr  = (from_IDLE_to_LOOKUP | from_LOOKUP_to_LOOKUP) ? index : index_req;
    assign tag_v_1_addr  = (from_IDLE_to_LOOKUP | from_LOOKUP_to_LOOKUP) ? index : index_req;
    assign tag_v_0_wdata = {tag_req, 1'b1};
    assign tag_v_1_wdata = {tag_req, 1'b1};

    assign data_way0_bank0_addr = (from_IDLE_to_LOOKUP | from_LOOKUP_to_LOOKUP) ? index : index_req;
    assign data_way0_bank1_addr = (from_IDLE_to_LOOKUP | from_LOOKUP_to_LOOKUP) ? index : index_req;
    assign data_way0_bank2_addr = (from_IDLE_to_LOOKUP | from_LOOKUP_to_LOOKUP) ? index : index_req;
    assign data_way0_bank3_addr = (from_IDLE_to_LOOKUP | from_LOOKUP_to_LOOKUP) ? index : index_req;
    assign data_way1_bank0_addr = (from_IDLE_to_LOOKUP | from_LOOKUP_to_LOOKUP) ? index : index_req;
    assign data_way1_bank1_addr = (from_IDLE_to_LOOKUP | from_LOOKUP_to_LOOKUP) ? index : index_req;
    assign data_way1_bank2_addr = (from_IDLE_to_LOOKUP | from_LOOKUP_to_LOOKUP) ? index : index_req;
    assign data_way1_bank3_addr = (from_IDLE_to_LOOKUP | from_LOOKUP_to_LOOKUP) ? index : index_req;

    assign data_way0_bank0_wdata = (from_S_IDLE_to_S_WRITE | from_S_WRITE_to_S_WRITE) ? wdata_req : refill_data;
    assign data_way0_bank1_wdata = (from_S_IDLE_to_S_WRITE | from_S_WRITE_to_S_WRITE) ? wdata_req : refill_data;
    assign data_way0_bank2_wdata = (from_S_IDLE_to_S_WRITE | from_S_WRITE_to_S_WRITE) ? wdata_req : refill_data;
    assign data_way0_bank3_wdata = (from_S_IDLE_to_S_WRITE | from_S_WRITE_to_S_WRITE) ? wdata_req : refill_data;
    assign data_way1_bank0_wdata = (from_S_IDLE_to_S_WRITE | from_S_WRITE_to_S_WRITE) ? wdata_req : refill_data;
    assign data_way1_bank1_wdata = (from_S_IDLE_to_S_WRITE | from_S_WRITE_to_S_WRITE) ? wdata_req : refill_data;
    assign data_way1_bank2_wdata = (from_S_IDLE_to_S_WRITE | from_S_WRITE_to_S_WRITE) ? wdata_req : refill_data;
    assign data_way1_bank3_wdata = (from_S_IDLE_to_S_WRITE | from_S_WRITE_to_S_WRITE) ? wdata_req : refill_data;

    assign data_way0_bank0_we = ((from_S_IDLE_to_S_WRITE | from_S_WRITE_to_S_WRITE) && way0_hit && (offset_req[3:2] == 2'b00)) ? wstrb_req :
                                (main_current[4] && (replace_way == 1'b0) && ret_valid && (ret_count == 2'b00)) ? 4'b1111 :
                                4'b0000;
    assign data_way0_bank1_we = ((from_S_IDLE_to_S_WRITE | from_S_WRITE_to_S_WRITE) && way0_hit && (offset_req[3:2] == 2'b01)) ? wstrb_req :
                                (main_current[4] && (replace_way == 1'b0) && ret_valid && (ret_count == 2'b01)) ? 4'b1111 :
                                4'b0000;
    assign data_way0_bank2_we = ((from_S_IDLE_to_S_WRITE | from_S_WRITE_to_S_WRITE) && way0_hit && (offset_req[3:2] == 2'b10)) ? wstrb_req :
                                (main_current[4] && (replace_way == 1'b0) && ret_valid && (ret_count == 2'b10)) ? 4'b1111 :
                                4'b0000;
    assign data_way0_bank3_we = ((from_S_IDLE_to_S_WRITE | from_S_WRITE_to_S_WRITE) && way0_hit && (offset_req[3:2] == 2'b11)) ? wstrb_req :
                                (main_current[4] && (replace_way == 1'b0) && ret_valid && (ret_count == 2'b11)) ? 4'b1111 :
                                4'b0000;
    assign data_way1_bank0_we = ((from_S_IDLE_to_S_WRITE | from_S_WRITE_to_S_WRITE) && way1_hit && (offset_req[3:2] == 2'b00)) ? wstrb_req :
                                (main_current[4] && (replace_way == 1'b1) && ret_valid && (ret_count == 2'b00)) ? 4'b1111 :
                                4'b0000;
    assign data_way1_bank1_we = ((from_S_IDLE_to_S_WRITE | from_S_WRITE_to_S_WRITE) && way1_hit && (offset_req[3:2] == 2'b01)) ? wstrb_req :
                                (main_current[4] && (replace_way == 1'b1) && ret_valid && (ret_count == 2'b01)) ? 4'b1111 :
                                4'b0000;
    assign data_way1_bank2_we = ((from_S_IDLE_to_S_WRITE | from_S_WRITE_to_S_WRITE) && way1_hit && (offset_req[3:2] == 2'b10)) ? wstrb_req :
                                (main_current[4] && (replace_way == 1'b1) && ret_valid && (ret_count == 2'b10)) ? 4'b1111 :
                                4'b0000;
    assign data_way1_bank3_we = ((from_S_IDLE_to_S_WRITE | from_S_WRITE_to_S_WRITE) && way1_hit && (offset_req[3:2] == 2'b11)) ? wstrb_req :
                                (main_current[4] && (replace_way == 1'b1) && ret_valid && (ret_count == 2'b11)) ? 4'b1111 :
                                4'b0000;

    always @(posedge clk)
    begin
        if(rst)
        begin
            ret_count <= 2'b00;
        end
        else if(main_current[4] & ret_valid)
        begin
            ret_count <= ret_count + 1'b1;
        end
    end

    assign hit_write       = cache_hit & op_req & main_current[1];
    assign hit_wr_conflict = valid && ~op && ((sub_current[1] && (offset_req[3:2] == offset[3:2])) || main_current[1] && hit_write && (offset_req == offset));

    reg [2:0] random;
    always @(posedge clk)
    begin
        if(rst)
        begin
            random <= 3'b111;
        end
        else if(from_REFILL_to_IDLE)
        begin
            random <= {random[1], random[0]^random[2], random[2]};
        end
    end
    assign replace_way = random[0];

    assign addr_ok  = main_current[0] | from_LOOKUP_to_LOOKUP;
    assign data_ok  = main_current[1] && cache_hit || main_current[4] && ret_valid && (ret_count == offset_req[3:2]);
    assign rd_req   = main_current[3];
    assign rd_type  = 3'b100;
    assign rd_addr  = {tag_req, index_req, 4'b0000};
    assign wr_type  = 3'b100;
    assign wr_addr  = {replace_addr[31:4], 4'b0000};
    assign wr_wstrb = 4'b1111;
    assign wr_data  = replace_data;

    reg wr_req_r;
    always @(posedge clk)
    begin
        if(rst)
        begin
            wr_req_r <= 1'b0;
        end
        else if(from_MISS_to_REPLACE)
        begin
            wr_req_r <= (replace_way == 1'b0 && dirty_0[index_req] == 1'b1 || replace_way == 1'b1 && dirty_1[index_req] == 1'b1);
        end
        else if(main_current[3])
        begin
            wr_req_r <= 1'b0;
        end
    end
    assign wr_req = wr_req_r;

    assign rdata = main_current[1] ? load_res : ret_data;
endmodule
