`default_nettype none

module tt_um_vga_battleship (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    assign uo_out = 8'h00;
    assign uio_oe  = 8'h00;
    wire _unused = &{ena, ui_in[7:4], uio_in, 1'b0};

    // ---------------- VGA timing 640x480@60 ----------------
    localparam H_DISP=640, H_FRONT=16, H_SYNC=96, H_BACK=48;
    localparam H_TOTAL = H_DISP+H_FRONT+H_SYNC+H_BACK;
    localparam V_DISP=480, V_FRONT=10, V_SYNC=2, V_BACK=33;
    localparam V_TOTAL = V_DISP+V_FRONT+V_SYNC+V_BACK;

    reg [9:0] hpos, vpos;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin hpos<=0; vpos<=0; end
        else if (hpos==H_TOTAL-1) begin
            hpos<=0; vpos <= (vpos==V_TOTAL-1) ? 0 : vpos+1;
        end else hpos<=hpos+1;
    end

    wire hsync = ~((hpos>=H_DISP+H_FRONT)&&(hpos<H_DISP+H_FRONT+H_SYNC));
    wire vsync = ~((vpos>=V_DISP+V_FRONT)&&(vpos<V_DISP+V_FRONT+V_SYNC));
    wire disp  = (hpos<H_DISP)&&(vpos<V_DISP);
    wire frame = (hpos==0)&&(vpos==0);

    // ---------------- Params ----------------
    // -> Increased BUL_SPD from 8 to 16 so it reaches the target much faster!
    localparam SHIP_X=24, SHIP_W=20, SHIP_H=18, SHIP_SPD=4;
    localparam BUL_W=6, BUL_H=3, BUL_SPD=16; 
    localparam OBS_W=14, GAP_H=150, OBS_SPD=2;
    localparam ENEMY_X=590, ENEMY_W=18, ENEMY_H=14, ENEMY_SPD=2;

    // ---------------- State ----------------
    reg [9:0] ship_y;
    reg       bullet_on;
    reg [9:0] bul_x, bul_y;
    reg [9:0] obs1_x, gap1_y, obs2_x, gap2_y;
    reg [9:0] enemy1_y, enemy2_y;
    reg       e1_dir, e2_dir;
    reg [4:0] score;
    reg [7:0] lfsr;
    reg [4:0] flash;
    reg       fire_prev, restart_prev;
    reg [9:0] star_scroll;
    reg       flame;

    wire restart_edge = ui_in[3] & ~restart_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ship_y<=230; bullet_on<=0; bul_x<=0; bul_y<=0;
            obs1_x<=640; gap1_y<=80;  obs2_x<=800; gap2_y<=250;
            enemy1_y<=120; enemy2_y<=300; e1_dir<=0; e2_dir<=0;
            score<=0; lfsr<=8'hA5; flash<=0;
            fire_prev<=0; restart_prev<=0; star_scroll<=0; flame<=0;
        end else begin
            restart_prev <= ui_in[3];

            if (restart_edge) begin
                ship_y<=230; bullet_on<=0; bul_x<=0; bul_y<=0;
                obs1_x<=640; gap1_y<=80;  obs2_x<=800; gap2_y<=250;
                enemy1_y<=120; enemy2_y<=300; e1_dir<=0; e2_dir<=0;
                score<=0; flash<=10;
            end else if (frame) begin
                lfsr <= {lfsr[6:0], lfsr[7]^lfsr[5]^lfsr[4]^lfsr[3]};
                star_scroll <= star_scroll + 1;
                flame <= ~flame;

                // movement
                if (ui_in[0] && ship_y>SHIP_SPD) ship_y <= ship_y-SHIP_SPD;
                else if (ui_in[1] && ship_y<(V_DISP-SHIP_H-SHIP_SPD)) ship_y <= ship_y+SHIP_SPD;

                // fire
                if (ui_in[2] && !fire_prev && !bullet_on) begin
                    bullet_on<=1; bul_x<=SHIP_X+SHIP_W; bul_y<=ship_y+SHIP_H/2-BUL_H/2;
                end else if (bullet_on) begin
                    if (bul_x+BUL_W>=H_DISP) bullet_on<=0; else bul_x<=bul_x+BUL_SPD;
                end
                fire_prev <= ui_in[2]; 

                // obstacles scroll
                if (obs1_x<=OBS_SPD) begin obs1_x<=H_DISP+60;  gap1_y<={2'b0,lfsr}+20; end
                else obs1_x<=obs1_x-OBS_SPD;
                if (obs2_x<=OBS_SPD) begin obs2_x<=H_DISP+280; gap2_y<={2'b0,lfsr^8'hFF}+20; end
                else obs2_x<=obs2_x-OBS_SPD;

                // Enemy vertical movement
                if (!e1_dir) begin 
                    if (enemy1_y+ENEMY_H+ENEMY_SPD>=240) e1_dir<=1; else enemy1_y<=enemy1_y+ENEMY_SPD;
                end else begin     
                    if (enemy1_y<=ENEMY_SPD+80) e1_dir<=0; else enemy1_y<=enemy1_y-ENEMY_SPD;
                end
                
                if (!e2_dir) begin 
                    if (enemy2_y+ENEMY_H+ENEMY_SPD>=400) e2_dir<=1; else enemy2_y<=enemy2_y+ENEMY_SPD;
                end else begin     
                    if (enemy2_y<=ENEMY_SPD+240) e2_dir<=0; else enemy2_y<=enemy2_y-ENEMY_SPD;
                end

                // -> Bullet vs obstacles collision REMOVED so bullets shoot straight through to targets!

                // bullet vs enemies
                if (bullet_on && (bul_x+BUL_W>ENEMY_X) && (bul_x<ENEMY_X+ENEMY_W) &&
                    (bul_y+BUL_H>enemy1_y) && (bul_y<enemy1_y+ENEMY_H)) begin
                    bullet_on<=0; score<=score+1; enemy1_y<={2'b0,lfsr[6:0]}+80;
                end
                if (bullet_on && (bul_x+BUL_W>ENEMY_X) && (bul_x<ENEMY_X+ENEMY_W) &&
                    (bul_y+BUL_H>enemy2_y) && (bul_y<enemy2_y+ENEMY_H)) begin
                    bullet_on<=0; score<=score+1; enemy2_y<={2'b0,lfsr[6:0]}+240;
                end

                // ship vs any obstacle -> reset position + flash
                if (((obs1_x<SHIP_X+SHIP_W)&&(obs1_x+OBS_W>SHIP_X)&&!((ship_y+SHIP_H>gap1_y)&&(ship_y<gap1_y+GAP_H))) ||
                    ((obs2_x<SHIP_X+SHIP_W)&&(obs2_x+OBS_W>SHIP_X)&&!((ship_y+SHIP_H>gap2_y)&&(ship_y<gap2_y+GAP_H)))) begin
                    ship_y<=230; flash<=20;
                end else if (flash!=0) flash<=flash-1;
            end
        end
    end

    // ---------------- Starfield ----------------
    wire [9:0] fx = hpos + star_scroll;
    wire star = (fx[4:0]==5'h1F) && (vpos[4:0]=={1'b0,fx[8:5]});

    // ---------------- Ship ----------------
    wire [9:0] sx = hpos - SHIP_X;
    wire [9:0] sy = vpos - ship_y;
    wire in_ship_box = disp && (hpos>=SHIP_X)&&(hpos<SHIP_X+SHIP_W+3)&&(vpos>=ship_y)&&(vpos<ship_y+SHIP_H);
    wire flame_px  = in_ship_box && sx<3 && sy>=6 && sy<12;
    wire hull_px   = in_ship_box && sx>=3 && sx<16 && sy>=2 && sy<16;
    wire cockpit_px= in_ship_box && sx>=10 && sx<15 && sy>=6 && sy<12;
    wire nose_px   = in_ship_box && sx>=16 && sx<20 && sy>=7 && sy<11;
    wire ship_hit  = flame_px | hull_px | nose_px;

    // ---------------- Bullet ----------------
    wire in_bullet = disp && bullet_on && (hpos>=bul_x)&&(hpos<bul_x+BUL_W)&&(vpos>=bul_y)&&(vpos<bul_y+BUL_H);

    // ---------------- Obstacles: plain solid blocks ----------------
    wire body1 = disp && (hpos>=obs1_x)&&(hpos<obs1_x+OBS_W) && !((vpos>=gap1_y)&&(vpos<gap1_y+GAP_H));
    wire body2 = disp && (hpos>=obs2_x)&&(hpos<obs2_x+OBS_W) && !((vpos>=gap2_y)&&(vpos<gap2_y+GAP_H));
    wire body_any = body1 | body2;

    // ---------------- Enemies (same saucer shape, two positions) ----------------
    wire [9:0] e1x = hpos-ENEMY_X, e1y = vpos-enemy1_y;
    wire [9:0] e2x = hpos-ENEMY_X, e2y = vpos-enemy2_y;
    wire in_e1 = disp && (hpos>=ENEMY_X)&&(hpos<ENEMY_X+ENEMY_W)&&(vpos>=enemy1_y)&&(vpos<enemy1_y+ENEMY_H);
    wire in_e2 = disp && (hpos>=ENEMY_X)&&(hpos<ENEMY_X+ENEMY_W)&&(vpos>=enemy2_y)&&(vpos<enemy2_y+ENEMY_H);
    wire dome_px = (in_e1 && e1x>=6 && e1x<12 && e1y<4) || (in_e2 && e2x>=6 && e2x<12 && e2y<4);
    wire body_px = (in_e1 && e1x>=1 && e1x<17 && e1y>=4 && e1y<9) || (in_e2 && e2x>=1 && e2x<17 && e2y>=4 && e2y<9);
    wire rim_px  = (in_e1 && e1x>=3 && e1x<15 && e1y>=9 && e1y<11) || (in_e2 && e2x>=3 && e2x<15 && e2y>=9 && e2y<11);

    // ---------------- Score / flash ----------------
    // -> Score is now rendered as distinct sticks/tally marks! (3 pixels wide, 5 pixels gap)
    wire [9:0] sx_score = hpos - 10;
    wire in_score = disp && (vpos>=5)&&(vpos<15)&&(hpos>=10)&&(hpos<10+{score,3'b000}) && (sx_score[2:0] < 3);
    
    wire in_flash = (flash!=0) && ((hpos<4)||(hpos>=H_DISP-4)||(vpos<4)||(vpos>=V_DISP-4));

    // ---------------- Pixel mux ----------------
    reg [1:0] R,G,B;
    always @(*) begin
        if (!disp)                 begin R=0; G=0; B=0; end
        else if (in_flash)         begin R=3; G=0; B=0; end
        else if (in_bullet)        begin R=3; G=3; B=0; end
        else if (rim_px)           begin R = flame?3:2; G = flame?3:0; B=0; end
        else if (dome_px)          begin R=0; G=3; B=3; end
        else if (body_px)          begin R=3; G=0; B=1; end
        else if (flame_px)         begin R=3; G = flame?2:1; B=0; end
        else if (cockpit_px)       begin R=0; G=3; B=3; end
        else if (ship_hit)         begin R=3; G=3; B=3; end
        else if (body_any)         begin R=2; G=1; B=1; end
        else if (in_score)         begin R=3; G=3; B=3; end
        else if (star)             begin R=3; G=3; B=3; end
        else                       begin R=0; G=0; B=1; end
    end

    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

endmodule