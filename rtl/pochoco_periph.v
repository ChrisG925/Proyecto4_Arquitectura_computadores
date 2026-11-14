// Copyright 2026 Universidad de los Andes.
// Licensed under the Solderpad Hardware License, Version 0.51 (the "License");
// you may not use this file except in compliance with the License.
// SPDX-License-Identifier: SHL-0.51
//
// Course: Arquitectura de Computadores (2026)
// 
// Authors:
// - Nicolás Villegas <navillegas@miuandes.cl>

module pochoco_periph (
  input  wire        clk_i,
  input  wire        rst_ni,
  input  wire        sel_i,
  input  wire        req_i,
  input  wire        we_i,
  input  wire [7:0]  addr_i,
  input  wire [31:0] wdata_i,
  output reg  [31:0] rdata_o,
  output wire [3:0]  leds_o,
  input  wire [3:0]  btn_i,
  output wire [6:0]  seg1_o,
  output wire [6:0]  seg2_o
);

  wire [5:0] off    = addr_i[7:2];
  wire       access = sel_i & req_i;

  // LEDs and raw digit registers
  reg [3:0]  led_q;
  reg [7:0]  digit_q;


  // Aceleracion 1: comparador para estrategia de trading
  reg [13:0] trade_sum_q;
  reg [1:0]  trade_result_q;

  // Precio de 8 bits y suma movil de 64 precios.
  // Las concatenaciones son conexiones fijas de hardware.
  wire [8:0] price_plus_gap;
  wire [14:0] buy_threshold;
  wire [14:0] sell_threshold;

  assign price_plus_gap = {1'b0, wdata_i[7:0]} + 9'd4;

  assign buy_threshold  = {price_plus_gap, 6'b0};
  assign sell_threshold = {1'b0, wdata_i[7:0], 6'b0};

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      trade_sum_q    <= 14'd0;
      trade_result_q <= 2'b00;
    end else if (access && we_i) begin
      case (off)
        6'd4: trade_sum_q <= wdata_i[13:0];

        6'd5: begin
          trade_result_q[0] <=
              {1'b0, trade_sum_q} >= buy_threshold;

          trade_result_q[1] <=
              sell_threshold >= {1'b0, trade_sum_q};
        end

        default: ;
      endcase
    end
  end


  //agregado mio
  reg [31:0] cycle_counter_q;
  always @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni)
    cycle_counter_q <= 32'b0;
  else
    cycle_counter_q <= cycle_counter_q + 32'd1;
end

//fin de agregado mio

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      led_q   <= 4'b0;
      digit_q <= 8'b0;
    end else if (access & we_i) begin
      case (off)
        6'd0: digit_q <= wdata_i[7:0];
        6'd1: led_q   <= wdata_i[3:0];
        default: ;
      endcase
    end
  end

  assign leds_o = led_q;

  // Hex to 7-segment decoder function
  function [6:0] hex2seg;
    input [3:0] hex;
    begin
      case (hex)
        4'h0: hex2seg = 7'b0111111; // 0
        4'h1: hex2seg = 7'b0000110; // 1
        4'h2: hex2seg = 7'b1011011; // 2
        4'h3: hex2seg = 7'b1001111; // 3
        4'h4: hex2seg = 7'b1100110; // 4
        4'h5: hex2seg = 7'b1101101; // 5
        4'h6: hex2seg = 7'b1111101; // 6
        4'h7: hex2seg = 7'b0000111; // 7
        4'h8: hex2seg = 7'b1111111; // 8
        4'h9: hex2seg = 7'b1101111; // 9
        4'hA: hex2seg = 7'b1110111; // A
        4'hB: hex2seg = 7'b1111100; // b
        4'hC: hex2seg = 7'b0111001; // C
        4'hD: hex2seg = 7'b1011110; // d
        4'hE: hex2seg = 7'b1111001; // E
        4'hF: hex2seg = 7'b1110001; // F
        default: hex2seg = 7'b0000000;
      endcase
    end
  endfunction

  assign seg1_o = hex2seg(digit_q[7:4]);
  assign seg2_o = hex2seg(digit_q[3:0]);

  // Registered read data
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) rdata_o <= 32'b0;
    else if (access & ~we_i) begin
      
      case (off)
        6'd2: rdata_o <= {28'b0, btn_i};
        6'd3: rdata_o <= cycle_counter_q;
        6'd6: rdata_o <= {30'b0, trade_result_q};
        default: rdata_o <= 32'b0;
      endcase
    end
  end

endmodule