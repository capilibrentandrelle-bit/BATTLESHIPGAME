# TT VGA Space Shooter

A retro, arcade-style space shooter written in Verilog for the Tiny Tapeout hardware platform. Rendered entirely in hardware logic for a 640x480 @ 60Hz VGA display, players must navigate a continuous obstacle course while shooting down patrolling enemy saucers.

## Controls

If you are playing via the Wokwi simulator, ensure your virtual pushbuttons are mapped to these keyboard keys:

| Action | Physical Key | Hardware Pin |
| :--- | :--- | :--- |
| **Move Up** | `0` | `ui_in[0]` |
| **Move Down** | `1` | `ui_in[1]` |
| **Fire Laser** | `2` | `ui_in[2]` |
| **Restart Game** | `3` | `ui_in[3]` |

---

## Game Mechanics

### The Player
You control a spaceship on the left side of the screen. The ship can move up and down to navigate through gaps in the incoming defenses. The ship features an animated thruster flame that flickers based on the system frame counter.

### The Environment & Obstacles
* **Starfield:** A hardware-generated, infinitely scrolling starfield moves from right to left in the background.
* **Scrolling Walls:** Two columns of solid walls continuously scroll toward the player. Each wall has a randomly generated safe gap (using a Linear-Feedback Shift Register, or LFSR, for pseudo-randomness).
* **Collisions:** If your ship crashes into a wall, the screen will flash red, and your ship will be reset to its starting vertical position.

### Combat & Enemies
* **Patrolling Saucers:** Two enemy saucers patrol the right side of the screen. One saucer bounces up and down in the upper-middle zone, while the other patrols the lower-middle zone.
* **Piercing Lasers:** Pressing fire shoots a high-speed yellow laser. Lasers pass straight through the scrolling walls, allowing you to time your shots to hit the saucers behind enemy lines.
* **Respawning:** When a saucer is hit, the laser disappears, and the saucer instantly respawns at a newly randomized vertical position within its patrol zone. 

### Scoring System
* **Tally Marks:** Traditional digital numbers are not used. Instead, every successful hit on an enemy saucer adds a physical "stick" or tally mark to the top left of the screen.
* **Tracking:** The score tracks continuously. Pressing the Restart key (`1`) will wipe the screen, reset your score to zero, and return your ship to the center.

---

## Technical Specifications
* **Video Output:** 640x480 @ 60Hz VGA
* **Color Depth:** 6-bit RGB (2 bits per color channel)
* **Logic:** 100% Verilog (No CPU, no frame buffer)
