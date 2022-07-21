module mmu(
    input  [31:0] vaddr         ,
    input         is_inst       ,
    input         is_load       ,
    input         is_store      ,
    input  [31:0] csr_crmd      ,
    input  [31:0] csr_asid      ,
    input  [31:0] csr_dmw0      ,
    input  [31:0] csr_dmw1      ,
    output [31:0] paddr         ,
    output [ 5:0] tlb_ex_bus    , // PIL, PIS, PIF, PME, PPI, TLBR

    output [18:0] s_vppn        ,
    output        s_va_bit12    ,
    output [ 9:0] s_asid        ,
    input         s_found       ,
    input  [ 3:0] s_index       ,
    input  [19:0] s_ppn         ,
    input  [ 5:0] s_ps          ,
    input  [ 1:0] s_plv         ,
    input  [ 1:0] s_mat         ,
    input         s_d           ,
    input         s_v           ,

    output        dmw_hit 
);

wire        direct    ;
wire        dmw0_hit  ;
wire        dmw1_hit  ;
wire [31:0] dmw0_paddr;
wire [31:0] dmw1_paddr;
wire [31:0] tlb_paddr ;
wire        ecode_pil ;
wire        ecode_pis ;
wire        ecode_pif ;
wire        ecode_pme ;
wire        ecode_ppi ;
wire        ecode_tlbr;

assign direct     = csr_crmd[`CSR_CRMD_DA] & ~csr_crmd[`CSR_CRMD_PG];
assign dmw0_hit   = csr_dmw0[csr_crmd[`CSR_CRMD_PLV]] && (csr_dmw0[`CSR_DMW0_VSEG] == vaddr[31:29]);
assign dmw1_hit   = csr_dmw1[csr_crmd[`CSR_CRMD_PLV]] && (csr_dmw1[`CSR_DMW1_VSEG] == vaddr[31:29]); 
assign dmw0_paddr = {csr_dmw0[`CSR_DMW0_PSEG],vaddr[28:0]};
assign dmw1_paddr = {csr_dmw1[`CSR_DMW1_PSEG],vaddr[28:0]};
assign dmw_hit    = dmw0_hit | dmw1_hit;

assign ecode_pil  = ~dmw_hit & is_load  & ~s_v;
assign ecode_pis  = ~dmw_hit & is_store & ~s_v;
assign ecode_pif  = ~dmw_hit & is_inst  & ~s_v;
assign ecode_pme  = ~dmw_hit & is_store & ~s_d;
assign ecode_ppi  = ~dmw_hit & (csr_crmd[`CSR_CRMD_PLV] > s_plv) & (is_inst | is_load | is_store); 
assign ecode_tlbr = ~dmw_hit & ~s_found & (is_inst | is_load | is_store);

assign s_vppn     = vaddr[31:13];
assign s_va_bit12 = vaddr[12];
assign s_asid     = csr_asid[9:0];

assign tlb_ex_bus = direct ? 6'b0
                           : {ecode_pil, 
                              ecode_pis, 
                              ecode_pif, 
                              ecode_pme, 
                              ecode_ppi, 
                              ecode_tlbr};

assign tlb_paddr = (s_ps == 6'd12) ? {s_ppn[19: 0],vaddr[11:0]} 
                                   : {s_ppn[19:10],vaddr[21:0]};

assign paddr = direct   ? vaddr
             : dmw0_hit ? dmw0_paddr 
             : dmw1_hit ? dmw1_paddr 
                        : tlb_paddr;
endmodule