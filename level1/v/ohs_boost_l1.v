/**
  Module name: ohs_boost_l1
  Author: P.Trujillo
  Date: March 2024
  Revision: 1.0
  History: 
    1.0: Model created
**/

module ohs_boost_l1 #(
  parameter MODEL_DATA_WIDTH = 32,
  parameter MODEL_Q_WIDTH = 22
)(
  input aclk, 
  input resetn, 
  input ce,

  /* Model parameters */
  input signed [MODEL_DATA_WIDTH-1:0] kL,
  input signed [MODEL_DATA_WIDTH-1:0] kC,
  input signed [MODEL_DATA_WIDTH-1:0] kR,
  input signed [MODEL_DATA_WIDTH-1:0] vdc,
  
  /* PWM input */
  input S1_pwm,
   
  /* Model outputs*/
  output wire signed [MODEL_DATA_WIDTH-1:0] iL,
  output wire signed [MODEL_DATA_WIDTH-1:0] vL,
  output reg signed [MODEL_DATA_WIDTH-1:0] iC,
  output wire signed [MODEL_DATA_WIDTH-1:0] vC,
  output wire signed [MODEL_DATA_WIDTH-1:0] iLoad
);

	/**********************************************************************************
	*
	* Variables declaration
	*
	**********************************************************************************/
	/* inductor voltages */
	wire signed [(MODEL_DATA_WIDTH*2)-1:0] vL_k_ds;
	reg signed [MODEL_DATA_WIDTH-1:0] v2;
	wire signed [MODEL_DATA_WIDTH-1:0] vL_k;

	/* inductor current */
	reg signed [MODEL_DATA_WIDTH-1:0] iL_1;

	/* current through R and C */
	reg signed [MODEL_DATA_WIDTH-1:0] iCR;

	/* capacitor current */
	wire signed [(MODEL_DATA_WIDTH*2)-1:0] iC_k_ds;
	wire signed [MODEL_DATA_WIDTH-1:0] iC_k;

	/* capacitor/output voltage */
	reg signed [MODEL_DATA_WIDTH-1:0] vC_1;

	/* resistor/output current */
	wire signed [(MODEL_DATA_WIDTH*2)-1:0] iR_k_ds;
	wire signed [MODEL_DATA_WIDTH-1:0] iR_k;

	/**********************************************************************************
	*
	* Model
	*
	**********************************************************************************/

	/* inductor voltage  */
	assign vL = vdc-v2;

	/* inductor voltage gained */
	assign vL_k_ds = $signed({{MODEL_DATA_WIDTH{vL[MODEL_DATA_WIDTH-1]}}, vL} * {{MODEL_DATA_WIDTH{kL[MODEL_DATA_WIDTH-1]}}, kL});
	assign vL_k = $signed(vL_k_ds >>> MODEL_Q_WIDTH);

	/* inductor current integrator */
	assign iL = vL_k + iL_1;

	always @(posedge aclk)
		if (!resetn)
			iL_1 <= {MODEL_DATA_WIDTH{1'b0}};
		else 
			if (ce)
				iL_1 <= iL;

		/* current through the capacitor + resistor */
		always @(posedge aclk)
			if (!resetn)
				iCR <= {MODEL_DATA_WIDTH{1'b0}};
			else
				iCR <= S1_pwm? {MODEL_DATA_WIDTH{1'b0}}: iL;
		
		/* capacitor current */
		always @(posedge aclk)
			if (!resetn)
				iC <= {MODEL_DATA_WIDTH{1'b0}};
			else 
				iC <= iCR - iLoad;

		/* capacitor current gained */
		assign iC_k_ds = $signed({{MODEL_DATA_WIDTH{iC[MODEL_DATA_WIDTH-1]}}, iC} * {{MODEL_DATA_WIDTH{kL[MODEL_DATA_WIDTH-1]}}, kC});
		assign iC_k = $signed(iC_k_ds >>> MODEL_Q_WIDTH);

		/* capacitor voltage integrator */
		assign vC = iC_k + vC_1;

		always @(posedge aclk)
			if (!resetn)
				vC_1 <= {MODEL_DATA_WIDTH{1'b0}};
			else 
				if (ce)
					vC_1 <= vC;

		/* voltage in the inductor pad */
		always @(posedge aclk)
			if (!resetn)
				v2 <= {MODEL_DATA_WIDTH{1'b0}};
			else 
				v2 <= S1_pwm? {MODEL_DATA_WIDTH{1'b0}}: vC;

		/* current through the load resistor */
		assign iR_k_ds = $signed({{MODEL_DATA_WIDTH{vC[MODEL_DATA_WIDTH-1]}}, vC} * {{MODEL_DATA_WIDTH{kL[MODEL_DATA_WIDTH-1]}}, kR});
		assign iR_k = $signed(iR_k_ds >>> MODEL_Q_WIDTH); 

		/* output current is the resistor current */
		assign iLoad = iR_k;

	endmodule