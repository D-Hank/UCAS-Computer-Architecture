`include "mycpu.h"

module csr(
    input         clock       ,
    input         reset       ,

    //pipeline interface
    input         csr_we      ,
    input  [13:0] csr_num     ,
    input  [31:0] csr_wmask   ,
    input  [31:0] csr_wvalue  ,
    output [31:0] csr_rvalue  ,
    input         wb_ex       ,
    input  [5:0]  wb_ecode    ,
    input  [8:0]  wb_esubcode ,
    input  [31:0] wb_pc       ,
    input  [31:0] wb_vaddr    ,
    input  [ 7:0] hw_int_in   ,
    input         ipi_int_in  ,
    input         ertn_flush  ,
    output        has_int     ,
    output [31:0] ex_entry    ,

    //tlb interface
    input we,
    input  [`TLB_TO_CSR   -1:0] tlb_to_csr_bus,
    //write and search
    output [`CSR_TO_EXE   -1:0] csr_to_exe_bus,
    output [`CSR_TO_TLB   -1:0] csr_to_tlb_bus
);

    reg  [`CSR_CRMD_PLV    ] csr_crmd_plv;
    reg                      csr_crmd_ie;
    reg                      csr_crmd_da;
    reg                      csr_crmd_pg;
    reg  [`CSR_PRMD_PPLV   ] csr_prmd_pplv;
    reg                      csr_prmd_pie;
    reg  [`CSR_ECFG_LIE    ] csr_ecfg_lie;
    reg  [`CSR_ESTAT_IS    ] csr_estat_is;
    reg  [ 5:0             ] csr_estat_ecode;
    reg  [ 8:0             ] csr_estat_esubcode;
    reg  [`CSR_ERA_PC      ] csr_era_pc;
    reg  [`CSR_BADV_VADDR  ] csr_badv_vaddr;
    reg  [`CSR_EENTRY_VA   ] csr_eentry_va;

    reg  [`CSR_SAVE_DATA   ] csr_save0_data;
    reg  [`CSR_SAVE_DATA   ] csr_save1_data;
    reg  [`CSR_SAVE_DATA   ] csr_save2_data;
    reg  [`CSR_SAVE_DATA   ] csr_save3_data;

    reg  [`CSR_TLBIDX_IDX  ] csr_tlbidx_idx;
    reg  [`CSR_TLBIDX_PS   ] csr_tlbidx_ps;
    reg  [`CSR_TLBIDX_NE   ] csr_tlbidx_ne;
    reg  [`CSR_TLBEHI_VPPN ] csr_tlbehi_vppn;

    reg  [`CSR_TLBELO0_V   ] csr_tlbelo0_v;
    reg  [`CSR_TLBELO0_D   ] csr_tlbelo0_d;
    reg  [`CSR_TLBELO0_PLV ] csr_tlbelo0_plv;
    reg  [`CSR_TLBELO0_MAT ] csr_tlbelo0_mat;
    reg  [`CSR_TLBELO0_G   ] csr_tlbelo0_g;
    reg  [`CSR_TLBELO0_PPN ] csr_tlbelo0_ppn;
    reg  [`CSR_TLBELO0_V   ] csr_tlbelo1_v;
    reg  [`CSR_TLBELO0_D   ] csr_tlbelo1_d;
    reg  [`CSR_TLBELO0_PLV ] csr_tlbelo1_plv;
    reg  [`CSR_TLBELO0_MAT ] csr_tlbelo1_mat;
    reg  [`CSR_TLBELO0_G   ] csr_tlbelo1_g;
    reg  [`CSR_TLBELO0_PPN ] csr_tlbelo1_ppn;

    reg  [`CSR_ASID_ASID   ] csr_asid_asid;
    wire [`CSR_ASID_BITS   ] csr_asid_bits;

    reg  [`CSR_TLBRENTRY_PA] csr_tlbrentry_pa;

    reg  [`CSR_TID_TID     ] csr_tid_tid;
    reg  [`CSR_TCFG_EN     ] csr_tcfg_en;
    reg  [`CSR_TCFG_PRDC   ] csr_tcfg_prdc;
    reg  [`CSR_TCFG_INIT   ] csr_tcfg_init;
    wire [31:             0] csr_tval;
    reg  [31:             0] timer_cnt;
    wire                     csr_ticlr_clr;

    assign has_int = ((csr_estat_is[11:0] & csr_ecfg_lie[11:0])!=12'b0) && (csr_crmd_ie==1'b1);

    //NOTICE: only one period!!!
    wire                     tlbsrch_done;
    wire [`CSR_TLBIDX_IDX ]  tlbsrch_idx_index;
    wire [`CSR_TLBIDX_NE  ]  tlbsrch_idx_ne;

    wire                     tlbrd_done;
    wire [`CSR_TLBEHI_VPPN]  tlbrd_ehi_vppn;
    wire [`CSR_TLBELO0_V  ]  tlbrd_elo0_v;
    wire [`CSR_TLBELO0_D  ]  tlbrd_elo0_d;
    wire [`CSR_TLBELO0_PLV]  tlbrd_elo0_plv;
    wire [`CSR_TLBELO0_MAT]  tlbrd_elo0_mat;
    wire [`CSR_TLBELO0_G  ]  tlbrd_elo0_g;
    wire [`TLB_PPN_WD -1:0]  tlbrd_elo0_ppn;
    wire [`CSR_TLBELO1_V  ]  tlbrd_elo1_v;
    wire [`CSR_TLBELO1_D  ]  tlbrd_elo1_d;
    wire [`CSR_TLBELO1_PLV]  tlbrd_elo1_plv;
    wire [`CSR_TLBELO1_MAT]  tlbrd_elo1_mat;
    wire [`CSR_TLBELO1_G  ]  tlbrd_elo1_g;
    wire [`TLB_PPN_WD -1:0]  tlbrd_elo1_ppn;
    wire [`TLB_ASID_WD-1:0]  tlbrd_asid_asid;
    wire [`TLB_PS_WD  -1:0]  tlbrd_idx_ps;
    wire                     tlbrd_idx_ne;

    assign tlbrd_done = we;
    assign {tlbsrch_done,//96:96
            tlbsrch_idx_index,//95:92
            tlbsrch_idx_ne,//91:91
            tlbrd_done,//90:90
            tlbrd_ehi_vppn,//89:71
            tlbrd_elo0_v,//70:70
            tlbrd_elo0_d,//69:69
            tlbrd_elo0_plv,//68:67
            tlbrd_elo0_mat,//66:65
            tlbrd_elo0_g,//64:64
            tlbrd_elo0_ppn,//63:44
            tlbrd_elo1_v,//43:43
            tlbrd_elo1_d,//42:42
            tlbrd_elo1_plv,//41:40
            tlbrd_elo1_mat,//39:38
            tlbrd_elo1_g,//37:37
            tlbrd_elo1_ppn,//36:17
            tlbrd_asid_asid,//16:7
            tlbrd_idx_ps,//6:1
            tlbrd_idx_ne//0:0
            } = tlb_to_csr_bus;

    //for searching
    //NOTICE: this bus actually goes to MMU
    //so DMW can be submitted here
    assign csr_to_exe_bus = {csr_tlbidx_idx,//32:29
                             csr_tlbehi_vppn,//28:10
                             csr_asid_asid//9:0
                             //DMW
                             };

    assign csr_to_tlb_bus = {csr_estat_ecode,//99:94
                             csr_tlbidx_idx,//93:90
                             csr_tlbidx_ps,//89:84
                             csr_tlbidx_ne,//83:83
                             csr_tlbehi_vppn,//82:64
                             csr_tlbelo0_v,//63:63
                             csr_tlbelo0_d,//62:62
                             csr_tlbelo0_plv,//61:60
                             csr_tlbelo0_mat,//59:58
                             csr_tlbelo0_g,//57:57
                             csr_tlbelo0_ppn,//56:37
                             csr_tlbelo1_v,//36:36
                             csr_tlbelo1_d,//35:35
                             csr_tlbelo1_plv,//34:33
                             csr_tlbelo1_mat,//32:31
                             csr_tlbelo1_g,//30:30
                             csr_tlbelo1_ppn,//29:10
                             csr_asid_asid//9:0
                             };


    //CRMD
    always @(posedge clock)
        begin
        if (reset)
        begin
            csr_crmd_plv <= 2'b0;
        end
        else if (wb_ex)
        begin
            csr_crmd_plv <= 2'b0;
        end
        else if (ertn_flush)
        begin
            csr_crmd_plv <= csr_prmd_pplv;
        end
        else if (csr_we && csr_num==`CSR_CRMD)
        begin
            csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV]
                         | ~csr_wmask[`CSR_CRMD_PLV] & csr_crmd_plv;
        end
    end

    always @(posedge clock)
    begin
        if (reset)
        begin
            csr_crmd_ie <= 1'b0;
        end
        else if (wb_ex)
        begin
            csr_crmd_ie <= 1'b0;        
        end
        else if (ertn_flush)
        begin
            csr_crmd_ie <= csr_prmd_pie;
        end
        else if (csr_we && csr_num==`CSR_CRMD)
        begin
            csr_crmd_ie <= csr_wmask[`CSR_CRMD_IE] & csr_wvalue[`CSR_CRMD_IE]
                        | ~csr_wmask[`CSR_CRMD_IE] & csr_crmd_ie;
        end
    end

    always @(posedge clock)
    begin
        if (reset)
        begin
            csr_crmd_da <= 1'b1;
        end
        else if (wb_ex && wb_ecode==`ECODE_TLBR)
        begin
            csr_crmd_da <= 1'b1;
        end
        else if (ertn_flush && csr_estat_ecode==`ECODE_TLBR)
        begin
            csr_crmd_da <= 1'b0;
        end
        else if (csr_we && csr_num==`CSR_CRMD)
        begin
            csr_crmd_da <= csr_wmask[`CSR_CRMD_DA] & csr_wvalue[`CSR_CRMD_DA]
                        | ~csr_wmask[`CSR_CRMD_DA] & csr_crmd_da;
        end
    end

    always @(posedge clock)
    begin
        if (reset)
        begin
            csr_crmd_pg <= 1'b0;
        end
        else if (wb_ex && wb_ecode==`ECODE_TLBR)
        begin
            csr_crmd_pg <= 1'b0;
        end
        else if (ertn_flush && csr_estat_ecode==`ECODE_TLBR)
        begin
            csr_crmd_pg <= 1'b1;
        end
        else if (csr_we && csr_num==`CSR_CRMD)
        begin
            csr_crmd_pg <= csr_wmask[`CSR_CRMD_PG] & csr_wvalue[`CSR_CRMD_PG]
                        | ~csr_wmask[`CSR_CRMD_PG] & csr_crmd_pg;
        end
    end

    //PRMD
    always @(posedge clock)
    begin
        if (wb_ex)
        begin
            csr_prmd_pplv <= csr_crmd_plv;
            csr_prmd_pie  <= csr_crmd_ie;
        end
        else if (csr_we && csr_num==`CSR_PRMD)
        begin
            csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV] & csr_wvalue[`CSR_PRMD_PPLV]
                        | ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
            csr_prmd_pie  <= csr_wmask[`CSR_PRMD_PIE] & csr_wvalue[`CSR_PRMD_PIE]
                        | ~csr_wmask[`CSR_PRMD_PIE] & csr_prmd_pie;
        end
    end

    //ECGF
    always @(posedge clock)
    begin
        if(reset)
        begin
            csr_ecfg_lie <= 13'b0;
        end
        else if (csr_we && csr_num==`CSR_ECFG)
        begin
            csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE] & csr_wvalue[`CSR_ECFG_LIE]
                        | ~csr_wmask[`CSR_ECFG_LIE] & csr_ecfg_lie;
        end
    end

    //ESTAT
    always @(posedge clock)
    begin
        if (reset)
        begin
            csr_estat_is[1:0] <= 2'b0;        
        end
        else if (csr_we && csr_num==`CSR_ESTAT)
        begin
            csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10] & csr_wvalue[`CSR_ESTAT_IS10]
                            | ~csr_wmask[`CSR_ESTAT_IS10] & csr_estat_is[1:0];        
        end

        csr_estat_is[9:2] <= hw_int_in[7:0];

        csr_estat_is[10] <= 1'b0;

        if (timer_cnt[31:0]==32'b0)
        begin
            csr_estat_is[11] <= 1'b1;
        end
        else if (csr_we && csr_num==`CSR_TICLR && csr_wmask[`CSR_TICLR_CLR] && csr_wvalue[`CSR_TICLR_CLR])
        begin
            csr_estat_is[11] <= 1'b0;
        end

        csr_estat_is[12] <= ipi_int_in;
    end

    always @(posedge clock)
    begin
        if (wb_ex)
        begin
            csr_estat_ecode    <= wb_ecode;
            csr_estat_esubcode <= wb_esubcode;
        end
    end

    //ERA
    always @(posedge clock)
    begin
        if (wb_ex)
        begin
            csr_era_pc <= wb_pc;        
        end
        else if (csr_we && csr_num==`CSR_ERA)
        begin
            csr_era_pc <= csr_wmask[`CSR_ERA_PC] & csr_wvalue[`CSR_ERA_PC]
                    | ~csr_wmask[`CSR_ERA_PC] & csr_era_pc;        
        end
    end

    //BADV
    wire   wb_ex_addr_err;
    assign wb_ex_addr_err = wb_ecode==`ECODE_ADE || wb_ecode==`ECODE_ALE;
    always @(posedge clock)
    begin
        if (wb_ex && wb_ex_addr_err)
        begin
            csr_badv_vaddr <= (wb_ecode==`ECODE_ADE && wb_esubcode==`ESUBCODE_ADEF) ? wb_pc : wb_vaddr;
        end
    end

    //EENTRY
    always @(posedge clock)
    begin
        if (csr_we && csr_num==`CSR_EENTRY)
        begin
            csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA] & csr_wvalue[`CSR_EENTRY_VA]
                        | ~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va;        
        end
    end

    //SAVE0~3
    always @(posedge clock)
    begin
        if (csr_we && csr_num==`CSR_SAVE0)
        begin
            csr_save0_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                        | ~csr_wmask[`CSR_SAVE_DATA] & csr_save0_data;
        end
        if (csr_we && csr_num==`CSR_SAVE1)
        begin
            csr_save1_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                        | ~csr_wmask[`CSR_SAVE_DATA] & csr_save1_data;        
        end
        if (csr_we && csr_num==`CSR_SAVE2)
        begin
            csr_save2_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                        | ~csr_wmask[`CSR_SAVE_DATA] & csr_save2_data;        
        end
        if (csr_we && csr_num==`CSR_SAVE3)
        begin
            csr_save3_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                        | ~csr_wmask[`CSR_SAVE_DATA] & csr_save3_data;        
        end
    end

    //TLBIDX
    always @(posedge clock)
    begin
        if (csr_we && csr_num==`CSR_TLBIDX)
        begin
            csr_tlbidx_idx <= csr_wmask[`CSR_TLBIDX_IDX] & csr_wvalue[`CSR_TLBIDX_IDX]
                            |~csr_wmask[`CSR_TLBIDX_IDX] & csr_tlbidx_idx;
        end
        else if (tlbsrch_done)
        begin
            csr_tlbidx_idx <= {6'b0, tlbsrch_idx_index};
        end
    end

    always @(posedge clock)
    begin
        if (csr_we && csr_num==`CSR_TLBIDX)
        begin
            csr_tlbidx_ps <= csr_wmask[`CSR_TLBIDX_PS] & csr_wvalue[`CSR_TLBIDX_PS]
                          | ~csr_wmask[`CSR_TLBIDX_PS] & csr_tlbidx_ps;
        end
        else if (tlbrd_done & ~tlbrd_idx_ne)
        begin
            csr_tlbidx_ps <= tlbrd_idx_ps;
        end
    end

    always @(posedge clock)
    begin
        if (csr_we && csr_num==`CSR_TLBIDX)
        begin
            csr_tlbidx_ne <= csr_wmask[`CSR_TLBIDX_NE] & csr_wvalue[`CSR_TLBIDX_NE]
                          | ~csr_wmask[`CSR_TLBIDX_NE] & csr_tlbidx_ne;
        end
        else if (tlbrd_done)
        begin
            csr_tlbidx_ne <= tlbrd_idx_ne;
        end
        else if (tlbsrch_done)
        begin
            csr_tlbidx_ne <= tlbsrch_idx_ne;
        end
    end

    //TLBEHI
    always @(posedge clock)
    begin
        if (csr_we && csr_num==`CSR_TLBEHI)
        begin
            csr_tlbehi_vppn <= csr_wmask[`CSR_TLBEHI_VPPN] & csr_wvalue[`CSR_TLBEHI_VPPN]
                            | ~csr_wmask[`CSR_TLBEHI_VPPN] & csr_tlbehi_vppn;
        end
        else if (tlbrd_done & ~tlbrd_idx_ne)
        begin
            csr_tlbehi_vppn <= tlbrd_ehi_vppn;
        end
    end

    //TLBLO
    always @(posedge clock)
    begin
        if (csr_we && csr_num==`CSR_TLBELO0)
        begin
            csr_tlbelo0_v <= csr_wmask[`CSR_TLBELO0_V] & csr_wvalue[`CSR_TLBELO0_V]
                          | ~csr_wmask[`CSR_TLBELO0_V] & csr_tlbelo0_v;
        end
        else if (tlbrd_done & ~tlbrd_idx_ne)
        begin
            csr_tlbelo0_v <= tlbrd_elo0_v;
        end

        if (csr_we && csr_num==`CSR_TLBELO1)
        begin
            csr_tlbelo1_v <= csr_wmask[`CSR_TLBELO1_V] & csr_wvalue[`CSR_TLBELO1_V]
                          | ~csr_wmask[`CSR_TLBELO1_V] & csr_tlbelo1_v;
        end
        else if (tlbrd_done & ~tlbrd_idx_ne)
        begin
            csr_tlbelo1_v <= tlbrd_elo1_v;
        end
    end

    always @(posedge clock)
    begin
        if (csr_we && csr_num==`CSR_TLBELO0)
        begin
            csr_tlbelo0_d <= csr_wmask[`CSR_TLBELO0_D] & csr_wvalue[`CSR_TLBELO0_D]
                          | ~csr_wmask[`CSR_TLBELO0_D] & csr_tlbelo0_d;
        end
        else if (tlbrd_done & ~tlbrd_idx_ne)
        begin
            csr_tlbelo0_d <= tlbrd_elo0_d;
        end

        if (csr_we && csr_num==`CSR_TLBELO1)
        begin
            csr_tlbelo1_d <= csr_wmask[`CSR_TLBELO1_D] & csr_wvalue[`CSR_TLBELO1_D]
                          | ~csr_wmask[`CSR_TLBELO1_D] & csr_tlbelo1_d;
        end
        else if (tlbrd_done & ~tlbrd_idx_ne)
        begin
            csr_tlbelo1_d <= tlbrd_elo1_d;
        end
    end

    always @(posedge clock)
    begin
        if (csr_we && csr_num==`CSR_TLBELO0)
        begin
            csr_tlbelo0_plv <= csr_wmask[`CSR_TLBELO0_PLV] & csr_wvalue[`CSR_TLBELO0_PLV]
                            | ~csr_wmask[`CSR_TLBELO0_PLV] & csr_tlbelo0_plv;
        end
        else if (tlbrd_done & ~tlbrd_idx_ne)
        begin
            csr_tlbelo0_plv <= tlbrd_elo0_plv;
        end

        if (csr_we && csr_num==`CSR_TLBELO1)
        begin
            csr_tlbelo1_plv <= csr_wmask[`CSR_TLBELO1_PLV] & csr_wvalue[`CSR_TLBELO1_PLV]
                            | ~csr_wmask[`CSR_TLBELO1_PLV] & csr_tlbelo1_plv;
        end
        else if (tlbrd_done & ~tlbrd_idx_ne)
        begin
            csr_tlbelo1_plv <= tlbrd_elo1_plv;
        end
    end

    always @(posedge clock)
    begin
        if (csr_we && csr_num==`CSR_TLBELO0)
        begin
            csr_tlbelo0_mat <= csr_wmask[`CSR_TLBELO0_PLV] & csr_wvalue[`CSR_TLBELO0_PLV]
                            | ~csr_wmask[`CSR_TLBELO0_PLV] & csr_tlbelo0_plv;
        end
        else if (tlbrd_done & ~tlbrd_idx_ne)
        begin
            csr_tlbelo0_mat <= tlbrd_elo0_mat;
        end

        if (csr_we && csr_num==`CSR_TLBELO1)
        begin
            csr_tlbelo1_mat <= csr_wmask[`CSR_TLBELO1_PLV] & csr_wvalue[`CSR_TLBELO1_PLV]
                            | ~csr_wmask[`CSR_TLBELO1_PLV] & csr_tlbelo1_plv;
        end
        else if (tlbrd_done & ~tlbrd_idx_ne)
        begin
            csr_tlbelo1_mat <= tlbrd_elo1_mat;
        end
    end

    always @(posedge clock)
    begin
        if (csr_we && csr_num==`CSR_TLBELO0)
        begin
            csr_tlbelo0_g <= csr_wmask[`CSR_TLBELO0_G] & csr_wvalue[`CSR_TLBELO0_G]
                          | ~csr_wmask[`CSR_TLBELO0_G] & csr_tlbelo0_g;
        end
        else if (tlbrd_done & ~tlbrd_idx_ne)
        begin
            csr_tlbelo0_g <= tlbrd_elo0_g;
        end

        if (csr_we && csr_num==`CSR_TLBELO1)
        begin
            csr_tlbelo1_g <= csr_wmask[`CSR_TLBELO1_G] & csr_wvalue[`CSR_TLBELO1_G]
                          | ~csr_wmask[`CSR_TLBELO1_G] & csr_tlbelo1_g;
        end
        else if (tlbrd_done & ~tlbrd_idx_ne)
        begin
            csr_tlbelo1_g <= tlbrd_elo1_g;
        end
    end

    always @(posedge clock)
    begin
        if (csr_we && csr_num==`CSR_TLBELO0)
        begin
            csr_tlbelo0_ppn <= csr_wmask[`CSR_TLBELO0_PPN] & csr_wvalue[`CSR_TLBELO0_PPN]
                            | ~csr_wmask[`CSR_TLBELO0_PPN] & csr_tlbelo0_ppn;
        end
        else if (tlbrd_done & ~tlbrd_idx_ne)
        begin
            csr_tlbelo0_ppn <= tlbrd_elo0_ppn;
        end

        if (csr_we && csr_num==`CSR_TLBELO1)
        begin
            csr_tlbelo1_ppn <= csr_wmask[`CSR_TLBELO1_PPN] & csr_wvalue[`CSR_TLBELO1_PPN]
                            | ~csr_wmask[`CSR_TLBELO1_PPN] & csr_tlbelo1_ppn;
        end
        else if (tlbrd_done & ~tlbrd_idx_ne)
        begin
            csr_tlbelo1_ppn <= tlbrd_elo1_ppn;
        end
    end

    //ASID
    always @(posedge clock)
    begin
        if (csr_we && csr_num==`CSR_ASID)
        begin
            csr_asid_asid <= csr_wmask[`CSR_ASID_ASID] & csr_wvalue[`CSR_ASID_ASID]
                          | ~csr_wmask[`CSR_ASID_ASID] & csr_asid_asid;
        end
        else if (tlbrd_done & ~tlbrd_idx_ne)
        begin
            csr_asid_asid <= tlbrd_asid_asid;
        end
    end
    assign csr_asid_bits = 4'd10;

    //TLBRENTRY
    always @(posedge clock)
    begin
        if (csr_we && csr_num==`CSR_TLBRENTRY)
        begin
            csr_tlbrentry_pa <= csr_wmask[`CSR_TLBRENTRY_PA] & csr_wvalue[`CSR_TLBRENTRY_PA]
                             | ~csr_wmask[`CSR_TLBRENTRY_PA] & csr_tlbrentry_pa;
        end
    end

    //TID
    wire   core_id_in;
    assign core_id_in = 32'b0;
    always @(posedge clock)
    begin
        if(reset)
        begin
            csr_tid_tid <= core_id_in;
        end
        else if(csr_we && csr_num==`CSR_TID)
        begin
            csr_tid_tid <= csr_wmask[`CSR_TID_TID] & csr_wvalue[`CSR_TID_TID]
                        | ~csr_wmask[`CSR_TID_TID] & csr_wvalue[`CSR_TID_TID];
        end
    end

    //TCFG
    always @(posedge clock)
    begin
        if(reset)
        begin
            csr_tcfg_en <= 1'b0;
        end
        else if(csr_we && csr_num==`CSR_TCFG)
        begin
            csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN] & csr_wvalue[`CSR_TCFG_EN]
                        | ~csr_wmask[`CSR_TCFG_EN] & csr_wvalue[`CSR_TCFG_EN];
        end

        if(csr_we && csr_num==`CSR_TCFG)
        begin
            csr_tcfg_prdc <= csr_wmask[`CSR_TCFG_PRDC] & csr_wvalue[`CSR_TCFG_PRDC]
                        | ~csr_wmask[`CSR_TCFG_PRDC] & csr_wvalue[`CSR_TCFG_PRDC];

            csr_tcfg_init <= csr_wmask[`CSR_TCFG_INIT] & csr_wvalue[`CSR_TCFG_INIT]
                        | ~csr_wmask[`CSR_TCFG_INIT] & csr_wvalue[`CSR_TCFG_INIT];
        end
    end

    //TVAL
    wire [31:0] tcfg_next_value;
    assign tcfg_next_value = csr_wmask[31:0] & csr_wvalue[31:0]
                        | ~csr_wmask[31:0] & {csr_tcfg_init, csr_tcfg_prdc, csr_tcfg_en};

    always @(posedge clock)
    begin
        if(reset)
        begin
            timer_cnt <= 32'hFFFFFFFF;
        end
        else if(csr_we && csr_num==`CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
        begin
            timer_cnt <= {tcfg_next_value[`CSR_TCFG_INIT], 2'b0};
        end
        else if(csr_tcfg_en && timer_cnt!=32'hFFFFFFFF)
        begin
            if(timer_cnt[31:0]==32'b0 && csr_tcfg_prdc)
            begin
                timer_cnt <= {csr_tcfg_init, 2'b0};
            end
            else
            begin
                timer_cnt <= timer_cnt - 1'b1;
            end
        end
    end
    assign csr_tval = timer_cnt[31:0];

    //TICLR
    assign csr_ticlr_clr = 1'b0;

    //read data
    wire [31:0] csr_crmd_rvalue      = {27'b0, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
    wire [31:0] csr_prmd_rvalue      = {29'b0, csr_prmd_pie, csr_prmd_pplv};
    wire [31:0] csr_ecfg_rvalue      = {19'b0, csr_ecfg_lie};
    wire [31:0] csr_estat_rvalue     = {1'b0 , csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};
    wire [31:0] csr_era_rvalue       = csr_era_pc;
    wire [31:0] csr_badv_rvalue      = csr_badv_vaddr;
    wire [31:0] csr_eentry_rvalue    = {csr_eentry_va, 6'b0}; 
    wire [31:0] csr_save0_rvalue     = csr_save0_data;
    wire [31:0] csr_save1_rvalue     = csr_save1_data;
    wire [31:0] csr_save2_rvalue     = csr_save2_data;
    wire [31:0] csr_save3_rvalue     = csr_save3_data;
    wire [31:0] csr_tlbidx_rvalue    = {csr_tlbidx_ne, 1'b0, csr_tlbidx_ps, 8'b0, 12'b0, csr_tlbidx_idx};
    wire [31:0] csr_tlbehi_rvalue    = {csr_tlbehi_vppn, 13'b0};
    wire [31:0] csr_tlbelo0_rvalue   = {csr_tlbelo0_ppn, 1'b0, csr_tlbelo0_g, csr_tlbelo0_mat, csr_tlbelo0_plv, csr_tlbelo0_d, csr_tlbelo0_v};
    wire [31:0] csr_tlbelo1_rvalue   = {csr_tlbelo1_ppn, 1'b0, csr_tlbelo1_g, csr_tlbelo1_mat, csr_tlbelo1_plv, csr_tlbelo1_d, csr_tlbelo1_v};
    wire [31:0] csr_asid_rvalue      = {8'b0, csr_asid_bits, 6'b0, csr_asid_asid};
    wire [31:0] csr_tlbrentry_rvalue = {csr_tlbrentry_pa, 6'b0};
    wire [31:0] csr_tid_rvalue       = csr_tid_tid;
    wire [31:0] csr_tcfg_rvalue      = {csr_tcfg_init, csr_tcfg_prdc, csr_tcfg_en};
    wire [31:0] csr_tval_rvalue      = csr_tval;
    wire [31:0] csr_ticlr_rvalue     = {31'b0, csr_ticlr_clr};

    assign ex_entry   = csr_eentry_rvalue;

    assign csr_rvalue = {32{csr_num==`CSR_CRMD     }} & csr_crmd_rvalue
                      | {32{csr_num==`CSR_PRMD     }} & csr_prmd_rvalue
                      | {32{csr_num==`CSR_ECFG     }} & csr_ecfg_rvalue
                      | {32{csr_num==`CSR_ESTAT    }} & csr_estat_rvalue
                      | {32{csr_num==`CSR_ERA      }} & csr_era_rvalue
                      | {32{csr_num==`CSR_BADV     }} & csr_badv_rvalue
                      | {32{csr_num==`CSR_EENTRY   }} & csr_eentry_rvalue
                      | {32{csr_num==`CSR_SAVE0    }} & csr_save0_rvalue
                      | {32{csr_num==`CSR_SAVE1    }} & csr_save1_rvalue
                      | {32{csr_num==`CSR_SAVE2    }} & csr_save2_rvalue
                      | {32{csr_num==`CSR_SAVE3    }} & csr_save3_rvalue
                      | {32{csr_num==`CSR_TLBIDX   }} & csr_tlbidx_rvalue
                      | {32{csr_num==`CSR_TLBEHI   }} & csr_tlbehi_rvalue
                      | {32{csr_num==`CSR_TLBELO0  }} & csr_tlbelo0_rvalue
                      | {32{csr_num==`CSR_TLBELO1  }} & csr_tlbelo1_rvalue
                      | {32{csr_num==`CSR_ASID     }} & csr_asid_rvalue
                      | {32{csr_num==`CSR_TLBRENTRY}} & csr_tlbrentry_rvalue
                      | {32{csr_num==`CSR_TID      }} & csr_tid_rvalue
                      | {32{csr_num==`CSR_TCFG     }} & csr_tcfg_rvalue
                      | {32{csr_num==`CSR_TVAL     }} & csr_tval_rvalue
                      | {32{csr_num==`CSR_TICLR    }} & csr_ticlr_rvalue;

endmodule