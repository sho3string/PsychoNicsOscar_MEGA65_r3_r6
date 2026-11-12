// Psycho-Nics Oscar - original arcade DIP switch banks.
//
// OSD SW1/SW2 selections represent physical switch positions:
//   1 = switch ON, 0 = switch OFF.
// Arcade DIP inputs use active-low switch positions: ON = 0, OFF = 1.
//
// Position 1 is bit 0; position 8 is bit 7 in each bank.
// MAME World set defaults: SW1 = 8'h7f (upright), SW2 = 8'hff.
module jtoscar_dip (
    input  wire [7:0] sw1,
    input  wire [7:0] sw2,
    output wire [7:0] dsw0,
    output wire [7:0] dsw1
);
    assign dsw0 = ~sw1;
    assign dsw1 = ~sw2;
endmodule
