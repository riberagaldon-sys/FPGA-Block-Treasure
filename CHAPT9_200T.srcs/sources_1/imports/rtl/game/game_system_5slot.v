`timescale 1ns/1ps

// Chapter-9 game system.  Slot 1 (ui_state=2) is the real block-treasure
// game; slots 2..5 retain the Chapter-8 reference implementations.
module game_system_5slot(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [2:0]  ui_state_control,
    input  wire [2:0]  ui_state_frame,
    input  wire        event_up,
    input  wire        event_down,
    input  wire        event_left,
    input  wire        event_right,
    input  wire        event_ok,
    input  wire        event_back,
    input  wire        event_pause,
    input  wire        game_tick,
    input  wire        tick_1s,
    input  wire [10:0] pointer_x,
    input  wire [9:0]  pointer_y,
    input  wire        pointer_down,
    input  wire [10:0] pixel_x,
    input  wire [9:0]  pixel_y,
    output reg         pixel_on,
    output reg  [23:0] pixel_rgb,
    output reg  [15:0] score,
    output reg  [3:0]  game_state,
    output wire        exit_request
);

    wire [4:0] enable = {
        ui_state_control == 3'd6,
        ui_state_control == 3'd5,
        ui_state_control == 3'd4,
        ui_state_control == 3'd3,
        ui_state_control == 3'd2
    };

    wire [4:0]  slot_on;
    wire [23:0] slot_rgb0, slot_rgb1, slot_rgb2, slot_rgb3, slot_rgb4;
    wire [15:0] slot_score0, slot_score1, slot_score2, slot_score3, slot_score4;
    wire [3:0]  slot_state0, slot_state1, slot_state2, slot_state3, slot_state4;
    wire [4:0]  slot_exit;

    treasure_game u_game1_treasure (
        .clk(clk), .rst_n(rst_n), .game_enable(enable[0]),
        .event_up(event_up), .event_down(event_down),
        .event_left(event_left), .event_right(event_right),
        .event_ok(event_ok), .event_back(event_back),
        .event_pause(event_pause),
        .game_tick(game_tick), .tick_1s(tick_1s),
        .pointer_x(pointer_x), .pointer_y(pointer_y),
        .pointer_down(pointer_down),
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .pixel_on(slot_on[0]), .pixel_rgb(slot_rgb0),
        .score(slot_score0), .game_state(slot_state0),
        .exit_request(slot_exit[0])
    );

    game_stub #(.SLOT_ID(2), .BG_COLOR(24'h6D4AA5), .FG_COLOR(24'hF4F4F4)) u_game2 (
        clk, rst_n, enable[1], event_up, event_down, event_left, event_right,
        event_ok, event_back, event_pause, game_tick, tick_1s, pixel_x, pixel_y,
        slot_on[1], slot_rgb1, slot_score1, slot_state1, slot_exit[1]);

    game_stub #(.SLOT_ID(3), .BG_COLOR(24'h2A9DAD), .FG_COLOR(24'hF4F4F4)) u_game3 (
        clk, rst_n, enable[2], event_up, event_down, event_left, event_right,
        event_ok, event_back, event_pause, game_tick, tick_1s, pixel_x, pixel_y,
        slot_on[2], slot_rgb2, slot_score2, slot_state2, slot_exit[2]);

    game_stub #(.SLOT_ID(4), .BG_COLOR(24'hA83A3A), .FG_COLOR(24'hF4F4F4)) u_game4 (
        clk, rst_n, enable[3], event_up, event_down, event_left, event_right,
        event_ok, event_back, event_pause, game_tick, tick_1s, pixel_x, pixel_y,
        slot_on[3], slot_rgb3, slot_score3, slot_state3, slot_exit[3]);

    game_stub #(.SLOT_ID(5), .BG_COLOR(24'h202020), .FG_COLOR(24'hE3B341)) u_game5 (
        clk, rst_n, enable[4], event_up, event_down, event_left, event_right,
        event_ok, event_back, event_pause, game_tick, tick_1s, pixel_x, pixel_y,
        slot_on[4], slot_rgb4, slot_score4, slot_state4, slot_exit[4]);

    assign exit_request = |slot_exit;

    always @(*) begin
        pixel_on  = 1'b0;
        pixel_rgb = 24'h000000;
        score     = 16'd0;
        game_state= 4'd0;

        case (ui_state_frame)
            3'd2: begin pixel_on=slot_on[0]; pixel_rgb=slot_rgb0; score=slot_score0; game_state=slot_state0; end
            3'd3: begin pixel_on=slot_on[1]; pixel_rgb=slot_rgb1; score=slot_score1; game_state=slot_state1; end
            3'd4: begin pixel_on=slot_on[2]; pixel_rgb=slot_rgb2; score=slot_score2; game_state=slot_state2; end
            3'd5: begin pixel_on=slot_on[3]; pixel_rgb=slot_rgb3; score=slot_score3; game_state=slot_state3; end
            3'd6: begin pixel_on=slot_on[4]; pixel_rgb=slot_rgb4; score=slot_score4; game_state=slot_state4; end
            default: begin pixel_on=1'b0; pixel_rgb=24'h000000; score=16'd0; game_state=4'd0; end
        endcase
    end

endmodule
