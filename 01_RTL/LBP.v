`timescale 1ns/1ps
module LBP # (
    parameter DATA_WIDTH = 8,              // AXI4 data width
    parameter ADDR_WIDTH = 15,             // AXI4 address width
    parameter STRB_WIDTH = (DATA_WIDTH/8)  // AXI4 strobe width
)
(
    // Clock and synchronous high reset
    input                   clk_A,
    input                   clk_B,
    input                   rst,

    input                   start,
    output                  finish,

    // Data AXI4 master interface
    output [ADDR_WIDTH-1:0] data_awaddr,
    output [           7:0] data_awlen,
    output [           2:0] data_awsize,
    output [           1:0] data_awburst,
    output                  data_awvalid,
    input                   data_awready,
    output [DATA_WIDTH-1:0] data_wdata,
    output [STRB_WIDTH-1:0] data_wstrb,
    output                  data_wlast,
    output                  data_wvalid,
    input                   data_wready,
    // input  [           1:0] data_bresp,
    // input                   data_bvalid,
    // output                  data_bready,
    output [ADDR_WIDTH-1:0] data_araddr,
    output [           7:0] data_arlen,
    output [           2:0] data_arsize,
    output [           1:0] data_arburst,
    output                  data_arvalid,
    input                   data_arready,
    input  [DATA_WIDTH-1:0] data_rdata,
    input  [           1:0] data_rresp,
    input                   data_rlast,
    input                   data_rvalid,
    output                  data_rready
);

    // FSM

    localparam S_IDLE   = 3'b000;
    localparam S_RSHAKE = 3'b001;
    localparam S_RDATA  = 3'b010;
    localparam S_WSHAKE = 3'b011;
    localparam S_WDATA  = 3'b100;
    localparam S_DONE   = 3'b101;
    reg [2:0] state_r, state_w;

    reg [7:0] cnt_r, cnt_w;
    reg [6:0] row_cnt_r, row_cnt_w;        // count of rows processed (0 to 127)
    reg [6:0] col_cnt_r, col_cnt_w;        // count of columns processed (0 to 127)

    // lbp calculation
    reg  [7:0] data_r [0:8], data_w [0:8];                 // [0] [1] [2]
    wire [7:0] lbp_0_w, lbp_90_w, lbp_180_w, lbp_270_w;    // [7] [8] [3]
    wire       lbp_flag_w [0:8];                           // [6] [5] [4]
    wire [7:0] lbp_min1_w, lbp_min2_w, lbp_min_w;;
    
    integer i;
    genvar j;
    generate
        for (j = 0; j < 9; j = j + 1) begin : LBP_CALC
            assign lbp_flag_w[j] = (data_r[j] >= data_r[8]) ? 1 : 0;
        end
    endgenerate
    assign lbp_0_w   = {lbp_flag_w[7], lbp_flag_w[6], lbp_flag_w[5], lbp_flag_w[4], lbp_flag_w[3], lbp_flag_w[2], lbp_flag_w[1], lbp_flag_w[0]};
    assign lbp_90_w  = {lbp_flag_w[5], lbp_flag_w[4], lbp_flag_w[3], lbp_flag_w[2], lbp_flag_w[1], lbp_flag_w[0], lbp_flag_w[7], lbp_flag_w[6]};
    assign lbp_180_w = {lbp_flag_w[3], lbp_flag_w[2], lbp_flag_w[1], lbp_flag_w[0], lbp_flag_w[7], lbp_flag_w[6], lbp_flag_w[5], lbp_flag_w[4]};
    assign lbp_270_w = {lbp_flag_w[1], lbp_flag_w[0], lbp_flag_w[7], lbp_flag_w[6], lbp_flag_w[5], lbp_flag_w[4], lbp_flag_w[3], lbp_flag_w[2]};
    assign lbp_min1_w = (lbp_0_w < lbp_90_w) ? lbp_0_w : lbp_90_w;
    assign lbp_min2_w = (lbp_180_w < lbp_270_w) ? lbp_180_w : lbp_270_w;
    assign lbp_min_w  = (lbp_min1_w < lbp_min2_w) ? lbp_min1_w : lbp_min2_w;

    // AXI control signals
    // reg                   data_awvalid_r, data_awvalid_w;
    // reg                   data_awready_r, data_awready_w;

    // reg                   data_wvalid_r, data_wvalid_w;
    // reg                   data_wready_r, data_wready_w;
    // reg                   data_wlast_r, data_wlast_w;
    
    // reg                   data_arvalid_r, data_arvalid_w;
    // reg                   data_arready_r, data_arready_w;
    
    // reg                   data_rready_r, data_rready_w;
    reg  [2:0]            axi_read_cnt_r, axi_read_cnt_w;   // count of AXI read transactions (0 to 3)
    reg  [ADDR_WIDTH-1:0] axi_read_addr_r, axi_read_addr_w;
    reg  [ADDR_WIDTH  :0] axi_write_addr_r, axi_write_addr_w;
    reg  [DATA_WIDTH-1:0] axi_write_data_r, axi_write_data_w;
    wire [1:0]            axi_read_len_w = (col_cnt_r == 127 || col_cnt_r == 0) ? 1 : 2;  // read 2 pixel for first and last column, otherwise read 3 pixels

    assign data_awaddr  = axi_write_addr_r + 16384;
    assign data_awlen   = 0;
    assign data_awsize  = 3'b000;  // 8-bit
    assign data_awburst = 2'b01;   // INCR
    assign data_awvalid = (state_r == S_WSHAKE);

    assign data_wdata   = axi_write_data_r;
    assign data_wstrb   = {STRB_WIDTH{1'b1}};        // always write 1 byte
    assign data_wlast   = (state_r == S_WDATA);
    assign data_wvalid  = (state_r == S_WDATA);

    assign data_araddr  = axi_read_addr_r;
    assign data_arlen   = axi_read_len_w;
    assign data_arsize  = 3'b000;  // 8-bit
    assign data_arburst = 2'b01;   // INCR
    assign data_arvalid = (state_r == S_RSHAKE);

    assign data_rready  = (state_r == S_RDATA);
    
    // done signal
    reg finish_r, finish_w;

    // CDC synchronization
    reg start_toggle_r;
    reg start_sync1, start_sync2, start_sync3;
    wire start_pulse_B = start_sync2 ^ start_sync3;

    reg finish_toggle_r;
    reg finish_cnt_r;
    reg start_cnt_r;
    assign finish = (finish_cnt_r > 0);

    // clk_A domain

    always @(posedge clk_A or posedge rst) begin
        if (rst) begin
            finish_cnt_r <= 0;
            start_toggle_r <= 0;
            start_cnt_r <= 0;
        end
        else begin
            if (start) begin
                start_toggle_r <= ~start_toggle_r;
            end
            if (finish_toggle_r) begin
                start_cnt_r <= 1;
            end
            if (start_cnt_r || finish_toggle_r) begin
                finish_cnt_r <= finish_cnt_r + 1;
            end
        end
    end

    // clk_B domain

    always @(posedge clk_B or posedge rst) begin
        if (rst) begin
            start_sync1 <= 0;
            start_sync2 <= 0;
            start_sync3 <= 0;
            finish_toggle_r <= 0;
        end
        else begin
            start_sync1 <= start_toggle_r;
            start_sync2 <= start_sync1;
            start_sync3 <= start_sync2;
            if (finish_r) begin
                finish_toggle_r <= ~finish_toggle_r;
            end
        end
    end

    // FSM
    always @(*) begin
        state_w = state_r;
        case (state_r)
            S_IDLE: begin
                if (start_pulse_B) state_w = S_RSHAKE;
            end 
            S_RSHAKE: begin
                state_w = S_RDATA;
            end
            S_RDATA: begin
                if (cnt_r == 8) state_w = S_WSHAKE;
                else if (cnt_r == 5) state_w = S_RSHAKE;
            end
            S_WSHAKE: begin
                if (data_awvalid && data_awready) state_w = S_WDATA;
            end
            S_WDATA: begin
                if (row_cnt_r == 127 && col_cnt_r == 127) state_w = S_DONE;
                else if (row_cnt_r == 126) state_w = S_WSHAKE;
                else state_w = S_RSHAKE;
            end
            S_DONE: begin
                // stay in DONE state
            end
            default: begin end
        endcase
    end

    // counter logic
    always @(*) begin
        cnt_w = cnt_r;
        row_cnt_w = row_cnt_r;
        col_cnt_w = col_cnt_r;
        case (state_r)
            S_IDLE: begin
                if (start_pulse_B) begin
                    cnt_w = 4;
                end
            end 
            S_RSHAKE: begin
                // no change in counters
            end
            S_RDATA: begin
                if (data_rvalid) begin
                    if (col_cnt_r == 0 || col_cnt_r == 127) cnt_w = (cnt_r == 8) ? 7 : cnt_r + 1;
                    else cnt_w = (cnt_r == 8) ? 6 : cnt_r + 1;
                end
            end
            S_WSHAKE: begin
                // no change in counters
            end
            S_WDATA: begin
                row_cnt_w = row_cnt_r + 1;
                col_cnt_w = (row_cnt_r == 127) ? col_cnt_r + 1 : col_cnt_r;
                if (row_cnt_r == 127) begin
                    cnt_w = (col_cnt_r == 126) ? 4 : 3; 
                end
                else begin
                    cnt_w = (row_cnt_r == 126) ? 8 : ((col_cnt_r == 0 || col_cnt_r == 127) ? 7 : 6);
                end
            end
            S_DONE: begin
                // no change in counters
            end
            default: begin end
        endcase
    end

    // data control and AXI control signals
    always @(*) begin
        for (i = 0; i < 9; i = i + 1) begin
            data_w[i] = data_r[i];
        end
        axi_read_cnt_w = axi_read_cnt_r;
        axi_read_addr_w = axi_read_addr_r;
        axi_write_addr_w = axi_write_addr_r;
        axi_write_data_w = axi_write_data_r;
        finish_w = finish_r;
        case (state_r)
            S_IDLE: begin
                if (start_pulse_B) begin
                    data_w[0] = 0;
                    data_w[1] = 0;
                    data_w[2] = 0;
                    data_w[7] = 0;
                    data_w[6] = 0;
                    axi_read_addr_w  = 0;
                end
            end
            S_RSHAKE: begin
                // no change in data
            end
            S_RDATA: begin
                // data capture
                if (data_rvalid) begin
                    if (col_cnt_r == 0) begin
                        case (axi_read_cnt_r)
                            0: begin
                                if (cnt_r == 4) data_w[8] = data_rdata;
                                else data_w[5] = data_rdata;
                            end
                            1: begin
                                if (cnt_r == 5) data_w[3] = data_rdata;
                                else data_w[4] = data_rdata;
                            end
                            default: begin end
                        endcase
                    end
                    else if (col_cnt_r == 127) begin
                        case (axi_read_cnt_r)
                            0: begin
                                if (cnt_r == 4) data_w[7] = data_rdata;
                                else data_w[6] = data_rdata;
                            end
                            1: begin
                                if (cnt_r == 5) data_w[8] = data_rdata;
                                else data_w[5] = data_rdata;
                            end
                            default: begin end
                        endcase
                    end
                    else begin
                        case (axi_read_cnt_r)
                            0: begin
                                if (cnt_r == 3) data_w[7] = data_rdata;
                                else data_w[6] = data_rdata;
                            end
                            1: begin
                                if (cnt_r == 4) data_w[8] = data_rdata;
                                else data_w[5] = data_rdata;
                            end
                            2: begin
                                if (cnt_r == 5) data_w[3] = data_rdata;
                                else data_w[4] = data_rdata;
                            end
                            default: begin end
                        endcase
                    end
                    if (axi_read_cnt_r == axi_read_len_w) begin
                        axi_read_cnt_w = 0;
                        if (row_cnt_r == 126) axi_read_addr_w = col_cnt_r;
                        else axi_read_addr_w = axi_read_addr_r + 128;
                    end
                    else begin
                        axi_read_cnt_w = axi_read_cnt_r + 1;
                    end
                end
            end
            S_WSHAKE: begin
                axi_write_data_w = lbp_min_w;
                if (row_cnt_r == 127 && col_cnt_r == 126) begin
                    data_w[0] = 0;
                    data_w[1] = 0;
                    data_w[2] = 0;
                    data_w[3] = 0;
                    data_w[4] = 0;
                end
                else if (row_cnt_r == 127) begin
                    data_w[0] = 0;
                    data_w[1] = 0;
                    data_w[2] = 0;
                end
                else if (row_cnt_r == 126) begin
                    data_w[4] = 0;
                    data_w[5] = 0;
                    data_w[6] = 0;
                    data_w[0] = data_r[7];
                    data_w[1] = data_r[8];
                    data_w[2] = data_r[3];
                    data_w[7] = data_r[6];
                    data_w[8] = data_r[5];
                    data_w[3] = data_r[4];
                end
                else begin  //  shift data
                    data_w[0] = data_r[7];
                    data_w[1] = data_r[8];
                    data_w[2] = data_r[3];
                    data_w[7] = data_r[6];
                    data_w[8] = data_r[5];
                    data_w[3] = data_r[4];
                end
            end
            S_WDATA: begin
                if (row_cnt_r == 127 && col_cnt_r == 127) finish_w = 1;
                axi_write_addr_w = (row_cnt_r == 127) ? (col_cnt_r + 1) : (axi_write_addr_r + 128); 
            end
            S_DONE: begin
                // stay in DONE state
            end
            default: begin end
        endcase
    end

    always @(posedge clk_B or posedge rst) begin
        if (rst) begin
            axi_read_cnt_r <= 0;
            axi_read_addr_r <= 0;
            axi_write_addr_r <= 0;
            axi_write_data_r <= 0;
            cnt_r <= 0;
            row_cnt_r <= 0;
            col_cnt_r <= 0;
            state_r <= S_IDLE;
            finish_r <= 0;
            for (i = 0; i < 9; i = i + 1) begin
                data_r[i] <= 0;
            end
        end
        else begin
            axi_read_cnt_r <= axi_read_cnt_w;
            axi_read_addr_r <= axi_read_addr_w;
            axi_write_addr_r <= axi_write_addr_w;
            axi_write_data_r <= axi_write_data_w;
            cnt_r <= cnt_w;
            row_cnt_r <= row_cnt_w;
            col_cnt_r <= col_cnt_w;
            state_r <= state_w;
            finish_r <= finish_w;
            for (i = 0; i < 9; i = i + 1) begin
                data_r[i] <= data_w[i];
            end
        end
    end

endmodule