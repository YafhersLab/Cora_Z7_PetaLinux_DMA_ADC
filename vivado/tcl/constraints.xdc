# main clock 160MHz with duty 50%
create_clock -period 6.25 -name clk -waveform {0.000 3.125} [get_ports clk]