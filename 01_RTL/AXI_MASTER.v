`timescale 1ns/1ps
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
    input  [ADDR_WIDTH :0] write_addr,
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
    reg [ADDR_WIDTH:0] data_awaddr_r, data_awaddr_w;
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
    assign finish = (data_rlast && data_rvalid && data_rready) || (data_wlast && data_wvalid && data_wready);

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

        case (state_r)
            S_IDLE:  begin
                if (read_start) begin
                    data_arvalid_w = 1;
                    data_araddr_w  = read_addr;
                    data_arlen_w   = read_len;
                    data_rready_w  = 1;

                end
                else if (write_start) begin
                    data_awvalid_w = 1;
                    data_awaddr_w  = write_addr;
                    data_awlen_w   = write_len;
                    data_wvalid_w  = 1;
                end
            end
            S_RSHAKE: begin
                if (data_arvalid && data_arready) begin
                    data_arvalid_w = 0;
                    // data_rready_w  = 1;
                end
            end
            S_RDATA: begin
                if (data_rvalid && data_rready && data_rlast) begin
                    data_rready_w  = 0;
                end
            end
            S_WSHAKE: begin
                if (data_awvalid && data_awready) begin
                    data_awvalid_w = 0;
                    // data_wvalid_w  = 1;
                end
            end
            S_WDATA: begin
                if (data_wvalid && data_wready && data_wlen_cnt_r == data_awlen_r) begin
                    data_wvalid_w   = 0;
                    data_wlen_cnt_w = 0;
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
