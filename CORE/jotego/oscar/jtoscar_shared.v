// Psycho-Nics Oscar (DECO-8) - shared CPU RAM and inter-CPU IRQ latches
// Addresses and IRQ register meanings: MAME dec8.cpp oscar_map/oscar_sub_map.
// Both CPU ports must be synchronous to clk. This is NOT a CDC boundary.
// Arbitration contract: a/b access requests are accepted only when granted;
// simultaneous requests to RAM are serialized, A first then B. Hold request
// and address/data stable until grant. IRQ register writes use the same grant.
module jtoscar_shared (
    input  wire        clk,
    input  wire        rst,
    input  wire        a_req,
    input  wire        a_wr,
    input  wire [15:0] a_addr,
    input  wire [7:0]  a_din,
    output reg  [7:0]  a_dout,
    output reg         a_ack,
    input  wire        b_req,
    input  wire        b_wr,
    input  wire [15:0] b_addr,
    input  wire [7:0]  b_din,
    output reg  [7:0]  b_dout,
    output reg         b_ack,
    output reg         main_irq,
    output reg         sub_irq
);
    // Shared: $0000-$0eff (3840 bytes) and $1000-$1fff (4096 bytes).
    // $0f00-$0fff is PRIVATE to each CPU and must be implemented outside.
    reg [7:0] share1 [0:3839];
    reg [7:0] share2 [0:4095];
    wire a_ram = (a_addr <= 16'h0eff) ||
                 ((a_addr >= 16'h1000) && (a_addr <= 16'h1fff));
    wire b_ram = (b_addr <= 16'h0eff) ||
                 ((b_addr >= 16'h1000) && (b_addr <= 16'h1fff));
    wire a_irqreg = (a_addr >= 16'h3e80) && (a_addr <= 16'h3e83);
    wire b_irqreg = (b_addr >= 16'h3e80) && (b_addr <= 16'h3e83);
    wire a_valid = a_ram || a_irqreg;
    wire b_valid = b_ram || b_irqreg;
    // Priority is intentionally deterministic; not claimed to reproduce
    // physical DE-0301 bus phasing. CPU integration must honor ack/stall.
    wire take_a = a_req && a_valid;
    wire take_b = b_req && b_valid && !take_a;

    always @(posedge clk) begin
        a_ack <= 1'b0;
        b_ack <= 1'b0;
        if (rst) begin
            main_irq <= 1'b0;
            sub_irq  <= 1'b0;
            a_dout <= 8'hff;
            b_dout <= 8'hff;
        end else begin
            if (take_a) begin
                a_ack <= 1'b1;
                if (a_ram) begin
                    if (a_addr < 16'h0f00) begin
                        if (a_wr) share1[a_addr[11:0]] <= a_din;
                        a_dout <= share1[a_addr[11:0]];
                    end else begin
                        if (a_wr) share2[a_addr[11:0]] <= a_din;
                        a_dout <= share2[a_addr[11:0]];
                    end
                end else begin
                    a_dout <= 8'hff;
                    if (a_wr) begin
                        case (a_addr[1:0])
                            2'd0: sub_irq  <= 1'b1; // $3e80
                            2'd1: main_irq <= 1'b0; // $3e81
                            2'd2: main_irq <= 1'b1; // $3e82
                            2'd3: sub_irq  <= 1'b0; // $3e83
                        endcase
                    end
                end
            end else if (take_b) begin
                b_ack <= 1'b1;
                if (b_ram) begin
                    if (b_addr < 16'h0f00) begin
                        if (b_wr) share1[b_addr[11:0]] <= b_din;
                        b_dout <= share1[b_addr[11:0]];
                    end else begin
                        if (b_wr) share2[b_addr[11:0]] <= b_din;
                        b_dout <= share2[b_addr[11:0]];
                    end
                end else begin
                    b_dout <= 8'hff;
                    if (b_wr) begin
                        case (b_addr[1:0])
                            2'd0: sub_irq  <= 1'b1;
                            2'd1: main_irq <= 1'b0;
                            2'd2: main_irq <= 1'b1;
                            2'd3: sub_irq  <= 1'b0;
                        endcase
                    end
                end
            end
        end
    end
endmodule
