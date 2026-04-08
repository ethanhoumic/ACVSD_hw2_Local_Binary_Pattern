`timescale 1ns/1ps
`define CYCLE_A 100.0
`define CYCLE_B 6.0
`define SDFFILE    "../02_SYN/Netlist/LBP_syn.sdf"	  // Modify your sdf file name
`define End_CYCLE  10000000              // Modify cycle times once your design need more cycle times!

`ifdef p1
    `define PAT        "../00_TESTBED/pattern/pattern1.dat"    
    `define EXP        "../00_TESTBED/pattern/golden1.dat"  
`elsif p2
    `define PAT        "../00_TESTBED/pattern/pattern2.dat"    
    `define EXP        "../00_TESTBED/pattern/golden2.dat"
`endif

`ifndef PAT
    `define PAT "../00_TESTBED/pattern/pattern1.dat"
    `define EXP "../00_TESTBED/pattern/golden1.dat"
`endif


module testfixture# (
    parameter DATA_WIDTH   = 8             ,
    parameter M_ADDR_WIDTH = 15            ,
    parameter M_COUNT      = 1             ,
    parameter STRB_WIDTH   = (DATA_WIDTH/8),
    parameter ID_WIDTH     = 8             
);

// input
reg clk_A;
reg clk_B;
reg rst;
reg start;
integer cycle_count;

wire rst_sync;

// output
wire finish;

// AXI ports
wire [M_COUNT*M_ADDR_WIDTH-1:0] m_axi_awaddr ;
wire [M_COUNT           *8-1:0] m_axi_awlen  ;
wire [M_COUNT           *3-1:0] m_axi_awsize ;
wire [M_COUNT           *2-1:0] m_axi_awburst;
wire [M_COUNT             -1:0] m_axi_awlock ;
wire [M_COUNT           *4-1:0] m_axi_awcache;
wire [M_COUNT           *3-1:0] m_axi_awprot ;
wire [M_COUNT             -1:0] m_axi_awvalid;
wire [M_COUNT             -1:0] m_axi_awready;
wire [M_COUNT  *DATA_WIDTH-1:0] m_axi_wdata  ;
wire [M_COUNT  *STRB_WIDTH-1:0] m_axi_wstrb  ;
wire [M_COUNT             -1:0] m_axi_wlast  ;
wire [M_COUNT             -1:0] m_axi_wvalid ;
wire [M_COUNT             -1:0] m_axi_wready ;
wire [M_COUNT    *ID_WIDTH-1:0] m_axi_bid    ;
wire [M_COUNT           *2-1:0] m_axi_bresp  ;
wire [M_COUNT             -1:0] m_axi_bvalid ;
wire [M_COUNT             -1:0] m_axi_bready ;
wire [M_COUNT*M_ADDR_WIDTH-1:0] m_axi_araddr ;
wire [M_COUNT           *8-1:0] m_axi_arlen  ;
wire [M_COUNT           *3-1:0] m_axi_arsize ;
wire [M_COUNT           *2-1:0] m_axi_arburst;
wire [M_COUNT             -1:0] m_axi_arlock ;
wire [M_COUNT           *4-1:0] m_axi_arcache;
wire [M_COUNT           *3-1:0] m_axi_arprot ;
wire [M_COUNT             -1:0] m_axi_arvalid;
wire [M_COUNT             -1:0] m_axi_arready;
wire [M_COUNT    *ID_WIDTH-1:0] m_axi_rid    ;
wire [M_COUNT  *DATA_WIDTH-1:0] m_axi_rdata  ;
wire [M_COUNT           *2-1:0] m_axi_rresp  ;
wire [M_COUNT             -1:0] m_axi_rlast  ;
wire [M_COUNT             -1:0] m_axi_rvalid ;
wire [M_COUNT             -1:0] m_axi_rready ;

