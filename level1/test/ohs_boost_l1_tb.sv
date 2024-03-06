`timescale 1ns/1ns

`define clk_period 10 /* 100MHz */
`define ce_period 1000 /* 1MHz */
`define pwm_period (`clk_period*1000) /* 20kHz */
`define delay_1ms 1000000
`define delay_10ms 10000000
`define delay_100ms 100000000
`define base_time 0.000000001

`define T_model 1e-6 /* samplind period model */
`define data_width 32
`define data_decimal 22

module ohs_boost_l1_tb();

  reg aclk;
  reg ce;
  reg resetn;

  real L;
  real C;
  real R;
  real f_kL;
  real f_kC;
  real f_kR;
  real f_vdc;
  reg signed [`data_width-1:0] kL;
  reg signed [`data_width-1:0] kC;
  reg signed [`data_width-1:0] kR;
  reg signed [`data_width-1:0] vdc;

  wire signed [`data_width-1:0] iL;
  wire signed [`data_width-1:0] vL;
  wire signed [`data_width-1:0] iC;
  wire signed [`data_width-1:0] vC;
  wire signed [`data_width-1:0] iLoad;

  integer pwm_comparator;
  integer file_id;

  /* clock generation */
  initial begin
    aclk <= 1'b0;
    #(`clk_period/2);
    forever begin
      aclk <= ~aclk;
      #(`clk_period/2);
    end
  end

  /* ce generation */
  initial begin
    ce <= 1'b0;
    forever begin
      #(`ce_period - `clk_period);
      ce <= 1'b1;
      #(`clk_period);
      ce <= 0;
    end
  end

  /* test flow */
  initial begin
    
    /* create vcd file and save all signals */
    $dumpfile("test_result.vcd");
    $dumpvars();

    /* reset module */
    resetn <= 1'b0;

    /* initialize values */
    L = 100e-6;
    C = 330e-6;
    R = 10;
    f_kL = `T_model / L;
    f_kC = `T_model / C;
    f_kR = 1/R;
    f_vdc = 15;
    pwm_comparator = (`pwm_period/8);

    /* quantize values */
    kL <= f_kL * 2**`data_decimal;
    kC <= f_kC * 2**`data_decimal;
    kR <= f_kR * 2**`data_decimal;
    vdc <= f_vdc * 2**`data_decimal;

    #(`clk_period*10);
    resetn <= 1'b1;

    #(`delay_10ms*5);

    pwm_comparator = (`pwm_period/2);

    #(`delay_10ms*3);

    R = 5;
    f_kR = 1/R;
    kR <= f_kR * 2**`data_decimal;

    #(`delay_10ms*2);

    $finish();

  end

  /* pwm generation */
  pwm_generator #(
  .counter_width(32)
  ) pwm_inst(
  .aclk(aclk), 
  .resetn(resetn), 
  .period(`pwm_period), 
  .comparator(pwm_comparator), 
  .counter(), 
  .pwm(S1_pwm)
  );

  ohs_boost_l1 #(
  .data_width(`data_width),
  .data_decimal(`data_decimal)
  ) dut (
  .aclk(aclk), 
  .resetn(resetn), 
  .ce(ce),

  /* Model parameters */
  .kL(kL),
  .kC(kC),
  .kR(kR),
  .vdc(vdc),
  
  /* PWM input */
  .S1_pwm(S1_pwm),
   
  /* Model outputs*/
  .iL(iL),
  .vL(vL),
  .iC(iC),
  .vC(vC),
  .iLoad(iLoad)
  );

  /* output file */
  initial
    begin
      file_id = $fopen("data_sim.csv","w");

      $fwrite(file_id, "time,iL,vL,iC,vC,iLoad\n");

      forever begin
        @(posedge ce);  
        $fwrite(file_id, "%f,%d,%d,%d,%d,%d \n", $time*`base_time, iL,vL,iC,vC,iLoad);
      end
      
    end

endmodule