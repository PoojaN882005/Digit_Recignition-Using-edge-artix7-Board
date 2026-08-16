## Clock Signal (50 MHz)
set_property -dict { PACKAGE_PIN N11 IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 20.00 -waveform {0 10} [get_ports { clk }];

## Active-High Pushbutton (PB0)
set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS33 PULLDOWN true } [get_ports { rst_btn }];

## USB UART RX
set_property -dict { PACKAGE_PIN D4 IOSTANDARD LVCMOS33 } [get_ports { uart_rx_i }];

## 7-Segment Display Cathodes (A, B, C, D, E, F, G)
set_property -dict { PACKAGE_PIN G2 IOSTANDARD LVCMOS33 } [get_ports { Seven_Seg[0] }]; # A
set_property -dict { PACKAGE_PIN G1 IOSTANDARD LVCMOS33 } [get_ports { Seven_Seg[1] }]; # B
set_property -dict { PACKAGE_PIN H5 IOSTANDARD LVCMOS33 } [get_ports { Seven_Seg[2] }]; # C
set_property -dict { PACKAGE_PIN H4 IOSTANDARD LVCMOS33 } [get_ports { Seven_Seg[3] }]; # D
set_property -dict { PACKAGE_PIN J5 IOSTANDARD LVCMOS33 } [get_ports { Seven_Seg[4] }]; # E
set_property -dict { PACKAGE_PIN J4 IOSTANDARD LVCMOS33 } [get_ports { Seven_Seg[5] }]; # F
set_property -dict { PACKAGE_PIN H2 IOSTANDARD LVCMOS33 } [get_ports { Seven_Seg[6] }]; # G

## 7-Segment Display Anodes (Active-Low Digit Enables)
set_property -dict { PACKAGE_PIN F2 IOSTANDARD LVCMOS33 } [get_ports { digit_en[0] }]; # Digit 1
set_property -dict { PACKAGE_PIN E1 IOSTANDARD LVCMOS33 } [get_ports { digit_en[1] }]; # Digit 2
set_property -dict { PACKAGE_PIN G5 IOSTANDARD LVCMOS33 } [get_ports { digit_en[2] }]; # Digit 3
set_property -dict { PACKAGE_PIN G4 IOSTANDARD LVCMOS33 } [get_ports { digit_en[3] }]; # Digit 4

## Diagnostic LEDs
set_property -dict { PACKAGE_PIN J3 IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN H3 IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN K1 IOSTANDARD LVCMOS33 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN L2 IOSTANDARD LVCMOS33 } [get_ports { led[3] }];