axi_ram # (
    .DATA_WIDTH (DATA_WIDTH   ),
    .ADDR_WIDTH (M_ADDR_WIDTH )
) axi_ram_inst (
    .clk             (clk_B          ),
    .rst             (!rst_sync      ),
    .s_axi_awid      (8'b0           ),
    .s_axi_awaddr    (m_axi_awaddr   ),
    .s_axi_awlen     (m_axi_awlen    ),
    .s_axi_awsize    (m_axi_awsize   ),
    .s_axi_awburst   (m_axi_awburst  ),
    .s_axi_awlock    (1'b0           ),
    .s_axi_awcache   (4'b0           ),
    .s_axi_awprot    (3'b0           ),
    .s_axi_awvalid   (m_axi_awvalid  ),
    .s_axi_awready   (m_axi_awready  ),
    .s_axi_wdata     (m_axi_wdata    ),
    .s_axi_wstrb     (m_axi_wstrb    ),
    .s_axi_wlast     (m_axi_wlast    ),
    .s_axi_wvalid    (m_axi_wvalid   ),
    .s_axi_wready    (m_axi_wready   ),
    .s_axi_bid       (m_axi_bid      ),
    .s_axi_bresp     (m_axi_bresp    ),
    .s_axi_bvalid    (m_axi_bvalid   ),
    .s_axi_bready    (1'b1           ), // m_axi_bready
    .s_axi_arid      (8'b0           ),
    .s_axi_araddr    (m_axi_araddr   ),
    .s_axi_arlen     (m_axi_arlen    ),
    .s_axi_arsize    (m_axi_arsize   ),
    .s_axi_arburst   (m_axi_arburst  ),
    .s_axi_arlock    (1'b0           ),
    .s_axi_arcache   (4'b0           ),
    .s_axi_arprot    (3'b0           ),
    .s_axi_arvalid   (m_axi_arvalid  ),
    .s_axi_arready   (m_axi_arready  ),
    .s_axi_rid       (m_axi_rid      ),
    .s_axi_rdata     (m_axi_rdata    ),
    .s_axi_rresp     (m_axi_rresp    ),
    .s_axi_rlast     (m_axi_rlast    ),
    .s_axi_rvalid    (m_axi_rvalid   ),
    .s_axi_rready    (m_axi_rready   ),

    .start           (start)
);

reset_sync reset_sync_inst (
    .i_CLK           (clk_B),
    .i_RST_N         (!rst),

    .o_RST_N_SYN     (rst_sync)
);

LBP # (
    .DATA_WIDTH (DATA_WIDTH  ), // AXI4 data width
    .ADDR_WIDTH (M_ADDR_WIDTH), // AXI4 address width
    .STRB_WIDTH (STRB_WIDTH  )  // AXI4 strobe width
) LBP_inst (
    // Clock and synchronous high reset
    .clk_A     (clk_A),
    .clk_B     (clk_B),
    .rst       (!rst_sync),

    .start     (start ),
    .finish    (finish),

    // Data AXI4 master interface 
    .data_awaddr  (m_axi_awaddr ),
    .data_awlen   (m_axi_awlen  ),
    .data_awsize  (m_axi_awsize ),
    .data_awburst (m_axi_awburst),
    .data_awvalid (m_axi_awvalid),
    .data_awready (m_axi_awready),
    .data_wdata   (m_axi_wdata  ),
    .data_wstrb   (m_axi_wstrb  ),
    .data_wlast   (m_axi_wlast  ),
    .data_wvalid  (m_axi_wvalid ),
    .data_wready  (m_axi_wready ),
    // .data_bresp   (m_axi_bresp  ),
    // .data_bvalid  (m_axi_bvalid ),
    // .data_bready  (m_axi_bready ),
    .data_araddr  (m_axi_araddr ),
    .data_arlen   (m_axi_arlen  ),
    .data_arsize  (m_axi_arsize ),
    .data_arburst (m_axi_arburst),
    .data_arvalid (m_axi_arvalid),
    .data_arready (m_axi_arready),
    .data_rdata   (m_axi_rdata  ),
    .data_rresp   (m_axi_rresp  ),
    .data_rlast   (m_axi_rlast  ),
    .data_rvalid  (m_axi_rvalid ),
    .data_rready  (m_axi_rready )
);

parameter N_EXP   = 16384; // 128 x 128 pixel
parameter N_PAT   = N_EXP;

reg   [7:0]   exp_mem    [0:N_EXP-1];

reg [7:0] LBP_dbg;
reg [7:0] exp_dbg;

integer err = 0;
integer times = 0;
reg over = 0;
integer exp_num = 0;
integer i;
   
`ifdef SDF
	initial $sdf_annotate(`SDFFILE, LBP_inst);
`endif

initial	$readmemh (`EXP, exp_mem);

initial clk_A = 0;
initial clk_B = 0;
always #(`CYCLE_A/2.0) clk_A = ~clk_A;
always #(`CYCLE_B/2.0) clk_B = ~clk_B;

initial begin
    $fsdbDumpfile("testfixture.fsdb");
    $fsdbDumpvars(0, testfixture, "+mda");
end

// initial begin
//     $dumpvars();
//     $dumpfile("testfixture.vcd");
// end

initial begin
   cycle_count = 0;
   @(negedge clk_B);
   while (1) begin
      cycle_count = cycle_count + 1;
      @(negedge clk_B);
   end
end

initial begin // result compare
	$display("-----------------------------------------------------\n");
 	$display("START!!! Simulation Start .....\n");
    $display("The pattern is from %s \n", `PAT);
    $display("The golden is from %s \n", `EXP);
 	$display("-----------------------------------------------------\n");

   rst   = 0;
   start = 0;

   // start reset
   @(posedge clk_A) #(1.0);
   rst = 1;
   repeat (3) @(posedge clk_A);
   @(posedge clk_A) #(1.0);
   rst = 0;
   
   @(posedge clk_A) #(1.0);
   @(posedge clk_A) #(1.0);
   start = 1;
   @(posedge clk_A) #(1.0);
   start = 0;

	#(`CYCLE_A*3);

    // Pulse 1
    while (~finish) begin
        @(posedge clk_A) #(`CYCLE_A-1.0);
    end
    @(posedge clk_A) #(`CYCLE_A-1.0);
    while (finish) begin
        @(posedge clk_A) #(`CYCLE_A-1.0);
    end
    @(posedge clk_A) #(`CYCLE_A-1.0);

    // Pulse 2
    while (~finish) begin
        @(posedge clk_A) #(`CYCLE_A-1.0);
    end
    @(posedge clk_A) #(`CYCLE_A-1.0);
    while (finish) begin
        @(posedge clk_A) #(`CYCLE_A-1.0);
    end
    @(posedge clk_A) #(`CYCLE_A-1.0);

    // Pulse 3
    while (~finish) begin
        @(posedge clk_A) #(`CYCLE_A-1.0);
    end
    @(posedge clk_A) #(`CYCLE_A-1.0);
    
	for (i=0; i <N_PAT ; i=i+1) begin
				exp_dbg = exp_mem[i]; LBP_dbg = axi_ram_inst.mem[i+16384];
				if (exp_mem[i] == axi_ram_inst.mem[i+16384]) begin
					err = err;
				end
				else begin
					//$display("pixel %d is FAIL !!", i); 
					err = err+1;
					// if (err <= 10) 
                    $display("Output pixel %d is wrong! Output = %h, golden = %h", i, axi_ram_inst.mem[i+16384], exp_mem[i]);
					// if (err == 11) begin $display("Find the wrong pixel reached a total of more than 10 !, Please check the code .....\n");  end
				end
				if( ((i%1000) === 0) || (i == 16383))begin  
					if ( err === 0)
      					$display("Output pixel: 0 ~ %d are correct!\n", i);
					else
					$display("Output Pixel: 0 ~ %d are wrong ! The wrong pixel reached a total of %d or more ! \n", i, err);
					
  				end					
				exp_num = exp_num + 1;
	end
	over = 1;
end


initial  begin
 #`End_CYCLE ;
 	$display("-----------------------------------------------------\n");
 	$display("Error!!! Somethings' wrong with your code ...!\n");
 	$display("-------------------------FAIL------------------------\n");
 	$display("-----------------------------------------------------\n");
 	$finish;
end

initial begin
      @(posedge over)      
      if((over) && (exp_num!='d0)) begin
         $display("-----------------------------------------------------\n");
         if (err == 0)  begin
            $display("Congratulations! All data have been generated successfully!\n");
            $display("Total cost time: %10.2f ns", cycle_count*(`CYCLE_B));
            $display("-------------------------PASS------------------------\n");
         end
         else begin
            $display("There are %d errors!\n", err);
            $display("-----------------------------------------------------\n");
	    
         end
      end
      #(`CYCLE_A/2); $finish;
end
   
endmodule

module reset_sync(
    input       i_CLK,
    input       i_RST_N,

    output      o_RST_N_SYN
);

reg A1, A2;

assign o_RST_N_SYN = A2;

always@(posedge i_CLK) begin
    if(!i_RST_N) begin
        A1 <= 0;
        A2 <= 0;
    end
    else begin
        A1 <= 1;
        A2 <= A1;
    end 
end

endmodule
