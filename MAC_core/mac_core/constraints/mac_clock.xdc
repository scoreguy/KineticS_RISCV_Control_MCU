# Clock target only. Add board pins, I/O delays and system-level constraints at integration.
create_clock -name clk -period 8.000 [get_ports clk]
