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

    // Main 6809 BAC06 control writes and external tilemap/ROM memory.
    input  wire [15:0] bac_cpu_addr,
    input  wire [7:0]  bac_cpu_dout,
    input  wire        bac_cpu_wr,
    output wire        bg_ram_cs,
    output wire [12:0] bg_ram_addr,
    input  wire [15:0] bg_ram_data,
    output wire        bg_rom_cs,
    output wire [16:0] bg_rom_addr,
    input  wire [31:0] bg_rom_data,

    // Original Oscar MXC06 sprite RAM CPU writes / DMA trigger.
    input  wire [15:0] obj_cpu_addr,
    input  wire [7:0]  obj_cpu_dout,
    input  wire        obj_cpu_wr,
    input  wire        obj_copy,

    // Sprite graphics ROMs (four 64 KiB planes in main.vhd).
    output wire        obj_rom_cs,
    output wire [16:0] obj_rom_addr,
    input  wire [31:0] obj_rom_data,

    // Character tilemap RAM from main.vhd (16-bit words, 1-cycle read)
    output wire [9:0]  cram_addr,
    input  wire [15:0] cram_data,

    // CPU-programmed 512 x 16-bit DECO RM-C3 palette RAM.
    output wire [8:0]  palette_addr,
    input  wire [15:0] palette_data,

    output wire [7:0]  red,
    output wire [7:0]  green,
    output wire [7:0]  blue,
    
    input  wire        flip
);

    // ------------------------------------------------------------
    // Pixel enable: unchanged (48 MHz / 8 = 6 MHz)
    // ------------------------------------------------------------
    reg [2:0] div8;
    reg pixel_ce_reg;

    assign pxl_cen = pixel_ce_reg;
    // Every fourth 48MHz clock. This overlaps every 6MHz pixel enable.
    wire pxl2_cen = div8[1:0] == 2'd0;

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
    wire [8:0] vrender;
    wire [8:0] vrender1;
    wire       hinit;
    wire       vload = vrender1 == 9'd7;

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
        .vrender  ( vrender ),
        .vrender1 ( vrender1),
        .H        ( hdump   ),
        .Hinit    ( hinit   ),
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
    wire [8:0] vchar = vdump - 9'd2;
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
        .HDUMP_OFFSET ( 0   ),
        .XOR_HFLIP    ( 1   )
    ) u_char (
        .rst         ( rst            ),
        .clk         ( clk            ),
        .pxl_cen     ( pxl_cen        ),
        .vdump       ( vchar          ),
        .hdump       ( hdump          ),
        .blankn      ( LVBL           ),
        .flip        ( flip           ),
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

    // The original video timer drives BAC06 in slave mode; no second timer.
    wire [7:0] bg_pxl;

    jtoscar_bac06 u_bac06 (
        .clk       ( clk          ),
        .rst       ( rst          ),
        .pxl_cen   ( pxl_cen      ),
        .pxl2_cen  ( pxl2_cen     ),
        .cpu_addr  ( bac_cpu_addr ),
        .cpu_dout  ( bac_cpu_dout ),
        .cpu_wr    ( bac_cpu_wr   ),
        .hdump     ( hdump        ),
        .vdump     ( vdump        ),
        .vrender   ( vrender      ),
        .LHBL      ( LHBL         ),
        .LVBL      ( LVBL         ),
        .HS        ( HS           ),
        .VS        ( VS           ),
        .ram_cs    ( bg_ram_cs    ),
        .ram_addr  ( bg_ram_addr  ),
        .ram_data  ( bg_ram_data  ),
        .ram_ok    ( 1'b1         ),
        .rom_cs    ( bg_rom_cs    ),
        .rom_addr  ( bg_rom_addr  ),
        .rom_data  ( bg_rom_data  ),
        .rom_ok    ( 1'b1         ),
        .bg_pxl    ( bg_pxl       ),
        .flip      ( flip         )
    );

    // Jotego MXC06 sprite engine. It contains the board's DMA copy RAM and
    // line buffer. CPU-facing sprite RAM remains in main.vhd for reads.
    // Original 6809 byte writes are mirrored into the MXC06 input RAM.
    wire [7:0] obj_pxl;
    wire [1:0] obj_cpu_dsn = !obj_cpu_wr ? 2'b11 :
                              obj_cpu_addr[0] ? 2'b10 : 2'b01;

    jtcop_obj u_obj (
        .rst        ( rst                         ),
        .clk        ( clk                         ),
        .clk_cpu    ( clk                         ),
        .pxl_cen    ( pxl_cen                     ),
        .HS         ( HS                          ),
        .LHBL       ( LHBL                        ),
        .LVBL       ( LVBL                        ),
        .flip         ( flip                      ),
        .hinit      ( hinit                       ),
        .vload      ( vload                       ),
        .hdump      ( hdump                       ),
        .vrender    ( vrender                     ),
        .ioctl_ram  ( 1'b0                        ),
        .ioctl_addr ( 11'd0                       ),
        .ioctl_din  (                             ),
        .cpu_addr   ( obj_cpu_addr[10:1]          ),
        .cpu_dout   ( {2{obj_cpu_dout}}           ),
        .obj_dout   (                             ),
        .cpu_dsn    ( obj_cpu_dsn                 ),
        .cpu_rnw    ( ~obj_cpu_wr                 ),
        .objram_cs  ( 1'b1                        ),
        .obj_copy   ( obj_copy                    ),
        .mixpsel    ( 1'b0                        ),
        .rom_cs     ( obj_rom_cs                  ),
        .rom_addr   ( obj_rom_addr                ),
        .rom_data   ( obj_rom_data                ),
        .rom_ok     ( 1'b1                        ),
        .pxl        ( obj_pxl                     )
    );

    // Foreground characters over sprites over the BAC06 background.
    jtoscar_colmix u_colmix (
        .clk          ( clk          ),
        .LHBL         ( LHBL         ),
        .LVBL         ( LVBL         ),
        .char_pxl     ( char_pxl     ),
        .bg_pxl       ( bg_pxl       ),
        .obj_pxl      ( obj_pxl      ),
        .palette_addr ( palette_addr ),
        .palette_data ( palette_data ),
        .red          ( red          ),
        .green        ( green        ),
        .blue         ( blue         )
    );
endmodule
