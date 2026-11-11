// Psycho-Nics Oscar audio subsystem.
// DECO 222 sound CPU (T65), YM2203/JT03 and YM3526/JTOPL.
// External program ROM and RAM are physically stored in main.vhd.

module jtoscar_sound (
    input  wire        clk,
    input  wire        rst,

    input  wire [7:0]  sound_cmd,
    input  wire        sound_cmd_wr,

    output wire [14:0] rom_addr,
    input  wire [7:0]  rom_data,
    output wire [10:0] ram_addr,
    output wire [7:0]  ram_dout,
    output wire        ram_we,
    input  wire [7:0]  ram_data,

    output wire signed [15:0] ym2203_pcm,
    output wire signed [15:0] ym3526_pcm
);

    wire cen1p5;
    wire cen3;

    // Original crystal 12 MHz: audio 6502 and YM2203 at 1.5 MHz,
    // YM3526 at 3 MHz. JTFRAME derives both enables from 48 MHz.
    jtframe_cen48 u_sound_cen (
        .clk    ( clk    ),
        .cen1p5 ( cen1p5 ),
        .cen3   ( cen3   )
    );

    wire [15:0] cpu_addr;
    wire [7:0]  cpu_dout;
    wire [7:0]  cpu_din;
    wire        cpu_rnw;
    wire        cpu_wr;
    wire        opl_irq_n;

    reg  [7:0] sound_latch = 8'h00;
    reg        sound_pending = 1'b0;

    // CPU writes $3D80, sound CPU reads $6000; pending raises NMI.
    // Reading the sound latch clears the NMI request.
    always @(posedge clk) begin
        if (rst) begin
            sound_latch    <= 8'h00;
            sound_pending <= 1'b0;
        end else begin
            if (cen1p5 && cpu_rnw && cpu_addr == 16'h6000)
                sound_pending <= 1'b0;

            if (sound_cmd_wr) begin
                sound_latch    <= sound_cmd;
                sound_pending <= 1'b1;
            end
        end
    end

    jtoscar_deco222 u_sound_cpu (
        .clk         ( clk              ),
        .reset       ( rst              ),
        .cpu_cen     ( cen1p5           ),
        .irq_n       ( opl_irq_n        ),
        .nmi_n       ( ~sound_pending   ),
        .address     ( cpu_addr         ),
        .data_in     ( cpu_din          ),
        .data_out    ( cpu_dout         ),
        .read_nwrite ( cpu_rnw          ),
        .write_strobe ( cpu_wr           )
    );

    assign rom_addr = cpu_addr[14:0];
    assign ram_addr = cpu_addr[10:0];
    assign ram_dout = cpu_dout;
    assign ram_we   = cpu_wr && cpu_addr < 16'h0600;

    assign cpu_din = cpu_addr < 16'h0600 ? ram_data :
                     cpu_addr == 16'h6000 ? sound_latch :
                     cpu_addr[15] ? rom_data : 8'hff;

    wire ym2203_wr = cpu_wr && cpu_addr[15:1] == 15'h1000;
    wire ym3526_wr = cpu_wr && cpu_addr[15:1] == 15'h2000;


    jt03 u_ym2203 (
        .rst         ( rst          ),
        .clk         ( clk          ),
        .cen         ( cen1p5       ),
        .din         ( cpu_dout     ),
        .addr        ( cpu_addr[0]  ),
        .cs_n        ( ~ym2203_wr   ),
        .wr_n        ( ~ym2203_wr   ),
        .dout        (              ),
        .irq_n       (              ),
        .IOA_in      ( 8'hff        ),
        .IOB_in      ( 8'hff        ),
        .IOA_out     (              ),
        .IOB_out     (              ),
        .IOA_oe      (              ),
        .IOB_oe      (              ),
        .psg_A       (              ),
        .psg_B       (              ),
        .psg_C       (              ),
        .fm_snd      (              ),
        .psg_snd     (              ),
        .snd         ( ym2203_pcm   ),
        .snd_sample  (              ),
        .debug_view  (              )
    );

    // YM3526 (not the YM3812/OPL2). Its IRQ drives the sound 6502.
    jtopl u_ym3526 (
        .rst         ( rst          ),
        .clk         ( clk          ),
        .cen         ( cen3         ),
        .din         ( cpu_dout     ),
        .addr        ( cpu_addr[0]  ),
        .cs_n        ( ~ym3526_wr   ),
        .wr_n        ( ~ym3526_wr   ),
        .dout        (              ),
        .irq_n       ( opl_irq_n    ),
        .snd         ( ym3526_pcm   ),
        .sample      (              )
    );

endmodule
