// Psycho-Nics Oscar - connect game CPU logic and existing video pipeline.
// All ROM/RAM instances remain in the MiSTer2MEGA65 main.vhd.
module jtoscar_game (
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  dip_sw1,
    input  wire [7:0]  dip_sw2,
    output wire        pxl_cen,
    output wire        HS,
    output wire        VS,
    output wire        LHBL,
    output wire        LVBL,
    output wire [7:0]  red,
    output wire [7:0]  green,
    output wire [7:0]  blue,
    output wire signed [15:0] audio_ym2203,
    output wire signed [15:0] audio_ym3526,

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
    output wire        bac_reg_wr,
    output wire        sprite_we,
    output wire        palette_hi_we,
    output wire        palette_lo_we,

    // CPU-side ROM and RAM read data.
    input  wire [7:0]  shared_main_q,
    input  wire [7:0]  shared_sub_q,
    input  wire [7:0]  private_main_q,
    input  wire [7:0]  private_sub_q,
    input  wire [7:0]  cram_main_hi,
    input  wire [7:0]  cram_main_lo,
    input  wire [7:0]  bg_q,
    input  wire [7:0]  sprite_q,
    input  wire [7:0]  palette_hi_q,
    input  wire [7:0]  palette_lo_q,
    input  wire [7:0]  main_rom_q,
    input  wire [7:0]  bank_rom_q,
    input  wire [7:0]  sub_rom_q,

    // Character RAM video read port.
    output wire [9:0]  cram_addr,
    input  wire [15:0] cram_data,

    // 512-entry palette RAM, read on the 48 MHz video clock.
    output wire [8:0]  palette_addr,
    input  wire [15:0] palette_data,

    // Character graphics ROM video read port.
    output wire [12:0] char_rom_addr,
    output wire        char_rom_cs,
    input  wire [23:0] char_rom_data,
    input  wire        char_rom_ok,

    // Jotego BAC06 reads tilemap RAM and graphics ROM from main.vhd.
    output wire        bg_ram_cs,
    output wire [12:0] bg_ram_addr,
    input  wire [15:0] bg_ram_data,
    output wire        bg_rom_cs,
    output wire [16:0] bg_rom_addr,
    input  wire [31:0] bg_rom_data,

    // MXC06 original sprite ROMs (ed04, ed05, ed06, ed07).
    output wire        obj_rom_cs,
    output wire [16:0] obj_rom_addr,
    input  wire [31:0] obj_rom_data,

    // DECO 222 sound CPU memory remains in main.vhd.
    output wire [14:0] sound_rom_addr,
    input  wire [7:0]  sound_rom_data,
    output wire [10:0] sound_ram_addr,
    output wire [7:0]  sound_ram_dout,
    output wire        sound_ram_we,
    input  wire [7:0]  sound_ram_data
);

    wire sprite_copy;
    wire sound_wr;

    jtoscar_main u_main (
        .clk             ( clk             ),
        .rst             ( rst             ),
        .LVBL            ( LVBL            ),
        .dip_sw1         ( dip_sw1         ),
        .dip_sw2         ( dip_sw2         ),
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
        .bac_reg_wr      ( bac_reg_wr      ),
        .sprite_we       ( sprite_we       ),
        .sprite_copy     ( sprite_copy     ),
        .sound_wr        ( sound_wr        ),
        .palette_hi_we   ( palette_hi_we   ),
        .palette_lo_we   ( palette_lo_we   ),

        .shared_main_q   ( shared_main_q   ),
        .shared_sub_q    ( shared_sub_q    ),
        .private_main_q  ( private_main_q  ),
        .private_sub_q   ( private_sub_q   ),
        .cram_main_hi    ( cram_main_hi    ),
        .cram_main_lo    ( cram_main_lo    ),
        .bg_q            ( bg_q            ),
        .sprite_q        ( sprite_q        ),
        .palette_hi_q    ( palette_hi_q    ),
        .palette_lo_q    ( palette_lo_q    ),
        .main_rom_q      ( main_rom_q      ),
        .bank_rom_q      ( bank_rom_q      ),
        .sub_rom_q       ( sub_rom_q       )
    );

    // Existing character renderer with live palette-RAM colour lookup.
    jtoscar_video u_video (
        .clk          ( clk          ),
        .rst          ( rst          ),
        .pxl_cen      ( pxl_cen      ),
        .HS           ( HS           ),
        .VS           ( VS           ),
        .LHBL         ( LHBL         ),
        .LVBL         ( LVBL         ),
        .char_addr    ( char_rom_addr ),
        .char_cs      ( char_rom_cs   ),
        .char_data    ( char_rom_data ),
        .char_ok      ( char_rom_ok   ),
        .bac_cpu_addr ( cpu_addr      ),
        .bac_cpu_dout ( cpu_dout      ),
        .bac_cpu_wr   ( bac_reg_wr    ),
        .bg_ram_cs    ( bg_ram_cs     ),
        .bg_ram_addr  ( bg_ram_addr   ),
        .bg_ram_data  ( bg_ram_data   ),
        .bg_rom_cs    ( bg_rom_cs     ),
        .bg_rom_addr  ( bg_rom_addr   ),
        .bg_rom_data  ( bg_rom_data   ),
        .obj_cpu_addr  ( cpu_addr      ),
        .obj_cpu_dout  ( cpu_dout      ),
        .obj_cpu_wr    ( sprite_we     ),
        .obj_copy      ( sprite_copy   ),
        .obj_rom_cs    ( obj_rom_cs    ),
        .obj_rom_addr  ( obj_rom_addr  ),
        .obj_rom_data  ( obj_rom_data  ),
        .cram_addr    ( cram_addr    ),
        .cram_data    ( cram_data    ),
        .palette_addr ( palette_addr ),
        .palette_data ( palette_data ),
        .red          ( red          ),
        .green        ( green        ),
        .blue         ( blue         )
    );

    // DECO 222 (T65) / YM2203 / YM3526. Video path is unchanged.
    jtoscar_sound u_sound (
        .clk            ( clk            ),
        .rst            ( rst            ),
        .sound_cmd      ( cpu_dout       ),
        .sound_cmd_wr   ( sound_wr       ),
        .rom_addr       ( sound_rom_addr ),
        .rom_data       ( sound_rom_data ),
        .ram_addr       ( sound_ram_addr ),
        .ram_dout       ( sound_ram_dout ),
        .ram_we         ( sound_ram_we   ),
        .ram_data       ( sound_ram_data ),
        .ym2203_pcm     ( audio_ym2203  ),
        .ym3526_pcm     ( audio_ym3526  )
    );

endmodule
