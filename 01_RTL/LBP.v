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

    AXI_MASTER #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .STRB_WIDTH(STRB_WIDTH)
    ) axi_master_inst (
        .clk(clk_A),
        .rst(rst),
        .read_start(read_start_r),
        .write_start(write_start_r),
        .finish(axi_finish),
        .read_addr(axi_read_addr_r),
        .read_len(axi_read_len_w),
        .write_addr(axi_write_addr_r),
        .write_len(0),
        .write_data(axi_write_data_r),
        .read_data(read_data_w),
        .read_valid(read_valid_w),
        .data_awaddr(data_awaddr),
        .data_awlen(data_awlen),
        .data_awsize(data_awsize),
        .data_awburst(data_awburst),
        .data_awvalid(data_awvalid),
        .data_awready(data_awready),
        .data_wdata(data_wdata),
        .data_wstrb(data_wstrb),
        .data_wlast(data_wlast),
        .data_wvalid(data_wvalid),
        .data_wready(data_wready),
        .data_araddr(data_araddr),
        .data_arlen(data_arlen),
        .data_arsize(data_arsize),
        .data_arburst(data_arburst),
        .data_arvalid(data_arvalid),
        .data_arready(data_arready),
        .data_rdata(data_rdata),
        .data_rresp(data_rresp),
        .data_rlast(data_rlast),
        .data_rvalid(data_rvalid),
        .data_rready(data_rready)
    );

    // FSM

    localparam S_IDLE  = 3'b000;
    localparam S_READ  = 3'b001;
    localparam S_CALC  = 3'b010;
    localparam S_WRITE = 3'b011;
    localparam S_DONE  = 3'b100;

    reg [2:0] state_r, state_w;

    reg [7:0] cnt_r, cnt_w;
    reg [7:0] row_cnt_r, row_cnt_w;        // count of rows processed (0 to 127)
    reg [7:0] col_cnt_r, col_cnt_w;        // count of columns processed (0 to 127)

    // lbp calculation
    reg  [7:0] data_r [0:8], data_w [0:8];               // [0] [1] [2]
    wire [7:0] lbp_0_w, lbp_90_w, lbp_180_w, lbp_270_w;  // [7] [8] [3]
    wire       lbp_flag [0:8];                           // [6] [5] [4]
    wire [7:0] lbp_min1_w, lbp_min2_w, lbp_min_w;;
    
    genvar j;
    generate
        for (j = 0; j < 9; j = j + 1) begin
            assign lbp_flag_w[j] = (data_r[j] > data_r[8]) ? 1 : 0;
        end
    endgenerate
    lbp_0_w   = {lbp_flag[7], lbp_flag[6], lbp_flag[5], lbp_flag[4], lbp_flag[3], lbp_flag[2], lbp_flag[1], lbp_flag[0]};
    lbp_90_W  = {lbp_flag[6], lbp_flag[7], lbp_flag[0], lbp_flag[1], lbp_flag[2], lbp_flag[3], lbp_flag[4], lbp_flag[5]};
    lbp_180_w = {lbp_flag[4], lbp_flag[5], lbp_flag[6], lbp_flag[7], lbp_flag[0], lbp_flag[1], lbp_flag[2], lbp_flag[3]};
    lbp_270_W = {lbp_flag[2], lbp_flag[3], lbp_flag[4], lbp_flag[5], lbp_flag[6], lbp_flag[7], lbp_flag[0], lbp_flag[1]};
    assign lbp_min1_w = (lbp_0_w < lbp_90_W) ? lbp_0_w : lbp_90_W;
    assign lbp_min2_w = (lbp_180_w < lbp_270_W) ? lbp_180_w : lbp_270_W;
    assign lbp_min_w  = (lbp_min1_w < lbp_min2_w) ? lbp_min1_w : lbp_min2_w;

    // AXI control signals
    reg [2:0] axi_read_cnt_r, axi_read_cnt_w;   // count of AXI read transactions (0 to 3)
    reg [ADDR_WIDTH-1:0] axi_read_addr_r, axi_read_addr_w;
    reg [ADDR_WIDTH-1:0] axi_write_addr_r, axi_write_addr_w;
    reg [DATA_WIDTH-1:0] axi_write_data_r, axi_write_data_w;
    reg read_start_r, read_start_w;
    reg write_start_r, write_start_w;
    wire [DATA_WIDTH-1:0] read_data_w;
    wire axi_finish_w;
    wire read_valid_w;
    wire axi_read_len_W = (col_cnt_r == 127 || col_cnt_r == 0) ? 2 : 3;  // read 2 pixel for first and last column, otherwise read 3 pixels

    // done signal
    reg finish_r, finish_w;

    // CDC synchronization
    reg start_sync1, start_sync2, start_sync3;
    reg finish_sync1, finish_sync2, finish_sync3;
    reg [1:0] finish_cnt_r;  // count of finish signal received in clk_B domain 

    always @(posedge clk_B or posedge rst) begin
        if (rst) begin
            start_sync1 <= 0;
            start_sync2 <= 0;
            start_sync3 <= 0;
            finish_sync1 <= 0;
            finish_sync2 <= 0;
            finish_cnt_r <= 0;
        end
        else begin
            start_sync1 <= start;
            start_sync2 <= start_sync1;
            start_sync3 <= start_sync2;
            finish_sync1 <= finish_r;
            finish_sync2 <= finish_sync1;
            finish_sync3 <= finish_sync2;
            if (!finish_sync3 && finish_sync2) begin
                finish_cnt_r <= 3;
            end
            else if (finish_cnt_r > 0) begin
                finish_cnt_r <= finish_cnt_r - 1;
            end
        end
    end

    assign finish = (finish_cnt_r > 0);

    wire start_pulse_B = start_sync2 && !start_sync3;

    // FSM
    always @(*) begin
        state_w = state_r;
        case (state_r)
            S_IDLE: begin
                if (start_pulse_B) begin
                    state_w = S_READ;
                end
            end 
            S_READ: begin
                if (axi_finish) begin
                    state_w = S_CALC;
                end
            end
            S_CALC: begin
                state_w = S_WRITE;
            end
            S_WRITE: begin
                if (axi_finish) begin
                    if (row_cnt_r == 127 && col_cnt_r == 127) state_w = S_DONE;
                    else state_w = S_READ;
                end
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
                    cnt_w = 0;
                end
            end 
            S_READ: begin
                if (read_valid_w) begin
                    cnt_w = 1;
                end
            end
            S_CALC: begin
                // no change in counters
            end
            S_WRITE: begin
                if (axi_finish) begin
                    row_cnt_w = row_cnt_r + 1;
                    col_cnt_w = (row_cnt_r == 127) ? col_cnt_r + 1 : col_cnt_r;
                    if (row_cnt_r == 127) begin
                        cnt_w = 0;
                    end
                end
            end
            default: begin end
        endcase
    end

    // data control and AXI control signals
    always @(*) begin
        for (i = 0; i < 9; i = i + 1) begin
            data_w[i] = data_r[i];
        end
        finish_w = finish_r;
        read_start_w = read_start_r;
        write_start_w = write_start_r;
        axi_read_cnt_w = axi_read_cnt_r;
        axi_read_addr_w = axi_read_addr_r;
        axi_write_addr_w = axi_write_addr_r;
        axi_write_data_w = axi_write_data_r;
        case (state_r)
            S_IDLE: begin
                if (start_pulse_B) begin
                    data_w[0] = 0;
                    data_w[1] = 0;
                    data_w[2] = 0;
                    data_w[7] = 0;
                    data_w[6] = 0;
                    read_start_w = 1;
                end
            end
            S_READ: begin
                read_start_w = 0;
                if (read_valid_w) begin
                    case (axi_read_cnt_r)
                        0: begin
                            if (!cnt_r) data_w[7] = read_data_w;
                            else data_w[6] = read_data_w;
                        end
                        1: begin
                            if (!cnt_r) data_w[8] = read_data_w;
                            else data_w[5] = read_data_w;
                        end
                        2: begin
                            if (!cnt_r) data_w[3] = read_data_w;
                            else data_w[4] = read_data_w;
                        end
                        default: begin end
                    endcase
                    if (axi_read_cnt_r == axi_read_len_w - 1 && read_valid_w) begin
                        axi_read_cnt_w = 0;
                        if (row_cnt_r == 127 && (col_cnt_r == 0 || col_cnt_r == 126)) axi_read_addr_w = col_cnt_r;
                        else if (row_cnt_r == 127) axi_read_addr_w = col_cnt_r + 1;
                        else axi_read_addr_w = axi_read_addr_r + 128;
                    end
                    else if (read_valid_w) begin
                        axi_read_cnt_w = axi_read_cnt_r + 1;
                    end
                end
            end
            S_CALC: begin
                axi_write_data_w = lbp_min_w;
                write_start_w = 1;
                // data shift
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
                else begin  //  shift data
                    data_w[0] = data_r[7];
                    data_w[1] = data_r[8];
                    data_w[2] = data_r[3];
                    data_w[7] = data_r[6];
                    data_w[8] = data_r[5];
                    data_w[3] = data_r[4];
                end
            end
            S_WRITE: begin
                write_start_w = 0;
                if (axi_finish) begin
                    if (row_cnt_r == 127 && col_cnt_r == 127) finish_w = 1;
                    axi_write_addr_w = (row_cnt_r == 127) ? (col_cnt_r + 1) : (axi_write_addr_r + 128); 
                end
            end
            S_DONE: begin
                // stay in DONE state
            end
            default: begin end
        endcase
    end

    always @(posedge clk_B or posedge rst) begin
        if (rst) begin
            
        end
        else begin
            
        end
    end

