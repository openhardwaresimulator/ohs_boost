iverilog ../test/ohs_boost_l1_tb.sv ../test/pwm_generator.v ../v/ohs_boost_l1.v -s ohs_boost_l1_tb -o ./sim.vvp
vvp sim.vvp
rm ./sim.vvp