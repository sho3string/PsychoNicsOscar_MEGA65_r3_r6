// Psycho-Nics Oscar - main and sub 6809 CPUs, address decoding and I/O.
// Program ROMs and RAM are physically implemented in the MEGA65 main.vhd.
// JTFRAME supplies CPU clock enables, E/Q sequencing and bus timing.
module jtoscar_main (
    input  wire        clk,
    input  wire        rst,
    input  wire        LVBL,

    // CPU buses to external ROM/RAM in main.vhd.
    output wire [15:0] cpu_addr,
    output wire [15:0] sub_addr,
    output wire [7:0]  cpu_dout,
    output wire [7:0]  sub_dout,
    output wire [15:0] bank_rom_addr,

    // Memory write enables (CPU bus phase and address decoding).
    output wire        shared_main_we,
    output wire        shared_sub_we,
    output wire        private_main_we,
    output wire        private_sub_we,
    output wire        char_hi_we,
    output wire        char_lo_we,
    output wire        bg_we,
    output wire        bac_reg_wr,
    output wire        sprite_we,
    output wire        sprite_copy,
    output wire        palette_hi_we,
    output wire        palette_lo_we,

    // External RAM read data.
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

    // External program ROM read data.
    input  wire [7:0]  main_rom_q,
    input  wire [7:0]  bank_rom_q,
    input  wire [7:0]  sub_rom_q
);

    wire [7:0] cpu_din;
    wire [7:0] sub_din;
    wire       cpu_wr;
    wire       sub_wr;

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

    // Four 16 KiB banks from the existing 64 KiB ed09 image.
    assign bank_rom_addr = {bank_reg[1:0], cpu_addr[13:0]};

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

    // Main CPU chip selects. $0f00-$0fff is private to each CPU;
    // $0000-$0eff and $1000-$1fff are shared.
    wire main_private_cs = cpu_addr[15:8] == 8'h0f;
    wire main_shared_cs  = cpu_addr < 16'h2000 && !main_private_cs;
    wire char_cs         = cpu_addr >= 16'h2000 && cpu_addr < 16'h2800;
    wire bg_cs           = cpu_addr >= 16'h2800 && cpu_addr < 16'h3000;
    wire sprite_cs       = cpu_addr >= 16'h3000 && cpu_addr < 16'h3800;
    wire palette_cs      = cpu_addr >= 16'h3800 && cpu_addr < 16'h3c00;
    wire bank_cs         = cpu_addr >= 16'h4000 && cpu_addr < 16'h8000;
    wire fixed_rom_cs    = cpu_addr >= 16'h8000;

    wire sub_private_cs  = sub_addr[15:8] == 8'h0f;
    wire sub_shared_cs   = sub_addr < 16'h2000 && !sub_private_cs;
    wire sub_fixed_cs    = sub_addr >= 16'h4000;

    assign shared_main_we  = cpu_wr && main_shared_cs;
    assign shared_sub_we   = sub_wr && sub_shared_cs;
    assign private_main_we = cpu_wr && main_private_cs;
    assign private_sub_we  = sub_wr && sub_private_cs;
    assign char_hi_we      = cpu_wr && char_cs && !cpu_addr[0];
    assign char_lo_we      = cpu_wr && char_cs &&  cpu_addr[0];
    assign bg_we           = cpu_wr && bg_cs;
    assign bac_reg_wr      = cpu_wr && (
                             (cpu_addr >= 16'h3c00 && cpu_addr <= 16'h3c07) ||
                             (cpu_addr >= 16'h3c10 && cpu_addr <= 16'h3c1f)
                         );
    assign sprite_we       = cpu_wr && sprite_cs;
    assign sprite_copy     = cpu_wr && cpu_addr == 16'h3c80;
    assign palette_hi_we   = cpu_wr && palette_cs && !cpu_addr[0];
    assign palette_lo_we   = cpu_wr && palette_cs &&  cpu_addr[0];

    // Oscar CPU read mux. The memory outputs are synchronous BRAM data;
    // JTFRAME supplies the same stable bus timing as the working build.
    reg [7:0] main_data;
    reg [7:0] sub_data;

    assign cpu_din = main_data;
    assign sub_din = sub_data;

    always @* begin
        main_data = 8'hff;

        case (1'b1)
            main_private_cs: main_data = private_main_q;
            main_shared_cs:  main_data = shared_main_q;
            char_cs:         main_data = cpu_addr[0] ? cram_main_lo : cram_main_hi;
            bg_cs:           main_data = bg_q;
            sprite_cs:       main_data = sprite_q;
            palette_cs:      main_data = cpu_addr[0] ? palette_lo_q : palette_hi_q;
            bank_cs:         main_data = bank_rom_q;
            fixed_rom_cs:    main_data = main_rom_q;

            default: begin
                case (cpu_addr)
                    // Oscar IN2: VBLANK is active high on bit 7.
                    16'h3c02: main_data = LVBL ? 8'h7f : 8'hff;
                    // Original World / upright DIP defaults.
                    16'h3c03: main_data = 8'h7f;
                    16'h3c04: main_data = 8'hff;
                    default:  main_data = 8'hff;
                endcase
            end
        endcase
    end

    always @* begin
        sub_data = 8'hff;

        case (1'b1)
            sub_private_cs: sub_data = private_sub_q;
            sub_shared_cs:  sub_data = shared_sub_q;
            sub_fixed_cs:   sub_data = sub_rom_q;
            default:        sub_data = 8'hff;
        endcase
    end

endmodule