endmodule

module AXI_MASTER # (
    parameter DATA_WIDTH = 8,              // AXI4 data width
    parameter ADDR_WIDTH = 15,             // AXI4 address width
    parameter STRB_WIDTH = (DATA_WIDTH/8)  // AXI4 strobe width
)
(
    input                   clk,
    input                   rst,

    input                   read_start,
    input                   write_start,
    output                  finish,

    // LBP-to-AXI control signals
    input  [ADDR_WIDTH-1:0] read_addr,
    input  [           7:0] read_len,
    input  [ADDR_WIDTH-1:0] write_addr,
    input  [           7:0] write_len,
    input  [DATA_WIDTH-1:0] write_data,

    // AXI-to-LBP signals
    output [DATA_WIDTH-1:0] read_data,
    output                  read_valid,

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

    localparam S_IDLE   = 3'b000;
    localparam S_RSHAKE = 3'b001;
    localparam S_RDATA  = 3'b010;
    localparam S_WSHAKE = 3'b011;
    localparam S_WDATA  = 3'b100;

    reg [2:0] state_r, state_w;
    
    // ar channel
    reg data_arvalid_r, data_arvalid_w;
    reg [ADDR_WIDTH-1:0] data_araddr_r, data_araddr_w;
    reg [7:0] data_arlen_r, data_arlen_w;
    assign data_arvalid = data_arvalid_r;
    assign data_araddr  = data_araddr_r;
    assign data_arlen   = data_arlen_r;
    assign data_arsize  = $clog2(DATA_WIDTH/8);
    assign data_arburst = 2'b01;             // INCR

    // r channel
    reg data_rready_r, data_rready_w;
    assign read_valid = data_rvalid && data_rready;
    assign data_rready  = data_rready_r;
    assign read_data = data_rdata;

    // aw channel
    reg data_awvalid_r, data_awvalid_w;
    reg [ADDR_WIDTH-1:0] data_awaddr_r, data_awaddr_w;
    reg [7:0] data_awlen_r, data_awlen_w;
    assign data_awvalid = data_awvalid_r;
    assign data_awaddr  = data_awaddr_r;
    assign data_awlen   = data_awlen_r;
    assign data_awsize  = $clog2(DATA_WIDTH/8);
    assign data_awburst = 2'b01;             // INCR

    // w channel
    reg data_wvalid_r, data_wvalid_w;
    reg [7:0] data_wlen_cnt_r, data_wlen_cnt_w;
    assign data_wvalid  = data_wvalid_r;
    assign data_wlast   = data_wvalid_r && (data_wlen_cnt_r == data_awlen_r);
    assign data_wdata   = write_data;
    assign data_wstrb   = {STRB_WIDTH{1'b1}};

    // AXI to LBP control signals
    reg finish_r, finish_w;
    assign finish = finish_r;

    // AXI FSM
    always @(*) begin
        state_w = state_r;
        case (state_r)
            S_IDLE: begin
                if (read_start)       state_w = S_RSHAKE;
                else if (write_start) state_w = S_WSHAKE;
            end
            S_RSHAKE: begin
                if (data_arvalid && data_arready) state_w = S_RDATA;
            end
            S_RDATA: begin
                if (data_rvalid && data_rready && data_rlast) state_w = S_IDLE;
            end
            S_WSHAKE: begin
                if (data_awvalid && data_awready) state_w = S_WDATA;
            end
            S_WDATA: begin
                if (data_wvalid && data_wready && data_wlast) state_w = S_IDLE;
            end
            default: begin end
        endcase
    end

    // control signals
    always @(*) begin
        // ar channel
        data_araddr_w = data_araddr_r;
        data_arlen_w  = data_arlen_r;
        data_arvalid_w = data_arvalid_r;

        // r channel
        data_rready_w  = data_rready_r;

        // aw channel
        data_awaddr_w  = data_awaddr_r;
        data_awlen_w   = data_awlen_r;
        data_awvalid_w = data_awvalid_r;

        // w channel
        data_wvalid_w  = data_wvalid_r;
        data_wlen_cnt_w = data_wlen_cnt_r;
        
        // AXI to LBP control signals
        finish_w = finish_r;

        case (state_r)
            S_IDLE:  begin
                if (read_start) begin
                    data_arvalid_w = 1;
                    data_araddr_w  = read_addr;
                    data_arlen_w   = read_len;

                end
                else if (write_start) begin
                    data_awvalid_w = 1;
                    data_awaddr_w  = write_addr;
                    data_awlen_w   = write_len;
                end
            end
            S_RSHAKE: begin
                if (data_arvalid && data_arready) begin
                    data_arvalid_w = 0;
                    data_rready_w  = 1;
                end
            end
            S_RDATA: begin
                if (data_rvalid && data_rready && data_rlast) begin
                    data_rready_w  = 0;
                    finish_w       = 1;
                end
            end
            S_WSHAKE: begin
                if (data_awvalid && data_awready) begin
                    data_awvalid_w = 0;
                    data_wvalid_w  = 1;
                end
            end
            S_WDATA: begin
                if (data_wvalid && data_wready && data_wlen_cnt_r == data_awlen_r) begin
                    data_wvalid_w   = 0;
                    data_wlen_cnt_w = 0;
                    finish_w        = 1;
                end
                else if (data_wvalid && data_wready) begin
                    data_wlen_cnt_w = data_wlen_cnt_r + 1;
                end
            end
            default: begin end
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state_r <= S_IDLE;

            // ar channel
            data_araddr_r <= 0;
            data_arlen_r  <= 0;
            data_arvalid_r <= 0;

            // r channel
            data_rready_r  <= 0;

            // aw channel
            data_awaddr_r  <= 0;
            data_awlen_r   <= 0;
            data_awvalid_r <= 0;

            // w channel
            data_wvalid_r  <= 0;
            data_wlen_cnt_r <= 0;
        end
        else begin
            state_r <= state_w;

            // ar channel
            data_araddr_r <= data_araddr_w;
            data_arlen_r  <= data_arlen_w;
            data_arvalid_r <= data_arvalid_w;

            // r channel
            data_rready_r  <= data_rready_w;

            // aw channel
            data_awaddr_r  <= data_awaddr_w;
            data_awlen_r   <= data_awlen_w;
            data_awvalid_r <= data_awvalid_w;

            // w channel
            data_wvalid_r  <= data_wvalid_w;
            data_wlen_cnt_r <= data_wlen_cnt_w;
        end
    end


endmodule
