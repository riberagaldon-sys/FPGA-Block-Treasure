`timescale 1ns/1fs

// Teaching-manual Chapter 10 -> chapter9_block_treasure_200t.xpr.
// Simulation top: tb_chapter10_all. Run 200 us. Expected: CH10 PASS.
// Tests the original game_system_5slot, its actual first-slot treasure_game,
// and the original four game_stub instances. No RTL edits/forces are used.
// UI control/frame page codes and game events enter at the module ports.
// No PS/2, I2C, MMCM, physical LCD, or board/timing validation is implied.
// Clock is 51.2 MHz. SCREEN_W/H, STATUS_H, GAME_TIME retain their defaults.
// game_tick and tick_1s are accelerated stimulus pulses, not wall-clock
// measurements of 60 Hz or one second. GAME_TIME remains 60.
// Internal display copies are tested using the actual pixel_x=y=0 condition;
// this condition is a level, and is not the LCD's genuine frame_start.
// No $finish/$stop: leave Vivado's waveform window open for screenshots.
//
// Figure 10-1: 3..28 us, direction events, pending flags, game_tick,
//               player_x/y, state_live (decimal for coordinates/state).
// Figure 10-2(a): 34.98..35.35 us, pointer_down, player/target positions,
//                collision, state_live, score_live, time_left.
// Figure 10-2(b): 49..61 us, direction/pending flags, game_tick,
//                player_x/y, state_live, time_left (four outer boundaries).
// Additional already-tested phases: 69..80 us pause/time hold/resume;
// 134..143 us timeout/restart; 150..160 us local display-copy behavior.
// State codes: 0 READY, 1 RUN, 2 PAUSED, 3 HIT, 4 OVER.

module tb_chapter10_all;
    reg clk = 1'b0;
    always #9.765625 clk = ~clk;
    reg rst_n = 1'b0;
    reg [2:0] ui_state_control = 3'd2;
    reg [2:0] ui_state_frame = 3'd2;
    wire [4:0] enable = dut.enable;
    wire game_enable = enable[0];

    reg event_up = 1'b0;
    reg event_down = 1'b0;
    reg event_left = 1'b0;
    reg event_right = 1'b0;
    reg event_ok = 1'b0;
    reg event_back = 1'b0;
    reg event_pause = 1'b0;
    reg game_tick = 1'b0;
    reg tick_1s = 1'b0;
    reg [10:0] pointer_x = 11'd0;
    reg [9:0] pointer_y = 10'd0;
    reg pointer_down = 1'b0;
    reg [10:0] pixel_x = 11'd128;
    reg [9:0] pixel_y = 10'd128;
    wire pixel_on;
    wire [23:0] pixel_rgb;
    wire [15:0] score;
    wire [3:0] game_state;
    wire exit_request;

    game_system_5slot dut (
        .clk(clk), .rst_n(rst_n),
        .ui_state_control(ui_state_control), .ui_state_frame(ui_state_frame),
        .event_up(event_up), .event_down(event_down),
        .event_left(event_left), .event_right(event_right),
        .event_ok(event_ok), .event_back(event_back),
        .event_pause(event_pause), .game_tick(game_tick), .tick_1s(tick_1s),
        .pointer_x(pointer_x), .pointer_y(pointer_y), .pointer_down(pointer_down),
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .pixel_on(pixel_on), .pixel_rgb(pixel_rgb), .score(score),
        .game_state(game_state), .exit_request(exit_request)
    );

    // Root aliases are read directly from the actual first game slot.
    wire [10:0] player_x = dut.u_game1_treasure.player_x;
    wire [9:0] player_y = dut.u_game1_treasure.player_y;
    wire [10:0] target_x = dut.u_game1_treasure.target_x;
    wire [9:0] target_y = dut.u_game1_treasure.target_y;
    wire [15:0] score_live = dut.u_game1_treasure.score_live;
    wire [6:0] time_left = dut.u_game1_treasure.time_left;
    wire [3:0] state_live = dut.u_game1_treasure.state_live;
    wire collision = dut.u_game1_treasure.collision;
    wire pending_up = dut.u_game1_treasure.pending_up;
    wire pending_down = dut.u_game1_treasure.pending_down;
    wire pending_left = dut.u_game1_treasure.pending_left;
    wire pending_right = dut.u_game1_treasure.pending_right;
    wire [3:0] pending = {pending_up,pending_down,pending_left,pending_right};
    wire [10:0] player_x_frame = dut.u_game1_treasure.player_x_frame;
    wire [9:0] player_y_frame = dut.u_game1_treasure.player_y_frame;
    wire [6:0] time_frame = dut.u_game1_treasure.time_frame;
    wire [3:0] state_frame = dut.u_game1_treasure.state_frame;
    wire [68:0] live_fields = {player_x,player_y,target_x,target_y,
                              score_live,time_left,state_live};
    wire [68:0] display_fields = {
        player_x_frame,player_y_frame,
        dut.u_game1_treasure.target_x_frame,
        dut.u_game1_treasure.target_y_frame,
        dut.u_game1_treasure.score_frame,time_frame,state_frame};

    integer case_id = 0;
    integer errors = 0;
    integer direction_tests = 0;
    integer boundary_tests = 0;
    integer collision_tests = 0;
    integer hit_updates = 0;
    reg checks_done = 1'b0;
    reg checks_pass = 1'b0;
    reg [68:0] expected_display;
    reg [3:0] previous_state;
    reg [15:0] previous_score;
    reg previous_enable;
    reg previous_ok;

    task check;
        input condition;
        input [639:0] message;
        begin
            if (condition !== 1'b1) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("CH10 FAIL at %0.6f us: %0s", $realtime/1000.0, message);
            end
        end
    endtask

    always @(posedge clk) begin
        previous_state = state_live;
        previous_score = score_live;
        previous_enable = game_enable;
        previous_ok = event_ok;
        if (!rst_n)
            expected_display = {11'd500,10'd288,11'd760,10'd320,
                                16'd0,7'd60,4'd0};
        else if (pixel_x == 0 && pixel_y == 0)
            expected_display = live_fields;
        #0.001;
        check(display_fields === expected_display, "local display copy/reset/hold mismatch");
        check(player_x <= 1000 && player_y >= 56 && player_y <= 576,
              "player rectangle escaped the legal 1024x600 play field");
        check(target_x <= 1004 && target_y >= 56 && target_y <= 580,
              "target rectangle escaped the legal play field");
        if (rst_n && previous_enable) begin
            if (previous_state == 3) begin
                check(score_live == previous_score + 16'd1 && state_live == 1,
                      "HIT did not add exactly one point and return to RUN");
                hit_updates = hit_updates + 1;
            end else if (previous_state == 4 && previous_ok)
                check(score_live == 0, "restart failed to clear the live score");
            else check(score_live == previous_score, "score changed outside the HIT/restart states");
        end
    end

    task at_us;
        input integer target_us;
        real delay_ns;
        begin
            delay_ns = target_us * 1000.0 - $realtime;
            if (delay_ns > 0) #(delay_ns);
            @(negedge clk);
        end
    endtask

    // Mask bits: up/down/left/right/OK/Back/pause/game_tick/tick_1s.
    task pulse;
        input [8:0] mask;
        begin
            @(negedge clk);
            {tick_1s,game_tick,event_pause,event_back,event_ok,
             event_right,event_left,event_down,event_up} = mask;
            #0.001;
            if (mask[5]) check(exit_request === game_enable, "incorrect Back exit gating");
            @(negedge clk);
            {tick_1s,game_tick,event_pause,event_back,event_ok,
             event_right,event_left,event_down,event_up} = 9'd0;
            #0.001;
        end
    endtask

    task drag_to;
        input [10:0] x_coord;
        input [9:0] y_coord;
        begin
            @(negedge clk);
            pointer_x = x_coord;
            pointer_y = y_coord;
            pointer_down = 1'b1;
            @(negedge clk);
            #0.001;
        end
    endtask

    task release_drag;
        input [8:0] release_mask;
        begin
            @(negedge clk);
            pointer_down = 1'b0;
            {tick_1s,game_tick,event_pause,event_back,event_ok,
             event_right,event_left,event_down,event_up} = release_mask;
            @(negedge clk);
            {tick_1s,game_tick,event_pause,event_back,event_ok,
             event_right,event_left,event_down,event_up} = 9'd0;
            #0.001;
        end
    endtask

    task fresh_game;
        begin
            @(negedge clk); ui_state_control = 3'd0; pointer_down = 1'b0;
            repeat (3) @(negedge clk);
            check(state_live == 0 && player_x == 500 && player_y == 288
               && target_x == 760 && target_y == 320
               && score_live == 0 && time_left == 60 && pending == 0,
                  "leaving the game page did not restore READY defaults");
            ui_state_control = 3'd2;
            pulse(9'h010);
            check(game_enable && enable == 5'b00001 && state_live == 1,
                  "first-slot selection/start failed");
        end
    endtask

    task snapshot_once;
        begin
            @(negedge clk); pixel_x = 0; pixel_y = 0;
            @(negedge clk); pixel_x = 128; pixel_y = 128;
            #0.001;
        end
    endtask

    integer n;
    reg [10:0] saved_x;
    reg [9:0] saved_y;
    reg [68:0] saved_display;
    initial begin
        at_us(1); rst_n = 1'b1;
        check(state_live == 0 && score_live == 0 && time_left == 60,
              "reset did not produce READY, score 0, time 60");
        at_us(2); pulse(9'h010);
        check(state_live == 1 && game_enable, "OK did not start the selected treasure slot");

        // Figure 10-1: one request persists until its later game tick.
        at_us(4); case_id = 1; pulse(9'h008);
        check(pending_right && player_x == 500, "right event was not buffered");
        at_us(8); pulse(9'h080);
        check(player_x == 508 && player_y == 288 && pending == 0, "right consume/clear failed");
        at_us(9); pulse(9'h080);
        check(player_x == 508, "right request was consumed twice"); direction_tests = direction_tests + 1;

        at_us(10); case_id = 2; pulse(9'h004);
        check(pending_left && player_x == 508, "left event was not buffered");
        at_us(14); pulse(9'h080);
        check(player_x == 500 && pending == 0, "left consume/clear failed");
        at_us(15); pulse(9'h080);
        check(player_x == 500, "left request was consumed twice"); direction_tests = direction_tests + 1;

        at_us(16); case_id = 3; pulse(9'h001);
        check(pending_up && player_y == 288, "up event was not buffered");
        at_us(20); pulse(9'h080);
        check(player_y == 280 && pending == 0, "up consume/clear failed");
        at_us(21); pulse(9'h080);
        check(player_y == 280, "up request was consumed twice"); direction_tests = direction_tests + 1;

        at_us(22); case_id = 4; pulse(9'h002);
        check(pending_down && player_y == 280, "down event was not buffered");
        at_us(26); pulse(9'h080);
        check(player_y == 288 && pending == 0, "down consume/clear failed");
        at_us(27); pulse(9'h080);
        check(player_y == 288, "down request was consumed twice"); direction_tests = direction_tests + 1;

        // Same-cycle event/tick is explicitly supported in the real source.
        at_us(28); case_id = 5; pulse(9'h088);
        check(player_x == 508 && pending == 0, "same-cycle direction/tick was lost");
        at_us(29); pulse(9'h084);
        check(player_x == 500, "same-cycle left/tick failed");
        at_us(30); pulse(9'h08F);
        check(player_x == 492 && player_y == 280, "left/up priority for opposite requests failed");
        at_us(31); pulse(9'h08A);
        check(player_x == 500 && player_y == 288, "diagonal right/down movement failed");

        // Figure 10-2(a): legitimate dragging creates rectangle overlap.
        at_us(35); case_id = 6;
        drag_to(11'd770,10'd330);
        check(player_x == 758 && player_y == 318 && collision, "drag did not reach the treasure");
        repeat (12) @(negedge clk); // continue holding at the old treasure
        release_drag(9'd0);
        repeat (8) @(negedge clk);
        check(score_live == 1 && state_live == 1 && hit_updates == 1,
              "one treasure collision did not produce exactly one HIT/point");
        check(target_x != 760 || target_y != 320, "hit did not refresh the target");
        collision_tests = collision_tests + 1;

        // Merely touching the rectangle edge is not overlap.
        at_us(39); case_id = 7; fresh_game();
        at_us(40); drag_to(11'd748,10'd332); release_drag(9'd0);
        check(player_x == 736 && player_y == 320 && !collision
           && score_live == 0 && state_live == 1, "edge contact incorrectly counted as collision");
        at_us(42); pulse(9'h088);
        repeat (8) @(negedge clk);
        check(score_live == 1 && state_live == 1 && hit_updates == 2,
              "moving past the edge did not produce one new point");
        collision_tests = collision_tests + 1;

        // Reset through the real game-enable path before boundary tests.
        at_us(48); case_id = 8; fresh_game();
        at_us(50); drag_to(11'd0,10'd0);
        check(player_x == 0 && player_y == 56, "top/left pointer clamp failed");
        // A release swipe must not cause an extra move towards the interior.
        release_drag(9'h08A);
        check(player_x == 0 && player_y == 56 && pending == 0,
              "release gesture caused an unwanted extra right/down step");
        at_us(52); pulse(9'h005); // outward left + up
        at_us(54); pulse(9'h080);
        check(player_x == 0 && player_y == 56 && pending == 0,
              "top/left outward request crossed a boundary");
        boundary_tests = boundary_tests + 2;

        at_us(56); case_id = 9; drag_to(11'd2047,10'd1023);
        check(player_x == 1000 && player_y == 576, "bottom/right pointer clamp failed");
        release_drag(9'h085);
        check(player_x == 1000 && player_y == 576 && pending == 0,
              "release gesture caused an unwanted extra left/up step");
        at_us(58); pulse(9'h00A); // outward right + down
        at_us(60); pulse(9'h080);
        check(player_x == 1000 && player_y == 576 && pending == 0,
              "bottom/right outward request crossed a boundary");
        boundary_tests = boundary_tests + 2;

        // Origins not divisible by 8 must saturate, not wrap or overshoot.
        at_us(62); case_id = 10; drag_to(11'd15,10'd71); release_drag(9'd0);
        check(player_x == 3 && player_y == 59, "near-edge drag origin incorrect");
        at_us(63); pulse(9'h085);
        check(player_x == 0 && player_y == 56, "near top/left step did not saturate");
        boundary_tests = boundary_tests + 1;
        at_us(64); drag_to(11'd1009,10'd585); release_drag(9'd0);
        check(player_x == 997 && player_y == 573, "near opposite-edge drag origin incorrect");
        at_us(65); pulse(9'h08A);
        check(player_x == 1000 && player_y == 576, "near bottom/right step did not saturate");
        boundary_tests = boundary_tests + 1;

        at_us(70); case_id = 11; pulse(9'h040);
        saved_x = player_x; saved_y = player_y;
        check(state_live == 2 && time_left == 60, "pause state/time incorrect");
        at_us(71); pulse(9'h188);
        at_us(72); pulse(9'h185);
        check(state_live == 2 && player_x == saved_x && player_y == saved_y
           && time_left == 60 && pending == 0, "paused position/time/events were not held");
        at_us(74); pulse(9'h040);
        check(state_live == 1, "pause event did not resume RUN");
        at_us(76); pulse(9'h100); check(time_left == 59, "first countdown tick failed");
        at_us(78); pulse(9'h100); check(time_left == 58, "second countdown tick failed");
        at_us(80); pulse(9'h100); check(time_left == 57, "third countdown tick failed");

        case_id = 12;
        for (n = 0; n < 57; n = n + 1) begin
            at_us(82 + n); pulse(9'h100);
            check(time_left == 56 - n, "countdown skipped/wrapped a remaining second");
        end
        at_us(140);
        check(time_left == 0 && state_live == 4, "timeout did not enter OVER");
        pulse(9'h188);
        check(time_left == 0 && state_live == 4 && player_x == saved_x && player_y == saved_y,
              "OVER consumed movement or wrapped the countdown");
        at_us(142); case_id = 13; pulse(9'h010);
        check(state_live == 1 && score_live == 0 && time_left == 60
           && player_x == 500 && player_y == 288 && pending == 0,
              "restart did not restore position, score, time and pending flags");

        at_us(145); case_id = 14;
        @(negedge clk); ui_state_control = 0;
        pulse(9'h19F);
        check(state_live == 0 && score_live == 0 && time_left == 60
           && player_x == 500 && player_y == 288 && pending == 0,
              "disabled treasure slot responded to events/timing pulses");
        pulse(9'h020); // no exit request while disabled

        // Actual internal display copies hold whenever pixel coordinates
        // are nonzero. Keeping zero coordinates for several clocks causes
        // several copies; the test deliberately does not call this a frame.
        at_us(150); case_id = 15;
        ui_state_control = 2; pulse(9'h010); pulse(9'h100);
        drag_to(11'd300,10'd320); release_drag(9'd0);
        check(player_x == 288 && player_y == 308 && time_left == 59
           && player_x_frame == 500 && state_frame == 0 && time_frame == 60,
              "nonzero pixel coordinates failed to hold displayed values");
        snapshot_once();
        check(player_x_frame == 288 && player_y_frame == 308
           && time_frame == 59 && game_state == 1 && score == 0,
              "zero-coordinate copy did not capture all live fields");
        saved_display = display_fields;
        at_us(152); drag_to(11'd400,10'd420); release_drag(9'd0); pulse(9'h100);
        check(player_x == 388 && player_y == 408 && time_left == 58
           && display_fields === saved_display, "display changed outside its copy condition");
        at_us(154); snapshot_once();
        check(player_x_frame == 388 && player_y_frame == 408 && time_frame == 58,
              "next zero-coordinate copy missed the latest live fields");

        at_us(156); case_id = 16;
        pixel_x = 390; pixel_y = 410; #0.001;
        check(pixel_on && pixel_rgb == 24'hF4F4F4, "player pixel/color or first-slot output mux incorrect");
        pixel_x = 770; pixel_y = 330; #0.001;
        check(pixel_rgb == 24'hFF5A4F, "treasure pixel/color incorrect");
        pixel_x = 1000; pixel_y = 100; #0.001;
        check(pixel_rgb == 24'h174D35, "background pixel/color incorrect");
        pixel_x = 0; pixel_y = 100; #0.001;
        check(pixel_rgb == 24'h6BCB9A, "border pixel/color incorrect");

        at_us(158); case_id = 17;
        @(negedge clk); pixel_x = 0; pixel_y = 0;
        drag_to(11'd450,10'd420);
        repeat (2) @(negedge clk);
        check(player_x_frame == 438, "held zero-coordinate copy did not track the first update");
        drag_to(11'd460,10'd420);
        repeat (2) @(negedge clk);
        check(player_x_frame == 448, "held zero coordinates were incorrectly treated as one pulse");
        release_drag(9'd0);
        @(negedge clk); pixel_x = 128; pixel_y = 128;

        at_us(165); case_id = 18; pulse(9'h020);
        check(state_live == 1, "Back unexpectedly changed the standalone game state");
        // As in the project, Back is an exit request. The controller owns
        // the subsequent page change, represented here at its input port.
        @(negedge clk); ui_state_control = 0;
        repeat (3) @(negedge clk);
        check(state_live == 0 && !exit_request, "page exit did not reset the treasure slot");

        at_us(190); case_id = 19;
        rst_n = 1'b0;
        #0.001;
        check(state_live == 0 && score_live == 0 && time_left == 60
           && player_x_frame == 500 && player_y_frame == 288 && pending == 0,
              "asynchronous reset did not restore live and displayed defaults");
        at_us(191); rst_n = 1'b1;
        at_us(195);
        check(direction_tests == 4 && boundary_tests == 6 && collision_tests == 2,
              "a required direction, boundary or collision test was skipped");
        checks_done = 1'b1;
        checks_pass = (errors == 0);
        if (checks_pass)
            $display("CH10 PASS: directions=%0d boundaries=%0d collisions=%0d errors=%0d",
                     direction_tests,boundary_tests,collision_tests,errors);
        else $display("CH10 FAIL: errors=%0d", errors);
    end
endmodule
