/**
  Module name: axi_ohs_comm
  Author: P.Trujillo
  Date: March 2024
  Revision: 1.0
  History: 
    1.0: Module created
**/

`default_nettype none

`define S_AXI_DATA_WIDTH 32
`define	S_AXI_ADDR_WIDTH 6 /* 9 parameters needed x 4 bytes */

module axi_ohs_boost_comm (
	input wire s_axi_aclk, 
	input wire s_axi_aresetn, 

	/* address write if */
  input wire [`S_AXI_ADDR_WIDTH - 1:0] s_axi_awaddr,
  input wire s_axi_awvalid,
	output wire s_axi_awready,

  /* data write if */
	input wire [`S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
	input wire [`S_AXI_DATA_WIDTH/8-1:0] s_axi_wstrb,
	input wire s_axi_wvalid,
  output wire s_axi_wready,

	/* status */
	output wire [1:0] s_axi_bresp,
	output reg s_axi_bvalid,
	input wire s_axi_bready,

	/* address read if */
	input wire [`S_AXI_ADDR_WIDTH - 1:0] s_axi_araddr,
  input  wire s_axi_arvalid,
  output wire s_axi_arready,

	/* data read if */
  output reg [`S_AXI_DATA_WIDTH-1:0] s_axi_rdata,	
  output wire [1:0] s_axi_rresp,
	output reg s_axi_rvalid,
	input wire s_axi_rready,

	/* model configuration registers */
	output reg [`S_AXI_DATA_WIDTH-1:0] kL,
	output reg [`S_AXI_DATA_WIDTH-1:0] kC,
	output reg [`S_AXI_DATA_WIDTH-1:0] kR,
	output reg [`S_AXI_DATA_WIDTH-1:0] vdc,

	/* model visualization signals */
	input wire [`S_AXI_DATA_WIDTH-1:0] iL,
	input wire [`S_AXI_DATA_WIDTH-1:0] vL,
	input wire [`S_AXI_DATA_WIDTH-1:0] iC,
	input wire [`S_AXI_DATA_WIDTH-1:0] vC,
	input wire [`S_AXI_DATA_WIDTH-1:0] iLoad
);

	localparam ADDR_LSB = 2; /* AXI lite is always 32 bits (32 = 4 bytes) */
	localparam ADDR_MSB = `S_AXI_ADDR_WIDTH-ADDR_LSB; /* AXI lite is always 32 bits (32 = 4 bytes) */

	/**********************************************************************************
	*
	* Write strobe apply function (https://zipcpu.com/blog/2020/03/08/easyaxil.html)
	*
	**********************************************************************************/

	function [`S_AXI_DATA_WIDTH-1:0]	apply_wstrb;
		input	[`S_AXI_DATA_WIDTH-1:0] prior_data;
		input	[`S_AXI_DATA_WIDTH-1:0] new_data;
		input	[`S_AXI_DATA_WIDTH/8-1:0] wstrb;

		integer	k;
		for(k=0; k<`S_AXI_DATA_WIDTH/8; k=k+1)
		begin
			apply_wstrb[k*8 +: 8]
				= wstrb[k] ? new_data[k*8 +: 8] : prior_data[k*8 +: 8];
		end
	endfunction

	/**********************************************************************************
	*
	* AXI Registers declaration
	*
	**********************************************************************************/


	/**********************************************************************************
	*
	* AXI internal signals
	*
	**********************************************************************************/

	reg [1:0] axi_rresp; /* read response */
	reg [1 :0] axi_bresp; /* write response */
	reg axi_awready; /* write address acceptance */
	reg axi_bvalid; /* write response valid */
	wire [ADDR_MSB-1:0] axi_awaddr; /* write address */
	wire [ADDR_MSB-1:0] axi_araddr; /* read address valid */
	reg [`S_AXI_DATA_WIDTH-1:0] axi_rdata; /* read data */
	reg axi_arready; /* read address acceptance */
	wire axi_read_ready; /* read ready */

	wire [`S_AXI_DATA_WIDTH-1:0] wskd_kL; /* reading register with strobo appplied */
	wire [`S_AXI_DATA_WIDTH-1:0] wskd_kC; /* reading register with strobo appplied */
	wire [`S_AXI_DATA_WIDTH-1:0] wskd_kR; /* reading register with strobo appplied */
	wire [`S_AXI_DATA_WIDTH-1:0] wskd_vdc; /* reading register with strobo appplied */

	/**********************************************************************************
	*
	* Write acceptance.
	*
	**********************************************************************************/

  always @(posedge s_axi_aclk )
    if (!s_axi_aresetn)
        axi_awready <= 1'b0;
    else
      axi_awready <= !axi_awready && (s_axi_awvalid && s_axi_wvalid) && (!s_axi_bvalid || s_axi_bready);
	
	/* Both ready signals are set at the same time */
	assign s_axi_awready = axi_awready;
	assign s_axi_wready = axi_awready;

	/**********************************************************************************
	*
	* Register write
	*
	**********************************************************************************/

	/* Apply write strobe to registers */
	assign wskd_kL = apply_wstrb(kL, s_axi_wdata, s_axi_wstrb);
	assign wskd_kC = apply_wstrb(kC, s_axi_wdata, s_axi_wstrb);
	assign wskd_kR = apply_wstrb(kR, s_axi_wdata, s_axi_wstrb);
	assign wskd_vdc = apply_wstrb(vdc, s_axi_wdata, s_axi_wstrb);

	/* set address */
	assign axi_awaddr = s_axi_awaddr[`S_AXI_ADDR_WIDTH-1:ADDR_LSB];

	/* write registers */
	always @(s_axi_aclk)
	if (!s_axi_aresetn) begin
		kL <= 0;
		kC <= 0;
		kR <= 0;
		vdc <= 0;
	end
	else 
		if (axi_awready)
			case(s_axi_awaddr)
				4'b0000: kL <= wskd_kL;
				4'b0001: kC <= wskd_kC;
				4'b0010: kR <= wskd_kR;
				4'b0011: vdc <= wskd_vdc;
			endcase

	/**********************************************************************************
	*
	* Register read
	*
	**********************************************************************************/

	assign axi_read_ready = (s_axi_arvalid && s_axi_arready);
	assign axi_araddr = s_axi_araddr[`S_AXI_ADDR_WIDTH-1:ADDR_LSB];

	always @(posedge s_axi_aclk)
		if (!s_axi_aresetn)
			axi_rdata <= {`S_AXI_DATA_WIDTH{1'b0}};
		else 
			if (!s_axi_rvalid || s_axi_rready)
				case(axi_araddr)
					4'b0000: s_axi_rdata	<= kL;
					4'b0001: s_axi_rdata	<= kC;
					4'b0010: s_axi_rdata	<= kR;
					4'b0011: s_axi_rdata	<= vdc;
					4'b0100: s_axi_rdata	<= iL;
					4'b0101: s_axi_rdata	<= vL;
					4'b0110: s_axi_rdata	<= iC;
					4'b0111: s_axi_rdata	<= vC;
					4'b1000: s_axi_rdata	<= iLoad;
					default: s_axi_rdata <= {`S_AXI_DATA_WIDTH{1'b0}};
				endcase

	/**********************************************************************************
	*
	* AXI information signals
	*
	**********************************************************************************/

	/* force no errors during AXI transactions */
	assign s_axi_bresp = 2'b00;
	assign s_axi_rresp = 2'b00;

	/* s_axi_bvalid is set following any succesful write transaction */
	always @(posedge s_axi_aclk)
		if (!s_axi_aresetn)
			s_axi_bvalid <= 1'b0;
		else 
			if (axi_awready)
				s_axi_bvalid <= 1'b1;
			else if (s_axi_bready)
				s_axi_bvalid <= 1'b0;
	
	/* s_axi_bvalid is set following any succesful read transaction */
	always @(posedge s_axi_aclk)
		if (!s_axi_aresetn)
			s_axi_rvalid <= 1'b0;
		else 
			if (axi_read_ready)
				s_axi_rvalid <= 1'b1;
			else if (s_axi_rready)
				s_axi_rvalid <= 1'b0;

	assign s_axi_arready = !s_axi_rvalid;
	
endmodule