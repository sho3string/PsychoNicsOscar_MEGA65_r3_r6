// Psycho-Nics Oscar - connect game CPU logic and existing video pipeline.
// All ROM/RAM instances remain in the MiSTer2MEGA65 main.vhd.
module jtoscar_game (
    input  wire        clk,
    input  wire        rst,
    output wire        pxl_cen,
    output wire        HS,
    output wire        VS,
    output wire        LHBL,
    output wire        LVBL,
    output wire [3:0]  red,
    output wire [3:0]  green,
    output wire [3:0]  blue,

    // CPU buses and banked ROM address.
    output wire [15:0] cpu_addr,
    output wire [15:0] sub_addr,
    output wire [7:0]  cpu_dout,
    output wire [7:0]  sub_dout,
    output wire [15:0] bank_rom_addr,

    // CPU-side RAM write enables.
    output wire        shared_main_we,
    output wire        shared_sub_we,
    output wire        private_main_we,
    output wire        private_sub_we,
    output wire        char_hi_we,
    output wire        char_lo_we,
    output wire        bg_we,
    output wire        sprite_we,
    output wire        palette_we,

    // CPU-side ROM and RAM read data.
    input  wire [7:0]  shared_main_q,
    input  wire [7:0]  shared_sub_q,
    input  wire [7:0]  private_main_q,
    input  wire [7:0]  private_sub_q,
    input  wire [7:0]  cram_main_hi,
    input  wire [7:0]  cram_main_lo,
    input  wire [7:0]  bg_q,
    input  wire [7:0]  sprite_q,
    input  wire [7:0]  palette_q,
    input  wire [7:0]  main_rom_q,
    input  wire [7:0]  bank_rom_q,
    input  wire [7:0]  sub_rom_q,

    // Character RAM video read port.
    output wire [9:0]  cram_addr,
    input  wire [15:0] cram_data,

    // Character graphics ROM video read port.
    output wire [12:0] char_rom_addr,
    output wire        char_rom_cs,
    input  wire [23:0] char_rom_data,
    input  wire        char_rom_ok
);

    jtoscar_main u_main (
        .clk             ( clk             ),
        .rst             ( rst             ),
        .LVBL            ( LVBL            ),
        .cpu_addr        ( cpu_addr        ),
        .sub_addr        ( sub_addr        ),
        .cpu_dout        ( cpu_dout        ),
        .sub_dout        ( sub_dout        ),
        .bank_rom_addr   ( bank_rom_addr   ),

        .shared_main_we  ( shared_main_we  ),
        .shared_sub_we   ( shared_sub_we   ),
        .private_main_we ( private_main_we ),
        .private_sub_we  ( private_sub_we  ),
        .char_hi_we      ( char_hi_we      ),
        .char_lo_we      ( char_lo_we      ),
        .bg_we           ( bg_we           ),
        .sprite_we       ( sprite_we       ),
        .palette_we      ( palette_we      ),

        .shared_main_q   ( shared_main_q   ),
        .shared_sub_q    ( shared_sub_q    ),
        .private_main_q  ( private_main_q  ),
        .private_sub_q   ( private_sub_q   ),
        .cram_main_hi    ( cram_main_hi    ),
        .cram_main_lo    ( cram_main_lo    ),
        .bg_q            ( bg_q            ),
        .sprite_q        ( sprite_q        ),
        .palette_q       ( palette_q       ),
        .main_rom_q      ( main_rom_q      ),
        .bank_rom_q      ( bank_rom_q      ),
        .sub_rom_q       ( sub_rom_q       )
    );

    // Previously verified character renderer. Colour remains diagnostic.
    jtoscar_video u_video (
        .clk       ( clk           ),
        .rst       ( rst           ),
        .pxl_cen   ( pxl_cen       ),
        .HS        ( HS            ),
        .VS        ( VS            ),
        .LHBL      ( LHBL          ),
        .LVBL      ( LVBL          ),
        .char_addr ( char_rom_addr ),
        .char_cs   ( char_rom_cs   ),
        .char_data ( char_rom_data ),
        .char_ok   ( char_rom_ok   ),
        .cram_addr ( cram_addr     ),
        .cram_data ( cram_data     ),
        .red       ( red           ),
        .green     ( green         ),
        .blue      ( blue          )
    );

endmodule
