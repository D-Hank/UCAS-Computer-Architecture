`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // inst sram interface
    output                         inst_sram_req    ,
    output                         inst_sram_wr     ,
    output [ 1:                 0] inst_sram_size   ,
    output [31:                 0] inst_sram_addr   ,
    output [ 3:                 0] inst_sram_wstrb  ,
    output [31:                 0] inst_sram_wdata  ,
    input                          inst_sram_addr_ok,
    input                          inst_sram_data_ok,
    input  [31:                 0] inst_sram_rdata  ,
    //from ws
    input  [`WS_TO_FS_BUS_WD -1:0] ws_to_fs_bus
);

    // pre-IF
    wire ps_ready_go;
    wire ps_to_fs_valid;
	
	// PC_Branch
	reg  [31:0]  nextpc;
	wire         br_stall;
	wire         br_taken;
	wire [ 31:0] br_target;
	assign {br_stall,br_taken,br_target} = br_bus;
	
	// IF
	reg         fs_valid;
	wire        fs_ready_go;
	wire        fs_allowin;
	wire [31:0] fs_inst;
	reg  [31:0] fs_pc;
	reg         fs_finish;
	
	wire  		fs_ex;
    wire        faddr_error;
	wire [`ECODE_WD   -1:0] fs_ecode;
	wire [`ESUBCODE_WD-1:0] fs_esubcode;
	assign fs_to_ds_bus = {nextpc, fs_ex, fs_ecode, fs_esubcode, fs_inst, fs_pc};
	
	// inst_sram
    reg  [31:0] ps_inst_buf;
    reg         ps_inst_buf_valid;
    reg  [31:0] fs_inst_buf;
    reg         fs_inst_buf_valid;
    reg         ps_finish;  // pre-IF handshake successful
    reg  [ 1:0] inst_discard;//number of data_ok to be ignored
    wire        ps_br_taken;//completely computed branch taken

	wire        do_ex;
	wire [31:0] ex_entry;
	wire        do_ertn;
	wire [31:0] pc_ertn;
    wire        do_refetch;
    wire [31:0] pc_refetch;
	wire        ws_cancel_fs;
	assign {do_refetch,
            pc_refetch,
            do_ex     ,
	        ex_entry  ,
	        do_ertn   ,
	        pc_ertn
	        } = ws_to_fs_bus;
    assign ws_cancel_fs    = do_ex || do_ertn || do_refetch;

	// pre-IF stage
	assign ps_br_taken     = !br_stall && br_taken;//final branch taken
	assign ps_ready_go     = ps_finish || inst_sram_req && inst_sram_addr_ok;//already requested or just requested
	assign ps_to_fs_valid  = ~reset && ps_ready_go;
	// pc
    always @(posedge clk)
    begin
        if (reset)
        begin
            nextpc <= 32'h1c000000;
        end
        else if (do_ertn)
        begin
            nextpc <= pc_ertn;
        end
        else if (do_ex)
        begin
            nextpc <= ex_entry;
        end
        else if (do_refetch)
        begin
            nextpc <= pc_refetch;
        end
        else if ((!inst_discard[1] && !inst_discard[0]) && ~br_stall && br_taken)
        begin
            nextpc <= br_target;//no data_ok to ignore and now branch taken, then we can fetch a new inst
        end
        else if (ps_ready_go && fs_allowin)
        begin
            nextpc <= nextpc + 4;//now pass an inst to IF stage and fetch a new one
        end
    end

    // inst sram
    always @(posedge clk)
    begin
        if (reset)
        begin
            ps_inst_buf <= 32'b0;
        end
        else if (inst_sram_data_ok && !ps_inst_buf_valid)
        begin
            ps_inst_buf <= inst_sram_rdata;
            //returned an inst and temporily store
            //ps with no valid inst on hand
        end

        if (reset)
        begin
            ps_inst_buf_valid <= 1'b0;
        end
        else if (ps_br_taken || ws_cancel_fs)
        begin
            ps_inst_buf_valid <= 1'b0;
        end
        else if (fs_to_ds_valid && ds_allowin)
        begin
            ps_inst_buf_valid <= 1'b0;
        end
        else if (inst_sram_data_ok && fs_inst_buf_valid)
        begin
            ps_inst_buf_valid <= 1'b1;
        end

        if (reset) begin
            ps_finish <= 1'b0;
        end
        else if (ws_cancel_fs || ps_br_taken) begin
            ps_finish <= 1'b0;
        end
        else if (inst_sram_req && inst_sram_addr_ok && !fs_allowin) begin
            ps_finish <= 1'b1;
        end
        else if (fs_allowin) begin
            ps_finish <= 1'b0;
        end
    end
    
    // inst discard
    always @(posedge clk) begin
        if (reset) begin
            inst_discard <= 2'b00;
        end
        else if ((fs_allowin && ps_ready_go) && (ps_br_taken || ws_cancel_fs)) begin
            if (ps_inst_buf_valid && fs_inst_buf_valid) begin
                inst_discard <= 2'b00;
            end
            if (fs_inst_buf_valid) begin
                if ((!inst_discard[1] && !inst_discard[0]) && !inst_sram_data_ok) begin
                    inst_discard <= 2'b01;
                end
                else if ((inst_discard[1] || inst_discard[0]) && inst_sram_data_ok) begin
                    inst_discard <= inst_discard - 2'b01;
                end
                else begin
                    inst_discard <= inst_discard;
                end
            end
            else begin
                if (!inst_discard[1] && !inst_discard[0])
                    inst_discard <= 2'b01;
                else if ((inst_discard[1] || inst_discard[0]) && inst_sram_data_ok) begin
                    inst_discard <= inst_discard;
                end
                else begin
                    inst_discard <= inst_discard + 2'b01;
                end
            end
        end
        else if ((!fs_allowin && !ps_ready_go) && (ps_br_taken || ws_cancel_fs)) begin
            if (fs_inst_buf_valid) begin
                inst_discard <= 2'b00;
            end
            else begin
                if ((!inst_discard[1] && !inst_discard[0]) && inst_sram_data_ok) begin
                    inst_discard <= 2'b00;
                end
                if ((!inst_discard[1] && !inst_discard[0]) && !inst_sram_data_ok) begin
                    inst_discard <= 2'b01;
                end
                else if ((inst_discard[1] || inst_discard[0]) && inst_sram_data_ok) begin
                    inst_discard <= inst_discard - 2'b01;
                end
                else if ((inst_discard[1] || inst_discard[0]) && !inst_sram_data_ok) begin
                    inst_discard <= inst_discard;
                end
            end
        end
        else if ((!fs_allowin && ps_ready_go) && (ps_br_taken || ws_cancel_fs)) begin
            if (ps_inst_buf_valid && fs_inst_buf_valid) begin
                inst_discard <= 2'b00;
            end
            else if (fs_inst_buf_valid) begin
                if ((!inst_discard[1] && !inst_discard[0]) && inst_sram_data_ok)
                    inst_discard <= 2'b00;
                else begin
                    inst_discard <= 2'b01;
                end
            end  
            else begin
                if ((!inst_discard[1] && !inst_discard[0]) && !inst_sram_data_ok) begin
                    inst_discard <= 2'b10;
                end
                else if ((!inst_discard[1] && !inst_discard[0]) && inst_sram_data_ok) begin
                    inst_discard <= 2'b01;
                end
                else if ((!inst_discard[1] && inst_discard[0]) && !inst_sram_data_ok) begin
                    inst_discard <= 2'b10;
                end
                else if ((!inst_discard[1] && inst_discard[0]) && inst_sram_data_ok) begin
                    inst_discard <= 2'b01;
                end
                else if ((inst_discard[1] || inst_discard[0]) && inst_sram_data_ok) begin
                    inst_discard <= inst_discard;
                end
                else if ((inst_discard[1] || inst_discard[0]) && !inst_sram_data_ok) begin
                    inst_discard <= inst_discard + 2'b01;
                end
            end
        end
        else if (inst_sram_data_ok && (inst_discard != 2'b00)) begin
            inst_discard <= inst_discard - 2'b01;
        end
    end

	// IF stage
	assign fs_ready_go    = (fs_finish || inst_sram_data_ok || fs_inst_buf_valid) && !inst_discard[1];
	assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
	assign fs_to_ds_valid =  fs_valid && fs_ready_go && !ps_br_taken && !ws_cancel_fs && !(|inst_discard);
	always @(posedge clk)
	begin
	    if (reset)
		begin
	        fs_valid <= 1'b0;
	    end
	    else if (fs_allowin)
		begin
	        fs_valid <= ps_to_fs_valid;
	    end

	    if (reset)
		begin
	        fs_pc <= 32'h1bfffffc;  //trick: to make nextpc be 0x1c000000 during reset 
	    end
	    else if (ps_to_fs_valid && fs_allowin)
		begin
	        fs_pc <= nextpc;
	    end

        if (reset) begin
            fs_finish <= 1'b0;
        end
        else if (inst_sram_data_ok && !ds_allowin) begin
            fs_finish <= 1'b1;
        end
        else if (ds_allowin) begin
            fs_finish <= 1'b0;
        end
	end
	
	// inst sram
    always @(posedge clk) begin
        if (reset) begin
            fs_inst_buf <= 32'b0;
        end
        else if (inst_sram_data_ok && !fs_inst_buf_valid) begin
            fs_inst_buf <= inst_sram_rdata;
        end
        else if (fs_to_ds_valid && ds_allowin) begin
            if (ps_inst_buf_valid) begin
                fs_inst_buf <= ps_inst_buf;
            end
            else if (inst_sram_data_ok) begin
                fs_inst_buf <= inst_sram_rdata;
            end
        end

        if (reset) begin
            fs_inst_buf_valid <= 1'b0;
        end
        else if (ps_br_taken || ws_cancel_fs) begin
            fs_inst_buf_valid <= 1'b0;
        end
        else if (inst_sram_data_ok && !fs_allowin && !(|inst_discard)) begin
            fs_inst_buf_valid <= 1'b1;
        end
        else if (fs_to_ds_valid && ds_allowin) begin
            if (ps_inst_buf_valid) begin
                fs_inst_buf_valid <= 1'b1;
            end
            else if (inst_sram_data_ok && fs_inst_buf_valid) begin
                fs_inst_buf_valid <= 1'b1;
            end
            else begin
                fs_inst_buf_valid <= 1'b0;
            end
        end
    end
    
	assign inst_sram_req   = ~reset && !ps_finish && !br_stall;
	assign inst_sram_wr    = 1'b0;
	assign inst_sram_wen   = 4'h0;
	assign inst_sram_size  = 2'b10;
	assign inst_sram_addr  = {nextpc[31:2],2'b00};
	assign inst_sram_wdata = 32'b0;
	
    assign fs_inst         = fs_inst_buf_valid ? fs_inst_buf 
                           : inst_sram_rdata;

    // exception
	assign faddr_error     = (fs_pc[1] | fs_pc[0]);//TLB is ignored here
	assign fs_ex           = faddr_error & fs_valid;
    assign fs_ecode        = faddr_error ? `ECODE_ADE : `ECODE_UNKNOWN;
    assign fs_esubcode     = faddr_error ? `ESUBCODE_ADEF : `ESUBCODE_UNKNOWN;
    
endmodule
