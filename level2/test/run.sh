iverilog ../test/ohs_boost_l2_tb.sv ../test/pwm_generator.v ../v/ohs_boost_l2.v -s ohs_boost_l2_tb -o ./sim.vvp
vvp sim.vvp
rm ./sim.vvp