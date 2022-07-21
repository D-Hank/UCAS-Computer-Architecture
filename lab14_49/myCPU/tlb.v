module tlb
#(parameter TLBNUM = 16)
(
    input                       clk,
    input                       rst,
    // search port 0 (for fetch)
    input  [`TLB_VPPN_WD  -1:0] s0_vppn,
    input                       s0_va_bit12,
    input  [`TLB_ASID_WD  -1:0] s0_asid,
    output                      s0_found,
    output [$clog2(TLBNUM)-1:0] s0_index,
    output [`TLB_PPN_WD   -1:0] s0_ppn,
    output [`TLB_PS_WD    -1:0] s0_ps,
    output [`TLB_PLV_WD   -1:0] s0_plv,
    output [`TLB_MAT_WD   -1:0] s0_mat,
    output                      s0_d,
    output                      s0_v,

    // search port 1 (for load/store)
    input                       tlbsrch_valid,
    output                      tlbsrch_done,
    input  [`TLB_VPPN_WD  -1:0] s1_vppn,//also for inv
    input                       s1_va_bit12,
    input  [`TLB_ASID_WD  -1:0] s1_asid,//also for inv
    output                      s1_found,
    output [$clog2(TLBNUM)-1:0] s1_index,
    output [`TLB_PPN_WD   -1:0] s1_ppn,
    output [`TLB_PS_WD    -1:0] s1_ps,
    output [`TLB_PLV_WD   -1:0] s1_plv,
    output [`TLB_MAT_WD   -1:0] s1_mat,
    output                      s1_d,
    output                      s1_v,

    // invtlb opcode
    input                       invtlb_valid,
    input  [`TLB_INV_OP_WD-1:0] invtlb_op,

    // write port
    input                       tlbwr_valid,
    input                       tlbfill_valid,
    input  [$clog2(TLBNUM)-1:0] w_index,
    input                       w_e,
    input  [`TLB_VPPN_WD  -1:0] w_vppn,
    input  [`TLB_PS_WD    -1:0] w_ps,
    input  [`TLB_ASID_WD  -1:0] w_asid,
    input                       w_g,
    input  [`TLB_PPN_WD   -1:0] w_ppn0,
    input  [`TLB_PLV_WD   -1:0] w_plv0,
    input  [`TLB_MAT_WD   -1:0] w_mat0,
    input                       w_d0,
    input                       w_v0,
    input  [`TLB_PPN_WD   -1:0] w_ppn1,
    input  [`TLB_PLV_WD   -1:0] w_plv1,
    input  [`TLB_MAT_WD   -1:0] w_mat1,
    input                       w_d1,
    input                       w_v1,

    // read port
    input                       tlbrd_valid,
    output                      tlbrd_done,
    input  [$clog2(TLBNUM)-1:0] r_index,
    output                      r_e,
    output [`TLB_VPPN_WD  -1:0] r_vppn,
    output [`TLB_PS_WD    -1:0] r_ps,
    output [`TLB_ASID_WD  -1:0] r_asid,
    output                      r_g,
    output [`TLB_PPN_WD   -1:0] r_ppn0,
    output [`TLB_PLV_WD   -1:0] r_plv0,
    output [`TLB_MAT_WD   -1:0] r_mat0,
    output                      r_d0,
    output                      r_v0,
    output [`TLB_PPN_WD   -1:0] r_ppn1,
    output [`TLB_PLV_WD   -1:0] r_plv1,
    output [`TLB_MAT_WD   -1:0] r_mat1,
    output                      r_d1,
    output                      r_v1
);

    reg [ TLBNUM      - 1:0] tlb_e;
    reg [ TLBNUM      - 1:0] tlb_ps4MB; //pagesize 1:4MB, 0:4KB
    reg [`TLB_VPPN_WD - 1:0] tlb_vppn   [TLBNUM-1:0];
    reg [`TLB_ASID_WD - 1:0] tlb_asid   [TLBNUM-1:0];
    reg                      tlb_g      [TLBNUM-1:0];
    reg [`TLB_PPN_WD  - 1:0] tlb_ppn0   [TLBNUM-1:0];
    reg [`TLB_PLV_WD  - 1:0] tlb_plv0   [TLBNUM-1:0];
    reg [`TLB_MAT_WD  - 1:0] tlb_mat0   [TLBNUM-1:0];
    reg                      tlb_d0     [TLBNUM-1:0];
    reg                      tlb_v0     [TLBNUM-1:0];
    reg [`TLB_PPN_WD  - 1:0] tlb_ppn1   [TLBNUM-1:0];
    reg [`TLB_PLV_WD  - 1:0] tlb_plv1   [TLBNUM-1:0];
    reg [`TLB_MAT_WD  - 1:0] tlb_mat1   [TLBNUM-1:0];
    reg                      tlb_d1     [TLBNUM-1:0];
    reg                      tlb_v1     [TLBNUM-1:0];

    //SEARCH 0
    wire [TLBNUM-1:0] match0;
    wire        s0_oddpage;
    generate
        genvar i;
        for(i=0;i<TLBNUM;i=i+1)
        begin: match0_gen
            assign match0[i] = tlb_e[i] && (s0_vppn[18:10]==tlb_vppn[i][18:10]) && (tlb_ps4MB[i] || s0_vppn[9:0]==tlb_vppn[i][9:0]) && ((s0_asid==tlb_asid[i]) || tlb_g[i]);
        end
    endgenerate

    assign s0_found = | match0;
    assign s0_index = ({4{match0[ 0]}} & 4'd00)
                    | ({4{match0[ 1]}} & 4'd01)
                    | ({4{match0[ 2]}} & 4'd02)
                    | ({4{match0[ 3]}} & 4'd03)
                    | ({4{match0[ 4]}} & 4'd04)
                    | ({4{match0[ 5]}} & 4'd05)
                    | ({4{match0[ 6]}} & 4'd06)
                    | ({4{match0[ 7]}} & 4'd07)
                    | ({4{match0[ 8]}} & 4'd08)
                    | ({4{match0[ 9]}} & 4'd09)
                    | ({4{match0[10]}} & 4'd10)
                    | ({4{match0[11]}} & 4'd11)
                    | ({4{match0[12]}} & 4'd12)
                    | ({4{match0[13]}} & 4'd13)
                    | ({4{match0[14]}} & 4'd14)
                    | ({4{match0[15]}} & 4'd15);

    assign s0_oddpage = tlb_ps4MB[s0_index] ? s0_vppn[9] : s0_va_bit12;

    assign s0_ps    = tlb_ps4MB[s0_index] ? 6'd22 : 6'd12;
    assign s0_ppn   = s0_oddpage ? tlb_ppn1[s0_index] : tlb_ppn0[s0_index];
    assign s0_plv   = s0_oddpage ? tlb_plv1[s0_index] : tlb_plv0[s0_index];
    assign s0_mat   = s0_oddpage ? tlb_mat1[s0_index] : tlb_mat0[s0_index];
    assign s0_d     = s0_oddpage ? tlb_d1  [s0_index] : tlb_d0  [s0_index];
    assign s0_v     = s0_oddpage ? tlb_v1  [s0_index] : tlb_v0  [s0_index];


    //SEARCH 1
    wire [TLBNUM-1:0] match1;
    wire        s1_oddpage;  

    generate
        genvar j;
        for(j=0;j<TLBNUM;j=j+1)
        begin: match1_gen
            assign match1[j] = tlb_e[j] && (s1_vppn[18:10]==tlb_vppn[j][18:10]) && (tlb_ps4MB[j] || s1_vppn[9:0]==tlb_vppn[j][9:0]) && ((s1_asid==tlb_asid[j]) || tlb_g[j]);
        end
    endgenerate

    assign s1_found = | match1;
    assign s1_index = ({4{match1[ 0]}} & 4'd00)
                    | ({4{match1[ 1]}} & 4'd01)
                    | ({4{match1[ 2]}} & 4'd02)
                    | ({4{match1[ 3]}} & 4'd03)
                    | ({4{match1[ 4]}} & 4'd04)
                    | ({4{match1[ 5]}} & 4'd05)
                    | ({4{match1[ 6]}} & 4'd06)
                    | ({4{match1[ 7]}} & 4'd07)
                    | ({4{match1[ 8]}} & 4'd08)
                    | ({4{match1[ 9]}} & 4'd09)
                    | ({4{match1[10]}} & 4'd10)
                    | ({4{match1[11]}} & 4'd11)
                    | ({4{match1[12]}} & 4'd12)
                    | ({4{match1[13]}} & 4'd13)
                    | ({4{match1[14]}} & 4'd14)
                    | ({4{match1[15]}} & 4'd15);

    assign s1_oddpage = tlb_ps4MB[s1_index] ? s1_vppn[9] : s1_va_bit12;

    assign s1_ps    = tlb_ps4MB[s1_index] ? 6'd22 : 6'd12;
    assign s1_ppn   = s1_oddpage ? tlb_ppn1[s1_index] : tlb_ppn0[s1_index];
    assign s1_plv   = s1_oddpage ? tlb_plv1[s1_index] : tlb_plv0[s1_index];
    assign s1_mat   = s1_oddpage ? tlb_mat1[s1_index] : tlb_mat0[s1_index];
    assign s1_d     = s1_oddpage ? tlb_d1  [s1_index] : tlb_d0  [s1_index];
    assign s1_v     = s1_oddpage ? tlb_v1  [s1_index] : tlb_v0  [s1_index];


    // INVTLB
    wire [15:0] inv_match;
    wire [15:0] asid_match;
    wire [15:0] vppn_match;

    generate
        genvar k;
        for(k=0;k<TLBNUM;k=k+1)
        begin: asid_match_gen
            assign asid_match[k] = s1_asid==tlb_asid[k];
        end
    endgenerate

    generate
        genvar l;
        for(l=0;l<TLBNUM;l=l+1)
        begin: vppn_match_gen
            assign vppn_match[l] = (s1_vppn[18:10]==tlb_vppn[l][18:10]) && (tlb_ps4MB[l] || s1_vppn[9:0]==tlb_vppn[l][9:0]);
        end
    endgenerate

    generate
        genvar m;
        for(m=0;m<TLBNUM;m=m+1)
        begin: inv_match_gen
            assign inv_match[m] = (invtlb_op==5'd0)
                               || (invtlb_op==5'd1)
                               || (invtlb_op==5'd2 &&  tlb_g[m])
                               || (invtlb_op==5'd3 && ~tlb_g[m])
                               || (invtlb_op==5'd4 && ~tlb_g[m] && asid_match[m])
                               || (invtlb_op==5'd5 && ~tlb_g[m] && asid_match[m]  && vppn_match[m])
                               || (invtlb_op==5'd6 && (tlb_g[m] || asid_match[m]) && vppn_match[m]);

        end
    endgenerate

    always @(posedge clk)
    begin
        if (invtlb_valid)
        begin
            tlb_e <= ~inv_match & tlb_e;
        end
        else if (tlbwr_valid | tlbfill_valid)
        begin
            tlb_e[wr_addr] <= w_e;
        end
    end

    // REFILL
    reg  [$clog2(TLBNUM)-1:0] replace_addr;
    wire [$clog2(TLBNUM)-1:0] wr_addr;
    always @(posedge clk)
    begin
        if (rst)
        begin
            replace_addr <= 4'b0;
        end
        else if (tlbfill_valid)
        begin
            replace_addr <= replace_addr + 1'b1;
        end
    end
    assign wr_addr = tlbwr_valid ? w_index : replace_addr;

    // WRITE
    always @(posedge clk)
    begin
        if (tlbwr_valid | tlbfill_valid)
        begin
            tlb_vppn [wr_addr] <= w_vppn;
            tlb_ps4MB[wr_addr] <= w_ps == 5'd22;
            tlb_asid [wr_addr] <= w_asid;
            tlb_g    [wr_addr] <= w_g;
            tlb_ppn0 [wr_addr] <= w_ppn0;
            tlb_plv0 [wr_addr] <= w_plv0;
            tlb_mat0 [wr_addr] <= w_mat0;
            tlb_d0   [wr_addr] <= w_d0;
            tlb_v0   [wr_addr] <= w_v0;
            tlb_ppn1 [wr_addr] <= w_ppn1;
            tlb_plv1 [wr_addr] <= w_plv1;
            tlb_mat1 [wr_addr] <= w_mat1;
            tlb_d1   [wr_addr] <= w_d1;
            tlb_v1   [wr_addr] <= w_v1;
        end
    end

    // READ
    assign r_e    = tlb_e    [r_index];
    assign r_vppn = tlb_vppn [r_index];
    assign r_ps   = tlb_ps4MB[r_index] ? 6'd22 : 6'd12;
    assign r_asid = tlb_asid [r_index];
    assign r_g    = tlb_g    [r_index];
    assign r_ppn0 = tlb_ppn0 [r_index];
    assign r_plv0 = tlb_plv0 [r_index];
    assign r_mat0 = tlb_mat0 [r_index];
    assign r_d0   = tlb_d0   [r_index];
    assign r_v0   = tlb_v0   [r_index];
    assign r_ppn1 = tlb_ppn1 [r_index];
    assign r_plv1 = tlb_plv1 [r_index];
    assign r_mat1 = tlb_mat1 [r_index];
    assign r_d1   = tlb_d1   [r_index];
    assign r_v1   = tlb_v1   [r_index];

    assign tlbrd_done   = tlbrd_valid;
    assign tlbsrch_done = tlbsrch_valid;

endmodule
