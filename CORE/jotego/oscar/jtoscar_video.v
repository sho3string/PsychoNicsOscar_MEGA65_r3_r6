// Psycho-Nics Oscar - character-ROM video bring-up
//
// 48 MHz FPGA clock, 6 MHz pixel enable.
// Original jtframe_vtimer timings preserved from jtoscar_video(3).v.
//
// Display: jtframe_tilemap reads live 2 KiB character RAM written by the main 6809.
// ROM data is 3 x 8-bit planes in {bit2,bit1,bit0} order; the external
// ROM adapter supplies it from the original ed08 image.
//
// NOTE: The new char_* ports must be connected in the parent module.
//       Expected char_data timing: 1-cycle synchronous 48 MHz BRAM read.

module jtoscar_video (
    input  wire        clk,
    input  wire        rst,
    output wire        pxl_cen,
    output wire        HS,
    output wire        VS,
    output wire        LHBL,
    output wire        LVBL,

    // Character ROM interface, as used by jtframe_tilemap.
    output wire [12:0] char_addr,  // {10-bit code, 3-bit row}
    output wire        char_cs,
    input  wire [23:0] char_data,  // {plane2, plane1, plane0}
    input  wire        char_ok,

    // Character tilemap RAM from main.vhd (16-bit words, 1-cycle read)
    output wire [9:0]  cram_addr,
    input  wire [15:0] cram_data,

    output wire [3:0]  red,
    output wire [3:0]  green,
    output wire [3:0]  blue
);

    // ------------------------------------------------------------
    // Pixel enable: unchanged (48 MHz / 8 = 6 MHz)
    // ------------------------------------------------------------
    reg [2:0] div8;
    reg pixel_ce_reg;

    assign pxl_cen = pixel_ce_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            div8         <= 3'd0;
            pixel_ce_reg <= 1'b0;
        end else begin
            div8         <= div8 + 3'd1;
            pixel_ce_reg <= (div8 == 3'd7);
        end
    end

    // ------------------------------------------------------------
    // JTFRAME video timer: original values unchanged
    // ------------------------------------------------------------
    wire [8:0] hdump;
    wire [8:0] vdump;

    jtframe_vtimer #(
        .VB_START ( 9'd248 ),
        .VB_END   ( 9'd8   ),
        .VCNT_END ( 9'd271 ),
        .VS_START ( 9'd256 ),
        .HS_START ( 9'd432 ),
        .HB_START ( 9'd384 ),
        .HJUMP    ( 1      ),
        .HB_END   ( 9'd0   ),
        .HINIT    ( 9'd128 )
    ) u_vtimer (
        .clk      ( clk     ),
        .pxl_cen  ( pxl_cen ),
        .vdump    ( vdump   ),
        .vrender  (         ),
        .vrender1 (         ),
        .H        ( hdump   ),
        .Hinit    (         ),
        .Vinit    (         ),
        .LHBL     ( LHBL    ),
        .LVBL     ( LVBL    ),
        .HS       ( HS      ),
        .VS       ( VS      )
    );

    // ------------------------------------------------------------
    // Character map: 32x32 entries, 8x8 pixels each.
    // Oscar's character RAM contains [attribute, code] byte pairs.
    // Keep the existing video timing and diagnostic H/V offsets.
    // ------------------------------------------------------------
    wire [8:0] vchar = vdump - 9'd8;
    wire [9:0] char_vram_addr;
    wire [5:0] char_pxl;

    assign cram_addr = char_vram_addr;

    jtframe_tilemap #(
        .SIZE         ( 8   ),
        .VA           ( 10  ),  // 32x32 tilemap, 1024 entries
        .CW           ( 10  ),  // 1024 character codes
        .PW           ( 6   ),  // 3 palette bits + 3 pixel bits
        .BPP          ( 3   ),
        .MAP_HW       ( 8   ),
        .MAP_VW       ( 8   ),
        .HDUMP_OFFSET ( 0   )
    ) u_char (
        .rst         ( rst            ),
        .clk         ( clk            ),
        .pxl_cen     ( pxl_cen        ),
        .vdump       ( vchar          ),
        .hdump       ( hdump          ),
        .blankn      ( LVBL           ),
        .flip        ( 1'b0           ),
        .vram_addr   ( char_vram_addr ),
        .code        ( {cram_data[9:8], cram_data[7:0]} ),
        .pal         ( {1'b0, cram_data[15:14]} ),
        .hflip       ( 1'b0           ),
        .vflip       ( 1'b0           ),
        .rom_cs      ( char_cs        ),
        .rom_addr    ( char_addr      ),
        .rom_data    ( char_data      ),
        .rom_ok      ( char_ok        ),
        .pxl         ( char_pxl       )
    );

    // Temporary monochrome colour mixer. Oscar's hardware palette and
    // layer priority logic are not implemented yet. Character attributes are not yet converted to arcade RGB.
    jtoscar_colmix u_colmix (
        .LHBL     ( LHBL     ),
        .LVBL     ( LVBL     ),
        .char_pxl ( char_pxl ),
        .red      ( red      ),
        .green    ( green    ),
        .blue     ( blue     )
    );
endmodule
