// Psycho-Nics Oscar - two 6809 CPUs and character video.
// Program ROMs and RAM are implemented in main.vhd.
// JTFRAME supplies CPU clock enables, E/Q sequencing and bus timing.
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

    // Main and sub CPU buses; all memory is external in main.vhd.
    output wire [15:0] cpu_addr,
    output wire [15:0] sub_addr,
    output wire [7:0]  cpu_dout,
    output wire [7:0]  sub_dout,
    input  wire [7:0]  cpu_din,
    input  wire [7:0]  sub_din,
    output wire        cpu_wr,
    output wire        sub_wr,
    output wire        cpu_rd,
    output wire        sub_rd,
    output wire [3:0]  bank,

    // Character RAM video port.
    output wire [9:0]  cram_addr,
    input  wire [15:0] cram_data,

    // Character graphics ROM port.
    output wire [12:0] char_rom_addr,
    output wire        char_rom_cs,
    input  wire [23:0] char_rom_data,
    input  wire        char_rom_ok
);

    wire cen6;
    wire main_cpu_cen;
    wire sub_cpu_cen;
    wire main_rw;
    wire sub_rw;
    wire main_vma;
    wire sub_vma;
    wire main_rom_cs;
    wire sub_rom_cs;

    reg [3:0] bank_reg = 4'd0;
    reg       main_irq = 1'b0;
    reg       sub_irq  = 1'b0;

    assign bank = bank_reg;

    // 48 MHz / 8 = 6 MHz enable. The 6809 wrapper divides this by four
    // and generates correctly sequenced E/Q enables: 1.5 MHz CPU cycles.
    jtframe_cen48 u_cen48 (
        .clk    ( clk  ),
        .cen6   ( cen6 )
    );

    assign main_rom_cs = cpu_addr[15] | cpu_addr[14];
    assign sub_rom_cs  = sub_addr[15] | sub_addr[14];

    // RAM_AW=0 disables the wrapper's internal RAM because Oscar's memory
    // is shared with the sub CPU and implemented separately in main.vhd.
    // All program ROMs are local BRAM: no ROM wait state is required.
    jtframe_sys6809 #(
        .RAM_AW   ( 0 ),
        .RECOVERY ( 0 )
    ) u_main_cpu (
        .rstn     ( ~rst          ),
        .clk      ( clk           ),
        .cen      ( cen6          ),
        .cpu_cen  ( main_cpu_cen  ),
        .nIRQ     ( ~main_irq     ),
        .nFIRQ    ( 1'b1          ),
        .nNMI     ( 1'b1          ),
        .irq_ack  (               ),
        .bus_busy ( 1'b0          ),
        .A        ( cpu_addr      ),
        .RnW      ( main_rw       ),
        .VMA      ( main_vma      ),
        .ram_cs   ( 1'b0          ),
        .rom_cs   ( main_rom_cs   ),
        .rom_ok   ( 1'b1          ),
        .ram_dout (               ),
        .cpu_dout ( cpu_dout      ),
        .cpu_din  ( cpu_din       )
    );

    jtframe_sys6809 #(
        .RAM_AW   ( 0 ),
        .RECOVERY ( 0 )
    ) u_sub_cpu (
        .rstn     ( ~rst          ),
        .clk      ( clk           ),
        .cen      ( cen6          ),
        .cpu_cen  ( sub_cpu_cen   ),
        .nIRQ     ( ~sub_irq      ),
        .nFIRQ    ( 1'b1          ),
        .nNMI     ( 1'b1          ),
        .irq_ack  (               ),
        .bus_busy ( 1'b0          ),
        .A        ( sub_addr      ),
        .RnW      ( sub_rw        ),
        .VMA      ( sub_vma       ),
        .ram_cs   ( 1'b0          ),
        .rom_cs   ( sub_rom_cs    ),
        .rom_ok   ( 1'b1          ),
        .ram_dout (               ),
        .cpu_dout ( sub_dout      ),
        .cpu_din  ( sub_din       )
    );

    // JTFRAME uses the Q clock-enable phase for CPU memory writes.
    // VMA prevents writes during invalid bus cycles.
    assign cpu_wr = main_cpu_cen & main_vma & ~main_rw;
    assign sub_wr = sub_cpu_cen  & sub_vma  & ~sub_rw;
    assign cpu_rd = main_cpu_cen & main_vma &  main_rw;
    assign sub_rd = sub_cpu_cen  & sub_vma  &  sub_rw;

    // Oscar main/sub interrupt handshake and main ROM bank register.
    always @(posedge clk) begin
        if (rst) begin
            bank_reg <= 4'd0;
            main_irq <= 1'b0;
            sub_irq  <= 1'b0;
        end else begin
            if (cpu_wr) begin
                if (cpu_addr == 16'h3d00)
                    bank_reg <= cpu_dout[3:0];

                case (cpu_addr)
                    16'h3e80: sub_irq  <= 1'b1;
                    16'h3e81: main_irq <= 1'b0;
                    16'h3e82: main_irq <= 1'b1;
                    16'h3e83: sub_irq  <= 1'b0;
                    default: ;
                endcase
            end

            if (sub_wr) begin
                case (sub_addr)
                    16'h3e80: sub_irq  <= 1'b1;
                    16'h3e81: main_irq <= 1'b0;
                    16'h3e82: main_irq <= 1'b1;
                    16'h3e83: sub_irq  <= 1'b0;
                    default: ;
                endcase
            end
        end
    end

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
