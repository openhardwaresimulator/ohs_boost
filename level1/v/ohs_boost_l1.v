/**
  Module name: ohs_boost_l1
  Author: P.Trujillo
  Date: March 2024
  Revision: 1.0
  History: 
    1.0: Model created
**/

module ohs_boost_l1 #(
  parameter data_width = 32,
  parameter data_decimal = 22
)(
  input aclk, 
  input resetn, 
  input ce,

  /* Model parameters */
  input signed [data_width-1:0] kL,
  input signed [data_width-1:0] kC,
  input signed [data_width-1:0] kR,
  input signed [data_width-1:0] vdc,
  
  /* PWM input */
  input S1_pwm,
   
  /* Model outputs*/
  output wire signed [data_width-1:0] iL,
  output wire signed [data_width-1:0] vL,
  output reg signed [data_width-1:0] iC,
  output wire signed [data_width-1:0] vC,
  output wire signed [data_width-1:0] iLoad
);

/* inductor voltages */
wire signed [(data_width*2)-1:0] vL_k_ds;
reg signed [data_width-1:0] v2;
wire signed [data_width-1:0] vL_k;

/* inductor current */
reg signed [data_width-1:0] iL_1;

/* current through R and C */
reg signed [data_width-1:0] iCR;

/* capacitor current */
wire signed [(data_width*2)-1:0] iC_k_ds;
wire signed [data_width-1:0] iC_k;

/* capacitor/output voltage */
reg signed [data_width-1:0] vC_1;

/* resistor/output current */
wire signed [(data_width*2)-1:0] iR_k_ds;
wire signed [data_width-1:0] iR_k;

/* inductor voltage  */
assign vL = vdc-v2;

/* inductor voltage gained */
assign vL_k_ds = $signed({{data_width{vL[data_width-1]}}, vL} * {{data_width{kL[data_width-1]}}, kL});
assign vL_k = $signed(vL_k_ds >>> data_decimal);

/* inductor current integrator */
assign iL = vL_k + iL_1;

always @(posedge aclk)
  if (!resetn)
    iL_1 <= {data_width{1'b0}};
  else 
    if (ce)
      iL_1 <= iL;

  /* current through the capacitor + resistor */
  always @(posedge aclk)
    if (!resetn)
      iCR <= {data_width{1'b0}};
    else
      iCR <= S1_pwm? {data_width{1'b0}}: iL;
  
  /* capacitor current */
  always @(posedge aclk)
    if (!resetn)
      iC <= {data_width{1'b0}};
    else 
      iC <= iCR - iLoad;

  /* capacitor current gained */
  assign iC_k_ds = $signed({{data_width{iC[data_width-1]}}, iC} * {{data_width{kL[data_width-1]}}, kC});
  assign iC_k = $signed(iC_k_ds >>> data_decimal);

  /* capacitor voltage integrator */
  assign vC = iC_k + vC_1;

  always @(posedge aclk)
    if (!resetn)
      vC_1 <= {data_width{1'b0}};
    else 
      if (ce)
        vC_1 <= vC;

  /* voltage in the inductor pad */
  always @(posedge aclk)
    if (!resetn)
      v2 <= {data_width{1'b0}};
    else 
      v2 <= S1_pwm? {data_width{1'b0}}: vC;

  /* current through the load resistor */
  assign iR_k_ds = $signed({{data_width{vC[data_width-1]}}, vC} * {{data_width{kL[data_width-1]}}, kR});
  assign iR_k = $signed(iR_k_ds >>> data_decimal); 

  /* output current is the resistor current */
  assign iLoad = iR_k;

endmodule