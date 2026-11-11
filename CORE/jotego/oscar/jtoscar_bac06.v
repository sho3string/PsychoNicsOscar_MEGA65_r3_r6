// Psycho-Nics Oscar - 8-bit 6809 interface for Jotego's BAC06.
//
// Uses jtcop_bac06.v from jtcores/cores/cop/hdl, unmodified.
// MASTER=0: existing jtoscar_video timing remains authoritative.
//
// MAME: dec8.cpp oscar_map and decbac06.h ctrlreg8_w(),
// scrollreg8_w<false>(), vram8_w<false>().
//
// This is an interface-stage module. Connect its external RAM/ROM ports
// to the MEGA65 BRAM instances before enabling background pixels in colmix.

module jtoscar_bac06 (
    input  wire        clk,
    input  wire        rst,
    input  wire        pxl_cen,
    input  wire        pxl2_cen,

    // From jtoscar_main: one-clock CPU write strobe and 6809 bus.
    input  wire [15:0] cpu_addr,
    input  wire [7:0]  cpu_dout,
    input  wire        cpu_wr,

    // From the existing jtoscar_video video timer.
    input  wire [8:0]  hdump,
    input  wire [8:0]  vdump,
    input  wire [8:0]  vrender,
    input  wire        LHBL,
    input  wire        LVBL,
    input  wire        HS,
    input  wire        VS,

    // Background tilemap/scroll RAM: video-read port in main.vhd.
    output wire        ram_cs,
    output wire [13:1] ram_addr,
    input  wire [15:0] ram_data,
    input  wire        ram_ok,

    // Background graphics ROM: external plane banks in main.vhd.
    output wire        rom_cs,
    output wire [17:1] rom_addr,
    input  wire [31:0] rom_data,
    input  wire        rom_ok,

    // Four palette bits and four pixel bits, for future colmix.
    output wire [7:0]  bg_pxl
);

    // Oscar $3c00-$3c07: BAC06 control registers (read addresses
    // at $3c00-$3c04 remain the separate cabinet/DIP inputs).
    wire ctrl0_cs = (cpu_addr >= 16'h3c00) && (cpu_addr <= 16'h3c07);

    // Oscar $3c10-$3c1f: BAC06 scroll registers.
    wire ctrl1_cs = (cpu_addr >= 16'h3c10) && (cpu_addr <= 16'h3c1f);

    wire bac_reg_wr = cpu_wr && (ctrl0_cs || ctrl1_cs);

    // Jotego's address port is [12:1], a WORD address. Its [4] is
    // the control/scroll bank select, while [2:1] selects registers 0-3.
    wire [12:1] bac_cpu_addr = {8'd0, cpu_addr[4], 1'b0, cpu_addr[2:1]};

    // The BAC06 control registers use the LOW 8-bit lane regardless
    // of the 6809 odd/even byte address: MAME ctrlreg8_w(offset>>1).
    //
    // Scroll X/Y are 16-bit, big endian on the 6809 bus:
    //  $3c10/$3c11 : X high/low
    //  $3c12/$3c13 : Y high/low
    //  $3c14-$3c17 : shift values, low byte, mirrored
    // and likewise at $3c18-$3c1f.
    reg [1:0] bac_dsn;

    always @* begin
        bac_dsn = 2'b11;

        if (bac_reg_wr) begin
            if (ctrl0_cs || cpu_addr[2]) begin
                bac_dsn = 2'b10;  // low byte enabled
            end else if (cpu_addr[0]) begin
                bac_dsn = 2'b10;  // scroll low byte
            end else begin
                bac_dsn = 2'b01;  // scroll high byte
            end
        end
    end

    // MASTER=0 does not drive the timer or flip nets. Oscar is upright
    // for this checkpoint, so drive flip explicitly rather than leave Z.
    wire bac_flip = 1'b0;
    wire bac_vload;
    wire bac_hinit;
    wire [15:0] bac_cpu_din;
    wire [7:0]  bac_status;

    jtcop_bac06 #(
        .MASTER ( 0 )
    ) u_bac06 (
        .rst       ( rst                        ),
        .clk       ( clk                        ),
        .clk_cpu   ( clk                        ),
        .pxl2_cen  ( pxl2_cen                   ),
        .pxl_cen   ( pxl_cen                    ),

        .mode_cs   ( bac_reg_wr                 ),
        .flip      ( bac_flip                   ),
        .cpu_dout  ( {cpu_dout, cpu_dout}       ),
        .cpu_din   ( bac_cpu_din                ),
        .cpu_addr  ( bac_cpu_addr               ),
        .cpu_rnw   ( ~bac_reg_wr                ),
        .cpu_dsn   ( bac_dsn                    ),

        .vdump     ( vdump                      ),
        .vrender   ( vrender                    ),
        .hdump     ( hdump                      ),
        .LHBL      ( LHBL                       ),
        .LVBL      ( LVBL                       ),
        .HS        ( HS                         ),
        .VS        ( VS                         ),
        .vload     ( bac_vload                  ),
        .hinit     ( bac_hinit                  ),

        .ram_cs    ( ram_cs                     ),
        .ram_addr  ( ram_addr                   ),
        .ram_data  ( ram_data                   ),
        .ram_ok    ( ram_ok                     ),

        .rom_cs    ( rom_cs                     ),
        .rom_addr  ( rom_addr                   ),
        .rom_data  ( rom_data                   ),
        .rom_ok    ( rom_ok                     ),

        .pxl       ( bg_pxl                     ),
        .st_addr   ( 8'd0                       ),
        .st_dout   ( bac_status                 )
    );

endmodule
