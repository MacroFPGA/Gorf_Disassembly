<!--
====================================================================
Title: VGER: A Guide to DNA's Real-Time Arcade Engine
Author: David E. Turner
Version: 1.0
Date: August 2026
Copyright: © 2026 David E. Turner
License: Creative Commons Attribution 4.0 International (CC BY 4.0)

You are free to share, copy, modify, and redistribute this document
in any medium or format for any purpose, provided that appropriate
credit is given to the original author.
====================================================================
-->


# VGER: A Guide to DNA's Real-Time Arcade Engine

## The Vector and Playaction Management Engine
### A Guide for Systems Programmers and Z80 Assembly Developers
#### Covering Extra Bases, Space Zap, Wizard of Wor, Gorf, and Robby Roto

---

## Preface

The Bally/Midway **Vector and Playaction Management Engine (VGER)** is a specialized real-time software framework built around the Z80 microprocessor. It separates high-level game logic from recurring background work such as task updates, physics, collision processing, graphics, sound, and speech.

The manual is organized to teach that architecture before presenting its lowest-level implementation. The main chapters therefore move from the problem VGER solves, to the structures and processing mechanisms it uses, and finally to the addresses, registers, hardware interfaces, and Z80 routines that implement those mechanisms.

The technical material is retained at reference-manual depth. Tables, memory maps, constants, assembly listings, disassemblies, and game-specific examples remain part of the document rather than being removed for readability.


### How to Read This Manual

The main narrative answers **what the subsystem is doing and why it exists**. Tables and diagrams define the structures involved. Assembly listings then show the implementation.

When a section becomes highly detailed, treat the surrounding prose as the teaching layer and the following tables or listings as the reference layer. You do not need to memorize an address or register before understanding the role it plays.


---

## Table of Contents & Chapter Guide

The chapters follow a progression from architecture to implementation. Each chapter begins with the purpose of the subsystem, then moves into its data structures and processing flow before presenting detailed implementation material.


*   **Chapter I: VGER Architecture: System Primer & Core Philosophy**
    *   The monolithic game loop and its bottleneck; VGER's decoupled foreground/background multitasking stage-crew model; object-oriented assembly task structures; and the background processing pass.
*   **Chapter II: RAM Architecture & The 51-Byte Task Header**
    *   16 KB DRAM board boundaries and video framebuffer overlap math ($4000–$7FFF hex); upper protected Static NVRAM ($D000–$FFFF hex) with security lock port `$5B` handshakes; the O(1) dynamic memory allocator (FREELIST); and IY-driven activation frames (`_FRAME`/`_UNFRAME`).
*   **Chapter III: The Multitasking Queue & Scanline Scheduler**
    *   Topology of the circular active queue and `vqhead` sentinel initialization (`NILVQ`); queue manipulation primitives (`ADDQ`/`nextq`); dynamic performance scaling (`INCTB`); and the raster-synchronized scanline interrupts (Lines 50, 100, 200) with beam-sync avoidance checks.
*   **Chapter IV: The Physics & Trajectory Engine (VMR)**
    *   Vector Management Routine (VMR) dispatcher; linear movement calculations with boundary limit checks (`VECTLC`); parabolic gravity modeling (`VECTDD`); real-time joystick joystick-driven inertia scaling (`JOYUPD`); and polar-to-cartesian coordinate mathematics using a 64-byte `sin-table` and `SINE`/`COSINE` lookups.
*   **Chapter V: The Custom Blitter & Video Hardware Interface (SUR)**
    *   The Screen Update Routine (SUR) blitting pipeline (`vwrite`/`verase`); LSI Pattern Board blitter port maps ($78–$7E hex); horizontal line-skip calculations (Xmod); CRT electronic line-blanking (`VERBL` Port `$0A`); and cocktail cabinet display mirroring (`cockrel`/`cockff`).
*   **Chapter VI: Collision Detection & Intercept Testing**
    *   Axis-Aligned Bounding Box (AABB) software broadphase (`CHECKVEC`/`CHECKALL`) with identity bitmasking; hardware-level pixel-perfect intercept latches (INTST Port `$08`); and interrupt-safe callback dispatchers (`VIWRITE`/`XIWRITE`) with indirect execution jumps.
*   **Chapter VII: Virtual Machines & The Animation Script Interpreter**
    *   The four execution layers of the platform (Z80 assembly, TERSE VM, VGER runtime verbs, and `ainter` script VM); the virtual program counter (VPC) and return stack variables; the `_ainet_loop` re-entry stack trick; and compiled animation script disassemblies (`EXPISUB`/`FLIPOVER`).
*   **Chapter VIII: Co-Processing Audio, Music, & Speech (MUSCPU)**
    *   Dual custom Astrocade "IO" sound chip maps ($10–$17 and $50–$57 hex); background co-processing trackers (`MUSCPU`/`process`); score parsing; dynamic left-right logarithmic volume panning; and asynchronous speech phoneme streaming (Votrax SC-01 PHONE interrupt).
*   **Chapter IX: Arcade Case Studies (Extra Bases, Gorf, & Wizard of Wor)**
    *   Cabinet hardware and memory configurations; volatile DRAM falls-back on minimalist hardware; double-derivative baseball trajectories; token-threaded code compression; battery-backed CMOS NVRAM writes; and repurposing the Linked Vector Pointer for active radar tracking.
*   **Appendix A: 51-Byte Task Header Quick Reference Table**
*   **Appendix B: Bare-Metal Hardware I/O Port Assignments**

---

# Chapter I: VGER Architecture: System Primer & Core Philosophy

VGER is easiest to understand by starting with the programming problem it addresses. Early arcade software commonly depended on a single loop that handled input, game state, collision tests, graphics, and frame timing. As the number of active objects increased, that arrangement placed more work into the same fixed frame window.

This chapter establishes the core VGER model before introducing implementation details: foreground game logic, background task processing, self-contained Tasks, the active collection, and the recurring processing pass.

---

## 1. What Problem Does the Monolithic Game Loop Create?

Early arcade games of the late 1970s operated under severe hardware constraints. Microprocessors ran at speeds that were a tiny fraction of modern chips, and physical memory was exceptionally scarce and expensive.

In those early days of video games, screen visual elements were simple. A game might feature two paddles and a bouncing ball, or a single player ship dodging a handful of static obstacles. Because the number of moving objects was tiny, programmers could manually track every coordinate, update every velocity, and erase and redraw every pixel in a straightforward, line-by-line program.

This linear structure is referred to as a **Monolithic Game Loop**:

```text
+-----------------------------------------------------+
|              Monolithic Game Loop                   |
|  1. Read Player Input (Joysticks, Buttons)          |
|  2. Update Game State (Move Ships, Calculate Physics)|
|  3. Run Collision Checks (Test Object Intersect)    |
|  4. Draw Graphics (Erase & Redraw Sprite Pixels)    |
|  5. Wait for Frame Sync (Repeat from Step 1)        |
+-----------------------------------------------------+
```

While this linear structure is easy to write, it scales poorly. An arcade monitor updates its visual display 60 times every second, giving the microprocessor a strict time window of roughly **16.6 milliseconds (decimal)** to execute all steps on the checklist.

If the game program finishes its checklist in 10 milliseconds, the game runs smoothly. But if a wave of alien ships spawns and the checklist suddenly takes 20 milliseconds to finish, the program misses the monitor's display deadline. This creates "CPU lag," where the game slows down to half-speed like running in slow motion. Worse, writing to visual memory while the video hardware is scanning it can cause memory bus collisions that glitch the graphics display.

---

## 2. How Does VGER Separate Game Logic from Repetitive Work?

VGER completely sweeps the single, linear game loop away. Instead of forcing a single program loop to perform every task sequentially, VGER splits the arcade cabinet's execution into two distinct layers:

1.  **The Foreground Program (The Director):** Focuses entirely on high-level game rules, storytelling, scoring, menus, and state machine transitions.
2.  **The Background Engine (The Stage Crew):** Operates continuously behind the scenes, automating position updates, collision testing, and screen drawing 60 times per second.

### The Stage Crew Analogy
Think of the foreground program as a theater director. The director doesn't personally run onto the stage during a play to move actors across the floor, physically flash lighting, or sweep the stage. The director simply tells an actor when to enter the stage and where to go.

VGER acts as the **stage crew**. When the foreground game program wants an alien ship to dive across the screen, it doesn't calculate the trajectory or draw the pixels. It simply tells VGER, *"Spawn an alien missile at these coordinates and give it this trajectory."*

From that moment on, VGER's background engine takes complete ownership of the missile. Every 1/60th of a second, VGER automatically calculates the missile's new position, erases its old sprite from the screen memory, redraws it at its new location, checks if it hit a target, and cleans it up when it leaves the display. The foreground program is freed from tedious housekeeping, allowing developers to write clean, high-level game playaction.

---

## 3. How Does VGER Represent an Active Game Object?

To make this background automation possible, VGER changes how programmers think about game data. In simple assembly programs, a developer might maintain a collection of separate variable arrays: one list of $X$ positions, one list of $Y$ positions, and another list of animation timers. Tracking which array index belonged to which alien or projectile quickly became a tangled mess.

VGER adopts an **object-oriented approach** directly at the processor level. Instead of scattered variables, VGER treats every active visual element on the screen as an autonomous, self-contained entity. Whether an entity is a player's ship, a diving enemy, a flying baseball, or an explosion, VGER treats it as an independent **object**.

Each object bundles two fundamental things together:
*   **Properties (State):** The information describing the object right now (e.g., current location, speed, acceleration, visual appearance, remaining lifetime).
*   **Behaviors (Methods):** The instruction routines that define how this specific object moves, updates its visual animation, and reacts when it collides with something else.

In VGER technical terminology, an active game object is called a **Task** (or **Vector Object**). When the game creates a new entity, VGER allocates a dedicated block of workspace memory to hold that Task. This block acts as the Task's personal ledger.

### Standardized Task Blueprint
To process many Tasks smoothly, VGER maintains a master **Active Collection** (referred to in technical manual terms as the **Active Queue**). Instead of using a static array with a fixed limit, VGER links active Tasks together in a **circular linked collection**. Each Task contains internal pointers pointing directly to the neighbor ahead of it and the neighbor behind it.

This circular design provides three major advantages:
*   **Dynamic Capacity:** Tasks can be added or removed dynamically at any time without shuffling other memory around.
*   **Infinite Loop Traversal:** The background engine can start at any point in the ring, step sequentially from object to object, and eventually wrap cleanly back to where it started without ever hitting a "dead end".
*   **Instant Removal:** When a Task dies or flies off-screen, VGER simply connects its two neighboring Tasks directly to each other, instantly unlinking the dead Task from the processing loop in a single step.

---

## 4. What Happens During a Background Processing Pass?

Every 1/60th of a second, the display hardware triggers a precise interrupt signal. This signal temporarily pauses the foreground program and hands control to VGER's background engine.

VGER then marches through the active collection, performing an automated **Five-Step Processing Pass** for every active Task:

1.  **Fetch:** VGER selects the next active Task in the ring and reads its behavioral routine address.
2.  **Move:** VGER executes the Task's movement behavior, integrating its velocity and acceleration vectors to calculate its new position.
3.  **Test:** The engine checks if the updated coordinates cross screen boundaries or collide with other active Tasks.
4.  **Render:** VGER commands the visual hardware to automatically erase the sprite's previous graphic frame and draw the new frame at its freshly calculated coordinates.
5.  **Advance:** The engine follows the forward link to the next Task in line and repeats the cycle.

Once every active Task in the ring has been processed, the background pass completes, and VGER returns control right back to the foreground game logic.

---

## 5. Architectural Checkpoint

Before moving into memory and hardware details, the reader should have four ideas in place:


VGER represents a major leap forward in early arcade systems engineering:
*   **VGER exists to automate repetitive labor:** It relieves the main game program from manually calculating physics, tracking objects, and managing graphics rendering.
*   **Decoupled Architecture:** High-level game rules run in the foreground, while time-critical object processing runs in the 60Hz background.
*   **Entities are Tasks:** Screen actors are represented by self-contained Tasks that bundle position, motion, graphics, and behavior together.
*   **Tasks live in an active collection:** VGER manages objects in a circular linked collection that allows seamless creation, traversal, and destruction.

In the subsequent chapters, we will open up VGER's mechanical systems: examining its strict RAM segmentation, interrupt synchronization, Fixed-Point Cartesian and Polar physics engine, hardware-accelerated Pattern Board blitting, AABB software broadphase, and pixel-perfect LSI hardware collision checking.

---

# Chapter II: RAM Architecture & The 51-Byte Task Header

Chapter I established what a Task represents. This chapter shows where that Task lives, how its memory is divided, and how VGER manages the fixed-size blocks used for active objects.

The order is deliberate: first the system memory map, then the Task structure, then allocation and deallocation, followed by stack frames and protected-memory writes. The exact addresses and offsets are presented as reference material after the role of each region has been established.

## 1. Where Does VGER Put Its Data?

The Z80 provides a single 64 KB (65,536 decimal bytes) address space. VGER divides that address space into functional regions so that video memory, task data, stacks, and other runtime state can coexist.

The system's main RAM is provided by a single Dynamic RAM (DRAM) Board containing 16 KB (16,384 decimal bytes) of workspace mapped from **`$4000` to `$7FFF`** in hex. This 16 KB segment is partitioned into several distinct functional areas to maximize memory efficiency:

```text
+------------------+  $4000 (hex) / 16384 (decimal)
|                  |
|  Viewable VRAM   |  (320 x 204 Bitmapped Screen Buffer)
|                  |
+------------------+  $7C00 (hex) / 31744 (decimal)  -- Start of Overlap
|   VGER Off-Screen|  (Temporary variables, buffers,
|     Work Area    |   and interrupt vectors)
+------------------+  $7F00 (hex) / 32512 (decimal)
|   TERSE VM       |  (Parameter Stack / Return Stack)
|   Stacks         |
+------------------+  $7FFF (hex) / 32767 (decimal)  -- End of DRAM Board
```

*   **Viewable Video RAM (`$4000 – $7FBF` hex / 16,384 – 32,703 decimal):** The bulk of the memory board is dedicated to a dense 320×204 bitmapped frame buffer. Every pixel written to this area is immediately scanned by the video hardware and output to the cathode-ray tube (CRT) monitor.
*   **Off-Screen Work Area (`$7C00 – $7EFF` hex / 31,744 – 32,511 decimal):** This region spans exactly **768 decimal bytes**. On minimalist hardware systems like *Extra Bases*, this is recycled as a temporary operational workspace.
*   **TERSE Virtual Machine Stacks (`$7F00 – $7FFF` hex / 32,512 – 32,767 decimal):** This region spans exactly **256 decimal bytes** and contains the execution stacks for the compiled TERSE virtual machine—specifically the **Parameter Stack Pointer (PSP)** and the **Return Stack Pointer (RSP)**.

---

### Hardware Insight: Frame Buffer Overlap & Line Masking

An elegant but challenging aspect of VGER’s design is the **mathematical overlap** between the Viewable VRAM boundary and the runtime workspaces located at the top of the DRAM board.

At a resolution of 320×204 pixels with a depth of 2 bits per pixel (4 pixels packed per byte), each horizontal scanline requires exactly **80 (decimal) bytes**. A complete frame of 204 scanlines therefore consumes exactly **16,320 (decimal) bytes** (equal to `$3FC0` bytes in hex). Mapped from the base of RAM at `$4000` (hex), the viewable display buffer extends up to **`$7FBF` (hex)** (decimal address 32,703).

This means that out of the 16,384 decimal bytes on the DRAM board, the framebuffer consumes **99.61%** of the available RAM, leaving exactly **64 (decimal) non-overlapping bytes** (`$7FC0` to `$7FFF` hex) at the very top.

Because the system requires more than 64 decimal bytes of workspace for variables, queues, and stacks, the system designers deliberately mapped VGER's off-screen workspace and the TERSE stacks to overlap the upper region of the video framebuffer:

```text
Display scanline math:
320 pixels * 204 scanlines * 2 bits/pixel = 130,560 bits
130,560 bits / 8 bits/byte = 16,320 decimal bytes ($3FC0 hex)
Base Address $4000 (hex) + 16,320 bytes = $7FC0 (hex) (Theoretical End of VRAM)

Overlapping Workspace Range:
$7C00 to $7FBF (hex) = 960 decimal bytes (overlapping viewable video memory)
960 bytes / 80 bytes per scanline = exactly 12 (decimal) bottom scanlines

DRAM Workspace Partitioning in Overlap:
- Off-Screen Work Area ($7C00–$7EFF) = 768 decimal bytes (exactly 9.6 scanlines)
- TERSE VM Stacks ($7F00–$7FFF) = 256 decimal bytes (256 - 64 = 192 overlapping bytes, exactly 2.4 scanlines)
```

Because variables, active queue pointers, and stacks in these regions change rapidly frame-by-frame, writing data directly to these overlapping DRAM addresses causes pseudo-random bit patterns to render at the bottom of the screen. These appear as flashing **\"garbage pixels\"** during active gameplay.

Cabinet builders dealt with this overlap using two methods:
1.  **Physical Masking:** On standard commercial cabinets, the CRT monitor's black cardboard bezel physically masked out the bottom 12 (decimal) lines.
2.  **Electronic Line Blanking:** VGER uses the hardware-blanking register `VERBL` mapped to output port **`$0A` (hex)**. Writing the value **`$CC` (hex)** (204 in decimal) to port `$0A` (hex) tells the video hardware to blank the electron beam immediately at scanline 204, electronically masking the garbage pixels from the player’s view.

---

### Write-Protected Non-Volatile RAM (WPRAM): Architectural Fallback Subsystem

On full-featured VGER systems like *Gorf* and *Wizard of Wor*, the platform does not attempt to pack persistent variables, high scores, and active task queues into the volatile DRAM workspace. Instead, those machines leverage a dedicated expansion board containing battery-backed CMOS Write-Protected Static RAM (WPRAM) starting at address **`$D000` (hex)** (or `$E000` depending on system constants).

This upper memory page hosts persistent variables, diagnostic logs, high score arrays (`HISCR2` and `HISCR4`), and VGER's master queue anchor (`vqhead` at `$D08C` hex). The behavior of this memory block is highly hardware-dependent:

*   **The Hardware-Locked Implementation (Audit-Capable Systems):** On games like *Gorf* and *Wizard of Wor*, a physical memory expansion board containing battery-backed CMOS static RAM is plugged into the cardcage. On these systems, the hardware bus monitors write attempts to the `$D000–$FFFF` address block. To guard these critical audit registers from processor runaways, write attempts are electronically ignored by default. To unlock the WPRAM, VGER must write the key byte **`$A5` (hex)** to the hardware-protect port **`$5B` (hex)** immediately prior to executing any write command.
*   **The Volatile Software Fallback (Extra Bases):** *Extra Bases* is designed with a more cost-effective, minimalist cardcage configuration containing only the CPU board, the Game Logic/IO Board, and the Dynamic RAM Board. Because there is no physical CMOS static RAM board installed in the cardcage, no physical hardware exists to intercept writes or protect the memory at `$D000` (hex).

    Crucially, **the compiled VGER kernel does not change**. The software still executes the `$A5` (hex) key handshake to port `$5B` (hex) and calls `wp!` or `wpb!` to write game data. But on the *Extra Bases* bus, this handshake operates in a \"null\" hardware environment: the unlock signal is ignored, and the write operations transparently execute as normal volatile RAM writes. As a result, all credits, high scores, and game settings are completely cleared when power is cycled.

#### Write-Protected Memory Comparison by Game
| Game Title | Year | Protected Memory Range | Size (Bytes) | Hardware & Architectural Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Extra Bases** | 1980 | *None* | 0 (decimal) bytes | No physical CMOS NVRAM; handshake is a no-op in software. |
| **Space Zap** | 1980 | `$D000 – $D03F` (hex) | 64 (decimal) bytes | Standard 64-byte NVRAM allocation. |
| **Wizard of Wor** | 1980 | `$D000 – $D03F` (hex) | 64 (decimal) bytes | Standard 64-byte NVRAM allocation. |
| **Gorf** | 1981 | `$D000 – $D07F` (hex) | 128 (decimal) bytes | Extended 128-byte block for expanded audio & speech logging. |
| **The Adventures of Robby Roto!** | 1981 | `$E000 – $E1FF` (hex) | 512 (decimal) bytes | Expanded 512-byte block for tracking game states and grid structures. |

---

## 2. Anatomy of the 64-Byte Node & The Task Header Block

To achieve multitasking on a Z80 processor with just a few kilobytes of available work RAM, VGER avoids a traditional heap. Instead, it utilizes a highly optimized **fixed-size block allocation system**.

Every active entity on the screen—such as a player, an outfielder, a flying baseball, or a custom hit marker—is managed as a **Vector Object** (or **Task**). When an object is spawned, it is allocated a single **64 (decimal) byte memory slot** (NODESIZE = 64) from a pre-allocated pool.

Within this 64 (decimal) byte envelope, the first **51 (decimal) bytes (offsets `$00 – $32` hex)** are occupied by the standard VGER **Task Header Block**. The remaining **13 (decimal) bytes (offsets `$33 – $3F` hex)** are reserved as local scratchpad memory and a private Return Stack (`VASTKS`) for that specific task's loops and subroutines.

*Note on Dimensionality:* Although some early development notes refer to this Task Header as a 50-byte structure (confusing the maximum offset index of `$32` hex with the total count), because the offsets are zero-indexed from `$00` to `$32` hex, it contains exactly **51 (decimal) bytes** of state data.

The 51 (decimal) byte Task Header Block is laid out across six functional register sets:

### I. Queue & Multitasking Links
| Offset (Dec) | Offset (Hex) | Variable Name | Type | Description / VM Semantics |
| :--- | :--- | :--- | :--- | :--- |
| **0** | `$00` | `PQS` | Byte | **Task Status Bitmask:** Tracks states such as active (`TBACT`), asleep (`TBSLEEP`), bypass drawing (`PQSDW`), or bypass erasing (`PQSDE`) on the current frame. |
| **1–2** | `$01–$02` | `PQFL/PQFH` | Word | **Forward Queue Link:** 16-bit RAM address pointing to the next active task in the linked list. |
| **3–4** | `$03–$04` | `PQBL/PQBH` | Word | **Backward Queue Link:** 16-bit RAM address pointing to the previous task in the linked list. |
| **5–6** | `$05–$06` | `PQRL/PQRH` | Word | **Task Routine Address:** Pointer to the compiled Z80 machine code subroutine managing this task's logic. |

### II. Timers, Scales & Limits
| Offset (Dec) | Offset (Hex) | Variable Name | Type | Description / VM Semantics |
| :--- | :--- | :--- | :--- | :--- |
| **7** | `$07` | `PQTB` | Byte | **Time Base:** Scalar multiplier used to regulate and smooth physical movement velocity across frame drops. |
| **8** | `$08` | `VXZW` | Byte | **Exclusion Zone Width:** Defines boundary width for collision detection and coordinate clipping limits. |
| **9** | `$09` | `VAUXS` | Byte | **Auxiliary Status:** Special formation flags (such as marking a runner as locked to a base). |
| **10** | `$0A` | `VATMR` | Byte | **Animation Timer:** Decrementing countdown timer used to trigger sprite frame transitions. |
| **11–12** | `$0B–$0C` | `VTLL/VTLH` | Word | **Master Time Limit:** 16-bit lifespan counter. When this ticks down to zero, VGER auto-deallocates the task. |

### III. Trajectory & Coordinate Systems
| Offset (Dec) | Offset (Hex) | Variable Name | Type | Description / VM Semantics |
| :--- | :--- | :--- | :--- | :--- |
| **13–14** | `$0D–$0E` | `VXL/VXH` | Word | **X Coordinate:** 16-bit horizontal screen position. |
| **15–16** | `$0F–$10` | `VDXL/VDXH` | Word | **X Velocity:** Signed 16-bit horizontal speed (Integer upper byte, fractional lower byte). |
| **17–18** | `$11–$12` | `VDDXL/VDDXH` | Word | **X Acceleration:** Signed 16-bit change in horizontal speed. |
| **19–20** | `$13–$14` | `VYL/VYH` | Word | **Y Coordinate:** 16-bit vertical screen position. |
| **21–22** | `$15–$16` | `VDYL/VDYH` | Word | **Y Velocity:** Signed 16-bit vertical speed. |
| **23–24** | `$17–$18` | `VDDYL/VDDYH` | Word | **Y Acceleration:** Signed 16-bit vertical acceleration. **Critical for gravity physics** on ballistic objects like batted baseballs. |

### IV. Blitting, Video, & Graphics Interface
| Offset (Dec) | Offset (Hex) | Variable Name | Type | Description / VM Semantics |
| :--- | :--- | :--- | :--- | :--- |
| **25–26** | `$19–$1A` | `VSAL/VSAH` | Word | **Screen RAM Address:** Computed absolute destination address in the 16 KB VRAM buffer. |
| **27** | `$1B` | `VMAGIC` | Byte | **Magic Register Properties:** Hardware flags governing blitter writes, including XOR draw, flips, or rotation. |
| **28** | `$1C` | `VXPAND` | Byte | **Palette Color Mask:** Controls how 1bpp patterns expand into the hardware color palette. |
| **29–30** | `$1D–$1E` | `VPATL/VPATH` | Word | **Sprite Pattern Pointer:** Memory address of the source graphic bitmap in ROM. |
| **31–32** | `$1F–$20` | `VFVPL/VFVPH` | Word | **Linked Vector Pointer:** **The key link!** Allows separate tasks to link to other active nodes (e.g. linking a flying baseball task to its shadow vector). |

### V. Animation Engine Registers
| Offset (Dec) | Offset (Hex) | Variable Name | Type | Description / VM Semantics |
| :--- | :--- | :--- | :--- | :--- |
| **33–34** | `$21–$22` | `VPCL/VPCH` | Word | **Animation Program Counter:** Tracks execution through compiled macro-animation scripts. |
| **35–36** | `$23–$24` | `VSPL/VSPH` | Word | **Animation Stack Pointer:** Local stack pointer used to store animation loop return targets. |
| **37–38** | `$25–$26` | `VPTBL/VPTBH` | Word | **Animation Pattern Table Pointer:** Base address pointing to the frame offset table for the current sprite set. |

### VI. Collision Engine, Object Identity, & Auxiliary Metadata
| Offset (Dec) | Offset (Hex) | Variable Name | Type | Description / VM Semantics |
| :--- | :--- | :--- | :--- | :--- |
| **39–40** | `$27–$28` | `VIRL/VIRH` | Word | **Intercept/Collision Routine:** Code pointer to the custom collision or hit-test handler for this task. |
| **41** | `$29` | `VINTER/VRACK` | Byte | **Intercept / Rack Code:** Active collision feedback status register. |
| **42–43** | `$2A–$2B` | `VFNLPL/VFNLPH` | Word | **Final Animation Pattern:** Displays a specific fallback pattern upon execution halt. |
| **44** | `$2C` | `VSHFTA` | Byte | **Magic Shift Value:** Saved pixel remainder shift offset from the last video blit. |
| **45** | `$2D` | `VIDENT` | Byte | **Object Category/Filter Bitmask:** Identifies the class of the task (e.g. Player, Enemy, Projectile) for selective collision sweeps. |
| **46–47** | `$2E–$2F` | `VFXBL/VFXBH` | Word | **Formation X Bias Offset:** Standard horizontal offset tracking relative to a fleet leader. |
| **48–49** | `$30–$31` | `VFYBL/VFYBH` | Word | **Formation Y Bias Offset:** Standard vertical offset tracking relative to a fleet leader. |
| **50** | `$32` | `VASTKS` | Byte | **Animation Stack Start:** Marker indicating the baseline of the task's private return stack memory block. |

---

## 3. How Does VGER Allocate and Recycle Task Nodes?

To prevent memory fragmentation during rapid spawning and deallocation of game objects, VGER implements a high-performance **Storage Allocator**.

During system boot, VGER reserves a block of RAM for the `MEMPOOL`. The pool is divided into a fixed set of nodes (typically 24 nodes in *Extra Bases*). VGER initializes these nodes by linking them together into a single, contiguous chain called the **`FREELIST`**.

A brilliant optimization in VGER’s design is **link recycling**. When a node is active, bytes 1 and 2 (`PQFL/PQFH`) serve as the active queue's forward pointers. However, when a node is freed, VGER hijacks these exact same bytes to serve as the pointer to the next free slot in the `FREELIST` chain.

```text
Active Task:  [ PQS ] [ PQFL (Forward Active Link) ] [ PQBL ] [ PQRL ] ...
Free Task:    [ PQS ] [ NEXT_FREE_NODE_POINTER     ] [ PQBL ] [ PQRL ] ...
```

This prevents heap overhead and allows allocation and deallocation to execute in $O(1)$ constant time.

### A. The `getnode` Subroutine (Allocation)
### Implementation Reference

The next listing is the exact allocation routine represented by the preceding `FREELIST` model.


When the game wants to spawn a vector, it calls `getnode`. This routine pulls the first available node from the head of the `FREELIST` and updates the list pointer. If no nodes are free, it returns zero.

```assembly
;=========================================================================================
; ----> getnode          ALLOCATE FREE MEMORY NODE                        (Block 0117)
;   Pulls a 64 (decimal) byte node from the head of the FREELIST chain.
;   Input:   None
;   Output:  HL = Allocated node address (or HL = 0 if pool is depleted)
;=========================================================================================
getnode:    ld      hl,(FREELIST)       ; Load current FREELIST head pointer
            ld      a,l                 ; Move LSB to accumulator for NIL check
            or      h                   ; OR with MSB to check if HL is NIL (0)
            jr      z,_getnode_empty    ; If zero, the pool is depleted, skip to exit
            inc     hl                  ; Point to next-node pointer field (offset 1 decimal)
            ld      e,(hl)              ; E = Next free node LSB
            inc     hl                  ; Point to offset 2 decimal
            ld      d,(hl)              ; D = Next free node MSB
            dec     hl                  ; Restore HL pointer to start of node
            dec     hl                  ; Point HL back to offset 0
            ld      (FREELIST),de       ; Update FREELIST head to point to next node
            ret                         ; Return with HL = allocated node address
_getnode_empty:
            ret                         ; Return with HL = 0 (NIL)
```

### B. The `freenode` Subroutine (Deallocation)
When an object is caught, destroyed, or travels out of bounds, VGER unlinks it from the active queue and calls `freenode` to prepend it back to the `FREELIST` chain.

```assembly
;=========================================================================================
; ----> freenode         DEALLOCATE MEMORY NODE                           (Block 0117)
;   Prepends a freed 64 (decimal) byte node back to the head of the FREELIST chain.
;   Input:   HL = Address of node to release
;   Output:  None
;=========================================================================================
freenode:   ld      de,(FREELIST)       ; DE = Current FREELIST head pointer
            ld      (FREELIST),hl       ; Point FREELIST head to our newly freed node
            inc     hl                  ; Point to link pointer field of our node
            ld      (hl),e              ; Write old FREELIST LSB into our node
            inc     hl                  ; Point to offset 2 decimal
            ld      (hl),d              ; Write old FREELIST MSB into our node
            ret                         ; Node is now successfully recycled
```

---

## 4. How Are Local Variables and Parameters Managed?

Writing advanced logic at the assembly level requires managing temporary variables and arguments. To avoid polluting global Z80 CPU registers, VGER provides a standardized **Stack Frame Allocation system** (`<FRAME` and `FRAME>`).

This system mimics the function call and activation record mechanics used by modern high-level compilers. When a compiled definition executes, it establishes a local stack frame using the Z80's **`IY` register** as the dedicated **Frame Pointer**.

### A. Frame Initialization (`_FRAME` / `FRAME`)
To set up a local frame, the compiled code calls the `FRAME` macro. This saves the caller's old frame pointer and aligns `IY` to point to the current parameter stack:

```assembly
;=========================================================================================
; ----> FRAME            ESTABLISH LOCAL STACK FRAME                      (Block 0045)
;   Saves current frame pointer IY and establishes a new frame at the Parameter Stack (SP).
;=========================================================================================
_FRAME:     push    iy                  ; Save caller's frame pointer on return stack
            ld      iy,$0000            ; Clear IY register
            add     iy,sp               ; Set IY to point to base of current stack (SP)
            ret                         ; Frame is now active and ready
```

By binding `IY` to the base of the parameter stack (`SP`), all arguments passed into the function can now be addressed at positive, predictable offsets from `IY`.

### B. Parameter Mapping
Parameters passed into the function on the stack are indexed sequentially using positive offsets from the frame pointer (`IY`):

*   **`1PARAM` (offset `+2` decimal):** The first parameter passed to the stack (`IY+2`).
*   **`2PARAM` (offset `+4` decimal):** The second parameter passed to the stack (`IY+4`).
*   **`3PARAM` (offset `+6` decimal):** The third parameter passed to the stack (`IY+6`).

This offset mapping is defined via hardware-linked constants:

```assembly
FR.P1       EQU     2                   ; Offset for first parameter
FR.P2       EQU     4                   ; Offset for second parameter
FR.P3       EQU     6                   ; Offset for third parameter
```

Using this architecture, the task code can modify values on the stack or perform arithmetic calculations simply by reading offsets relative to `IY` (such as `ld e,(iy+FR.P1)`), leaving other CPU registers completely free for high-speed physics calculations.

### C. Frame Destruction (`UNFRAME` / `FRAME>`)
Before exiting, the function must tear down its activation record and restore the caller's previous frame pointer. This is done via `UNFRAME`:

```assembly
;=========================================================================================
; ----> UNFRAME          DESTROY LOCAL STACK FRAME                        (Block 0045)
;   Restores the caller's previous frame pointer IY from the stack.
;=========================================================================================
_UNFRAME:   pop     iy                  ; Restore caller's original IY
            ret                         ; Return safely to caller
```

By decoupling parameters and local variables into distinct, self-contained frames, VGER prevents variable collision, enabling a clean modular workflow for complex game playactions.

---

## 5. How Are Protected-RAM Writes Performed?

To guarantee safe and synchronized writes to protected static CMOS RAM on systems where the hardware is physically present, VGER utilizes several low-level primitives. These routines ensure that interrupts are safely handled, registers are conserved, and the port `$5B` (hex) handshake is sequentially processed for both 16-bit word and 8-bit byte writes.

```assembly
;=========================================================================================
; ----> 2wp!             WRITE 16-BIT WORD TO PROTECTED RAM               (Block 0058)
;   Writes a 16-bit word (DE) to hardware Write-Protected RAM (HL).
;   Unlocks the NVRAM by writing $A5 (hex) to port $5B (hex) before each byte write.
;   Input:   HL = NVRAM Target Address, DE = 16-bit Value
;   Output:  None
;=========================================================================================
_2wp_bang:  ld      a,$A5               ; Load key byte $A5 hex (165 decimal)
            out     ($5B),a             ; Write key to RIGHTPORT to unlock NVRAM LSB write
            ld      (hl),e              ; Write LSB (register E) into RAM
            inc     hl                  ; Point to next NVRAM address
            out     ($5B),a             ; Write key to RIGHTPORT to unlock NVRAM MSB write
            ld      (hl),d              ; Write MSB (register D) into RAM
            ret                         ; Exit subroutine

;=========================================================================================
; ----> 2wpb!            WRITE 8-BIT BYTE TO PROTECTED RAM                (Block 0058)
;   Writes an 8-bit byte (E) to hardware Write-Protected RAM (HL).
;   Unlocks the NVRAM by writing $A5 (hex) to port $5B (hex) before writing.
;   Input:   HL = NVRAM Target Address, E = 8-bit Value
;   Output:  None
;=========================================================================================
_2wpb_bang: ld      a,$A5               ; Load key byte $A5 hex (165 decimal)
            out     ($5B),a             ; Write key to RIGHTPORT to unlock NVRAM byte write
            ld      (hl),e              ; Write byte (register E) into RAM
            ret                         ; Exit subroutine

;=========================================================================================
; ----> wp!              INTERRUPT-SAFE 16-BIT WRITE                      (Block 0058)
;   Disables interrupts, calls 2wp! to write a word, and restores original interrupt state.
;   Input:   HL = NVRAM Target Address, DE = 16-bit Value
;   Output:  None
;=========================================================================================
wp_bang:    ld      a,i                 ; Load Z80 Interrupt register to query current state
            push    af                  ; Save current flag state onto stack
            di                          ; Disable interrupts to protect critical region
            push    hl                  ; Save NVRAM address
            call    _2wp_bang           ; Call 16-bit unlock/write routine
            pop     hl                  ; Restore target address
            pop     af                  ; Pop original interrupt state flags
            jp      po,wp_ei_skip       ; If parity odd (Interrupts were disabled), skip EI
            ei                          ; Re-enable interrupts
wp_ei_skip: ret                         ; Exit safely

;=========================================================================================
; ----> wpb!             INTERRUPT-SAFE 8-BIT WRITE                       (Block 0058)
;   Disables interrupts, calls 2wpb! to write a byte, and restores original state.
;   Input:   HL = NVRAM Target Address, E = 8-bit Value
;   Output:  None
;=========================================================================================
wpb_bang:   ld      a,i                 ; Load Z80 Interrupt register to query current state
            push    af                  ; Save current flag state onto stack
            di                          ; Disable interrupts to protect critical region
            push    hl                  ; Save NVRAM address
            call    _2wpb_bang          ; Call 8-bit unlock/write routine
            pop     hl                  ; Restore target address
            pop     af                  ; Pop original interrupt state flags
            jp      po,wpb_ei_skip      ; If parity odd (Interrupts were disabled), skip EI
            ei                          ; Re-enable interrupts
wpb_ei_skip:ret                         ; Exit safely
```


---

# Chapter III: The Multitasking Queue & Scanline Scheduler

Chapter II showed how an individual Task is stored. This chapter explains how VGER keeps many Tasks organized and decides when each one gets processor time.

The progression is: queue structure → queue operations → time-base adjustment → interrupt configuration → raster-safe scheduling. The queue is the foundation; the scheduler is the mechanism that uses it.

VGER resolves this bottleneck by implementing a decoupled, dual-layer execution model:
1.  **The Foreground Program (Background Executive / `RESUMEBACKGROUND`):** Runs the low-priority, non-time-critical game operations, such as attract loops, credit polling, and high-score processing in the remaining clock cycles.
2.  **The Background Engine (VGER Queue Scheduler / `TRYFOREGROUND`):** Driven by real-time hardware scanline interrupts, this layer automatically updates coordinate physics, steps animations, checks collisions, and renders sprites 60 times per second.

This chapter explores VGER's multitasking queue topology, its dynamic performance scaling (`INCTB`), Z80 interrupt configurations, and the scanline-safe context-switching mechanics that prevent visual screen artifacts.

---

## 1. How Is the Active Task Queue Organized?

To track, update, and render up to dozens of autonomous screen objects (tasks) concurrently, VGER organizes all active entities into a circular, doubly linked list.

Unlike a standard linear linked list that terminates with a `NIL` pointer, the active task nodes in VGER's gameplay queue are connected together in a **closed circular ring**. This structure enables several systems-level advantages:
*   **Constant-Time Insertion/Deletion ($O(1)$):** Tasks can be instantly unlinked or spliced into the queue without shifting other elements in memory.
*   **Zero-Overhead Traversal:** The scheduler steps sequentially from task to task via forward pointers, automatically wrapping back to the beginning without needing to check for `NIL` endpoints.

### The External Queue Anchor (`vqhead`)

To anchor the active queue and prevent null-pointer errors when no tasks are currently active, VGER maintains a persistent, 4 (decimal) byte anchor block in the Write-Protected Static RAM at address **`$D08C` (hex)** (referred to as **`vqhead`**).

A common misconception is that `vqhead` acts as a dummy node inside the circular execution ring itself. In reality, `vqhead` resides outside the ring as an **external directory pointer-pair**:

```text
  vqhead ($D08C hex)
  +--------------------------------+
  | QFL (LSB/MSB) -> First Active  | ----+
  +--------------------------------+     |
  | QBL (LSB/MSB) -> Last Active   | --+ |
  +--------------------------------+   | |
                                       | |
       +-------------------------------+ |
       |                                 |
       v                                 v
  +----------+  PQFL  +----------+  PQFL  +----------+
  |  Task 1  |=======>|  Task 2  |=======>|  Task 3  |---+  (Circular Task Ring)
  |  (Head)  |<=======|  (Node)  |<=======|  (Tail)  |   |
  +----------+  PQBL  +----------+  PQBL  +----------+   |
       ^                                       |         |
       |                                       v         |
       +=================================================+
                                  PQFL
```

*   **`vqhead + 0` (Forward Link / `QFL`):** A 16-bit pointer to the first active task node in the circular queue (or `0` if the queue is completely empty).
*   **`vqhead + 2` (Backward Link / `QBL`):** A 16-bit pointer to the last active task node in the queue (or `0` if empty).

During system boot, VGER initializes the active queue structure by calling the **`NILVQ`** routine. NILVQ writes 16-bit zeros (`NIL` pointers) into both fields of `vqhead`, cleanly representing an empty queue state:

```assembly
;=========================================================================================
; ----> NILVQ            INITIALIZE ACTIVE VECTOR QUEUE HEAD              (Block 0031)
;   Clears the 4 (decimal) bytes of vqhead ($D08C to $D08F hex) to zero (NIL).
;   Input:   None
;   Output:  Memory at vqhead initialized to zero (NIL / Empty queue state)
;=========================================================================================
_NILVQ:     push    bc                  ; Save alternate VM registers
            ld      hl,$D08C            ; HL = Base address of vqhead dummy anchor
            ld      de,$0000            ; DE = 0 (NIL)

            ; Write 16-bit zero to vqhead+0 (QFL)
            ld      (hl),e              ; Write QFL LSB
            inc     hl                  ; Point to vqhead+1
            ld      (hl),d              ; Write QFL MSB

            ; Write 16-bit zero to vqhead+2 (QBL)
            inc     hl                  ; Point to vqhead+2
            ld      (hl),e              ; Write QBL LSB
            inc     hl                  ; Point to vqhead+3
            ld      (hl),d              ; Write QBL MSB
            pop     bc                  ; Restore registers
            ret                         ; Exit to inner interpreter
```

---

## 2. How Are Tasks Added and Advanced?

VGER provides highly optimized, low-level Z80 assembly routines to manipulate this circular linked structure. These routines guarantee $O(1)$ constant-time execution, avoiding the performance penalty of traditional linear list lookups.

### A. The `ADDQ` Subroutine (Node Splicing)
### Implementation Reference

The queue model is established above. The following routine shows the pointer updates used to splice a new Task into that model.


When a new task is spawned, VGER grabs a free 64-byte node from the `FREELIST` pool, initializes its trajectory, timers, and sprite pattern registers, and calls **`ADDQ`** to integrate it into the active execution ring.

`ADDQ` evaluates whether the queue is empty. If empty, it creates a 1-node circular loop pointing to itself and updates `vqhead`. Otherwise, it splices the node directly between the old tail (`QBL`) and the head (`QFL`):

```assembly
;=========================================================================================
; ----> ADDQ             SPLICE NEW NODE INTO ACTIVE TASK QUEUE           (Block 0118)
;   Slices a newly allocated 64 (decimal) byte task node into the circular active queue.
;   Input:   HL = Address of the newly allocated task node ($40 bytes)
;            IY = Address of the Queue Head anchor (vqhead = $D08C hex)
;   Output:  Queue pointers updated; new task integrated into multitasking cycle
;=========================================================================================
_ADDQ:      ld      e,(iy+$00)          ; DE = vqhead->QFL (Forward Link)
            ld      d,(iy+$01)          ;
            ld      a,e                 ;
            or      d                   ; Check if queue is empty (QFL == NIL)
            jr      nz,_ADDQ_splicing   ; If non-zero, active tasks exist; skip to splice

            ; Queue is empty: Make node self-referential
            ld      e,l                 ; DE = Address of new node
            ld      d,h                 ;

            ; Set task links: PQFL (offset 1) and PQBL (offset 3) point to task itself
            inc     hl                  ; Point to PQFL LSB (offset 1)
            ld      (hl),e              ; PQFL LSB = Node LSB
            inc     hl                  ; Point to PQFL MSB
            ld      (hl),d              ; PQFL MSB = Node MSB
            inc     hl                  ; Point to PQBL LSB (offset 3)
            ld      (hl),e              ; PQBL LSB = Node LSB
            inc     hl                  ; Point to PQBL MSB
            ld      (hl),d              ; PQBL MSB = Node MSB

            ; Restore HL to point to start of task node (offset 0)
            dec     hl                  ; Restore offset 3
            dec     hl                  ; Restore offset 2
            dec     hl                  ; Restore offset 1
            dec     hl                  ; Point back to offset 0

            ; Update vqhead external pointers to anchor this new node
            ld      (iy+$00),l          ; vqhead->QFL LSB = Node LSB
            ld      (iy+$01),h          ; vqhead->QFL MSB = Node MSB
            ld      (iy+$02),l          ; vqhead->QBL LSB = Node LSB
            ld      (iy+$03),h          ; vqhead->QBL MSB = Node MSB
            ret                         ; Done

_ADDQ_splicing:
            ; Queue is active: Splice node at the tail (before head, after old tail)
            ld      c,(iy+$02)          ; BC = Current Queue Head Backward Link (old tail)
            ld      b,(iy+$03)          ;

            ; Set new node's links: PQFL points to head (DE), PQBL points to old tail (BC)
            inc     hl                  ; Point to PQFL (offset 1)
            ld      (hl),e              ; PQFL LSB = head LSB
            inc     hl                  ; Point to PQFL MSB
            ld      (hl),d              ; PQFL MSB = head MSB
            inc     hl                  ; Point to PQBL (offset 3)
            ld      (hl),c              ; PQBL LSB = old tail LSB
            inc     hl                  ; Point to PQBL MSB
            ld      (hl),b              ; PQBL MSB = old tail MSB

            ; Restore HL to point to start of task node (offset 0)
            dec     hl                  ; Restore offset 3
            dec     hl                  ; Restore offset 2
            dec     hl                  ; Restore offset 1
            dec     hl                  ; Point back to offset 0

            ; Update old tail's forward link (old_tail->PQFL = HL)
            push    hl                  ; Save new node address
            ld      l,c                 ; HL = old tail address
            ld      h,b                 ;
            inc     hl                  ; Point to PQFL (offset 1)
            pop     de                  ; DE = new node address
            ld      (hl),e              ; old_tail->PQFL LSB = new node LSB
            inc     hl                  ; Point to PQFL MSB
            ld      (hl),d              ; old_tail->PQFL MSB = new node MSB

            ; Update head's backward link (head->PQBL = new node (DE))
            ld      l,e                 ; HL = new node address
            ld      h,d                 ;
            ld      e,(iy+$00)          ; DE = head address
            ld      d,(iy+$01)          ;
            push    hl                  ; Save new node address
            ex      de,hl               ; HL = head address, DE = new node address
            inc     hl                  ; Point to PQFL (offset 1)
            inc     hl                  ; Point to offset 2
            inc     hl                  ; Point to PQBL (offset 3)
            ld      (hl),e              ; head->PQBL LSB = new node LSB
            inc     hl                  ; Point to PQBL MSB
            ld      (hl),d              ; head->PQBL MSB = new node MSB
            pop     hl                  ; HL = new node address

            ; Update vqhead external tail pointer (vqhead->QBL = HL)
            ld      (iy+$02),l          ; vqhead->QBL LSB = new node LSB
            ld      (iy+$03),h          ; vqhead->QBL MSB = new node MSB
            ret                         ; Splicing complete
```

### B. The `nextq` Subroutine (Execution Advancing)

During the background execution pass, VGER moves sequentially from task to task. The **`nextq`** subroutine advances the active queue pointer to the next active task node in the circular execution ring:

```assembly
;=========================================================================================
; ----> nextq            ADVANCE ACTIVE TASK QUEUE POINTER               (Block 0120)
;   Advances the execution queue head pointer inside vqhead.
;   Input:   IY = Address of the Queue Head (vqhead)
;   Output:  Queue Head links advanced to the next active task in the ring
;=========================================================================================
_nextq:     ld      l,(iy+$00)          ; HL = Forward Link of Queue Head (QFL LSB)
            ld      h,(iy+$01)          ; HL = Forward Link of Queue Head (QFL MSB)
            ld      a,h                 ;
            or      l                   ; Check if queue is empty (HL == NIL)
            ret     z                   ; Return immediately if empty

            inc     hl                  ; Point to task forward link PQFL (offset 1)
            ld      e,(hl)              ; E = Next active task LSB
            inc     hl                  ; Point to offset 2
            ld      d,(hl)              ; D = Next active task MSB

            ; Update vqhead QFL to point to the next task in the circular ring
            ld      (iy+$00),e          ; Update vqhead QFL LSB to next task
            ld      (iy+$01),d          ; Update vqhead QFL MSB to next task

            ; Retrieve next task's backward link (which becomes the new queue tail)
            push    de                  ; Save next task address
            ex      de,hl               ; HL = next task address, DE = old task address
            inc     hl                  ; Point to offset 1
            inc     hl                  ; Point to offset 2
            inc     hl                  ; Point to PQBL (offset 3)
            ld      e,(hl)              ; E = LSB of next task's backward link (the new tail)
            inc     hl                  ; Point to offset 4
            ld      d,(hl)              ; D = MSB of next task's backward link
            pop     hl                  ; HL = next task address

            ; Update vqhead QBL to point to the new tail
            ld      (iy+$02),e          ; Update vqhead QBL LSB
            ld      (iy+$03),d          ; Update vqhead QBL MSB
            ret                         ; Done
```

### C. The `INCTB` Subroutine (Dynamic Time-Base Performance Scaling)

If a heavy cascade of explosions or active tasks consumes more processing time than the 16.6 ms frame budget allows, VGER prevents sluggish playaction slow-motion by executing **`INCTB` (Increment Time Base)**.

Once per VBLANK pass, `INCTB` traverses the active queue and adds a scaling delta `C` to the `PQTB` (Time Base, offset `$07` hex) multiplier of *every* active task. If frame rate drop-offs are detected, `PQTB` increases, forcing the movement vectors to integrate larger coordinate offsets during the subsequent tick to preserve real-time gameplay parity.

```assembly
;=========================================================================================
; ----> INCTB            SCALE TIME BASE MULTIPLIER QUEUE-WIDE            (Block 0120)
;   Traverses all active task nodes in the execution queue and increments/scales the
;   individual Time Base scalar byte (PQTB, offset 7) to maintain consistent physics.
;   Input:   IY = Queue Head Address (vqhead)
;            C  = Delta scaling factor to apply to all task timebases
;   Output:  All active task nodes' PQTB multipliers updated
;=========================================================================================
_INCTB:     ld      l,(iy+$00)          ; HL = Queue Forward Link LSB (QFL)
            ld      h,(iy+$01)          ; HL = Queue Forward Link MSB (QFH)
            ld      a,h                 ;
            or      l                   ; Check if list is empty
            ret     z                   ; Return immediately if empty

            ld      e,l                 ; Setup loop tracking pointer
            ld      d,h                 ; DE = Pointer to first active task node

_INCTB_loop:
            push    de                  ; Save current node pointer
            ld      de,$0007            ; Offset to PQTB (Time Base, byte 7)
            add     hl,de               ; HL points directly to task's PQTB byte
            ld      a,(hl)              ; Read current scalar Time Base
            add     a,c                 ; Accumulate the scale delta
            ld      (hl),a              ; Write scaled Time Base back to task node

            and     a                   ; Clear carry flag
            sbc     hl,de               ; Restore HL to start of node
            pop     de                  ; Retrieve saved node pointer

            ; Get forward link to next task in circular queue
            inc     hl                  ; Point to forward link field (offset 1)
            ld      a,(hl)              ; Read next Forward Link LSB
            inc     hl                  ;
            ld      h,(hl)              ; Read next Forward Link MSB
            ld      l,a                 ; HL = Next active task node address

            ; Check if we have completed a full traversal loop back to starting task
            xor     e                   ; Compare current LSB to starting LSB
            ld      b,a                 ;
            ld      a,h                 ;
            xor     d                   ; Compare current MSB to starting MSB
            or      b                   ;
            jr      nz,_INCTB_loop      ; If not back to start, continue traversal

            ret                         ; Queue-wide scaling complete
```

---

## 3. How Does VGER Synchronize with the Display?

To trigger VGER's real-time scheduler passes, the platform relies on physical scanline interrupts tied directly to the monitor's electron gun. However, the exact processor interrupt mode configured at system startup varies considerably across platform games:

### 1. Z80 Interrupt Mode 2 (IM 2) — *Extra Bases*
On *Extra Bases*, VGER configures the Z80 microprocessor for **Interrupt Mode 2** during `INTSTART`. It places the interrupt vector table at high-RAM page `$7C` (hex), loading `$7C` directly into the CPU's `I` register. When the hardware scanline interrupts fire, the CPU combines `I` with the vector byte broadcasted on the data bus to perform a direct look-up jump to `TIMINT` or `BGENDI` with zero CPU overhead.

### 2. Z80 Interrupt Mode 0 (IM 0) — *Gorf*
On *Gorf*, the warmstart routine explicitly configures the Z80 CPU for **Interrupt Mode 0 (IM 0)** at startup:
```assembly
WARMSTRT:   di                          ; Disable interrupts during system initialization
            im      0                   ; Set Z80 processor to Interrupt Mode 0
```
Under IM 0, the hardware places an instruction (typically a single-byte Restart opcode such as `RST $10` or `RST $08`) directly onto the data bus when an interrupt is acknowledged, prompting the CPU to execute a fast jump to a fixed low-memory address. The VGER kernel adapts transparently to either execution environment, preserving synchronized timing.

### The Three Scanline Interrupt Slices
Regardless of the Z80 interrupt mode, the hardware triggers interrupts at three precise horizontal lines on every vertical frame pass:
*   **Scanline 50 (`BGENDI` / Background Housekeeper):** Temporarily interrupts low-priority logic to read player joysticks, update stereo sound queues, and process attract animations.
*   **Scanline 100 & Line 200 (`TIMINT` / Gameplay Heartbeat):** Decrements global system timers, updates Votrax speech co-processor registers, increments task lifespans (`VTLL/VTLH`), and triggers the master task update loops.

---

## 4. How Does VGER Avoid Raster Conflicts?

Writing pixels into screen memory at the exact microsecond that the monitor's electron gun is scanning that same line causes visual flickering and sprite tearing.

To completely prevent this, VGER implements a **Raster-Sync Avoidance Check** in **`TRYFOREGROUND`**:
1.  VGER queries the current position of the electron beam `C` (reading vertical line feedback register `VERAF` via `GETSYC` from Port `$0E` hex).
2.  It calculates the absolute distance between the beam and the target task's vertical coordinate (`VYH` offset `$14` hex).
3.  If $|VYH - C|$ is smaller than the task's individual **`VXZW` (Exclusion Zone Width, offset `$08` hex)**, the beam is too close! The scheduler **bypasses drawing and updating** the task on this frame, jumping straight to `RESUMEBACKGROUND` to protect raster timing.

If the timing is safe, VGER executes a complete **Context Switch** to run the task's subroutine:

```assembly
;=========================================================================================
; ----> TRYFOREGROUND    SCHEDULER & CONTEXT-SWITCHING TASK LOOP          (Block 0134)
;   Core task scheduler. Traverses active circular execution queue, performs raster-safe
;   flicker avoidance checks, and context-switches execution directly into task logic.
;   Input:   vqhead = Circular active queue dummy node
;   Output:  CPU execution transferred to selected active Vector Object
;=========================================================================================
_TRYFOREGROUND:
            xor     a                   ; A = 0
            ld      (BACKGROUNDRUNNING),a ; Pause background executive during foreground
            ei                          ; Enable interrupts safely

_TRYAGAIN:  call    _GETSYC             ; Read current CRT active vertical scanline
            ld      c,a                 ; C = Current active scanline coordinate
            ld      a,(BGTIMER)         ; Read background task timer
            and     a                   ; Check if timer has run out
            jp      z,_RESUMEBACKGROUND ; If timer is 0, time-slice is up; exit to background

            ; Setup active queue pointer
            ld      iy,vqhead           ; IY = Pointer to active execution loop head
            ld      l,(iy+$00)          ; HL = QFL LSB
            ld      h,(iy+$01)          ; HL = QFL MSB
            ld      a,h                 ;
            or      l                   ; Check if list is empty (HL == 0)
            jp      z,_RESUMEBACKGROUND ; If empty, exit to background executive

            ; Register context transfer: Setup IX to point directly to current task node
            push    hl                  ; Push node address
            pop     ix                  ; IX = Current active Vector Object pointer

            ; Verify task is active and has valid timebase
            ld      a,(ix+$07)          ; A = Current task Time Base (PQTB)
            and     a                   ; Verify Time Base is non-zero
            jp      z,_RESUMEBACKGROUND ; If 0, skip execution

            ; Raster-Sync Avoidance Check
            bit     3,(ix+$00)          ; Read PQSDS flag (bit 3 of PQS offset 0)
            jr      nz,_TRY_dispatch    ; If PQSDS is set, bypass raster check entirely

            ; Calculate vertical proximity to electron beam
            ld      a,(ix+$14)          ; A = Task Vertical Position MSB (VYH)
            sub     c                   ; Subtract current scanline (VYH - C)
            jr      nc,_TRY_abs_diff    ; If positive, skip sign inversion
            cpl                         ; Invert sign to calculate absolute value
            inc     a                   ; A = |VYH - C|

_TRY_abs_diff:
            cp      (ix+$08)            ; Compare against task Exclusion Zone Width (VXZW)
            jp      c,_RESUMEBACKGROUND ; If $|VYH - C| < VXZW$, collision risk is HIGH! Skip task

_TRY_dispatch:
            di                          ; Disable interrupts during pointer advance
            call    _nextq              ; Shift active head link to advance pointer
            ei                          ; Re-enable interrupts

            ; Context Switch: Setup jump table target and execute
            ld      hl,_TRYAGAIN        ; Set return target to scheduler loop
            push    hl                  ; Push scheduler return address onto return stack
            ld      l,(ix+$05)          ; L = Task execution routine LSB (PQRL)
            ld      h,(ix+$06)          ; H = Task execution routine MSB (PQRH)
            jp      (hl)                ; JUMP DIRECTLY INTO TASK CODE (jp (hl))
```

When a task update completes, VGER executes the return handshake **`RESUMEBACKGROUND`**, popping saved CPU registers off the stack to seamlessly resume the interrupted background tasks:

```assembly
_RESUMEBACKGROUND:
            di                          ; Disable interrupts during stack teardown
            ld      a,(BGWINDOW)        ; A = Background window line size
            add     a,c                 ; Calculate offset
            ld      c,a                 ;
            sub     112                 ; Adjust boundaries
            cp      52                  ; Proximity check
            jr      c,_RESUME_teardown  ; If within safe timing, skip interrupt reload

            ld      a,c                 ; Setup interrupt lines
            out     (INLIN),a           ; Output scanline target to hardware port
            ld      a,BGINTVEC          ; Get vector
            out     (INFBK),a           ; Force interrupt feedback reload

_RESUME_teardown:
            ; Restore normal/alternate CPU registers from interrupt stack
            pop     iy                  ; Restore normal index pointer IY
            pop     ix                  ; Restore normal index pointer IX
            pop     hl                  ; Restore normal HL register
            pop     de                  ; Restore normal DE register
            pop     bc                  ; Restore normal BC register
            pop     af                  ; Restore primary AF register & flags
            exx                         ; Switch to alternate register set
            ex      af,af\'                  ; Switch to alternate accumulator & flags
            pop     hl                  ; Restore alternate HL
            pop     de                  ; Restore alternate DE
            pop     bc                  ; Restore alternate BC

            ld      a,$01                   ; Set flag
            ld      (BACKGROUNDRUNNING),a   ; Re-enable background executive
            ld      a,BGTLMT                ; Get limit
            ld      (BGTIMER),a             ; Reset background timer
            pop     af                      ; Restore alternate AF
            ei                              ; Re-enable interrupts
            ret                             ; Return safely to background executive loop
```


---

# Chapter IV: The Physics & Trajectory Engine (VMR)

The queue scheduler determines which Task is processed. The **Vector Management Routine (VMR)** determines how that Task's position and motion are updated.

This chapter moves from the common vector representation to linear movement, double-derivative movement, joystick input, and polar-coordinate calculations. The goal is to understand the data being manipulated before examining the Z80 routines that perform the calculations.

---

## 1. How Is Motion Represented and Updated?

At the architecture level, VMR operations are triggered when VGER's Queue Scheduler advances to an active task node and reads its 16-bit **Routine Pointer (`PQRL`/`PQRH`)** located at offsets `$05–$06` (hexadecimal). Rather than executing arbitrary routines, this pointer typically routes to one of VGER's standardized VMR update methods:

*   **`XADWRITE` / `XIWRITE`:** Erases the task's old sprite, executes linear coordinate translation with boundary limit checking, runs animation updates, and redraws the sprite using the hardware blitter.
*   **`XADDWRITE`:** Erases the old sprite, calculates a second-derivative trajectory (integrating acceleration and velocity), updates animation, and draws the updated pattern.
*   **`JOYWRITE`:** Reads hardware joystick inputs, applies directional acceleration to coordinate vectors, updates animation, and renders the modified position.

By routing task updates through these standardized primitives, game developers do not need to write custom Z80 trajectory math. Instead, they simply configure the physics parameters directly inside the Task Header Block.

### Physics Vector Offset Schema
The trajectory engine acts on a dense matrix of 16-bit signed vector registers mapped to specific byte offsets in the 64-byte (decimal) task node. These registers utilize a fixed-point decimal format where the **upper byte represents the integer portion** and the **lower byte represents the fractional portion**:

```text
       Task Node RAM offsets $0D to $18 (hexadecimal)
+-----------------------------------------------------------+
| $0D–$0E : VXL / VXH   --- Horizontal Coordinate Vector   |
| $0F–$10 : VDXL / VDXH --- Horizontal Velocity Vector     |
| $11–$12 : VDDXL/VDDXH --- Horizontal Acceleration Vector |
| $13–$14 : VYL / VYH   --- Vertical Coordinate Vector     |
| $15–$16 : VDYL / VDYH --- Vertical Velocity Vector       |
| $17–$18 : VDDYL/VDDYH --- Vertical Acceleration Vector   |
+-----------------------------------------------------------+
```

---

## 2. How Does Linear Movement Work?

The primary workhorse for standard movement is the **`VECTLC` (Vector Linear translation with Limit Clamping)** subroutine. It performs a single integration of 16-bit velocity vectors onto 16-bit position vectors, scaled dynamically by the current frame's Time Base factor.

If the updated coordinates travel beyond the physical dimensions of the active screen, `VECTLC` handles automatic boundary clamping and deallocation via the **`NUD`** fallback routine.

### Standard Z80 Disassembly: `VECTLC` & `NUD`
### Conceptual Checkpoint

At this point, the important model is simple: a Task stores position and velocity, `VECTLC` applies velocity to position according to the current Time Base, and `NUD` handles an object that reaches the configured boundary. The listing below shows how those operations are implemented.


The following assembly block illustrates the raw Z80 translation of the compiled VGER `VECTLC` routine. The Time Base scaling multiplier—passed to the routine in CPU register `C`—regulates the loop:

```assembly
;=========================================================================================
; ----> VECTLC           LINEAR VECTOR MOVEMENT UPDATE                  (Block 0147)
;   Updates task position by integrating velocity over a Time Base loop.
;   Input:   IX = Base address of active task node
;            C  = Time Base multiplier (PQTB / frame rate scaler)
;   Output:  Altered coordinate vectors in task node RAM offsets $0D–$14
;=========================================================================================
VECTLC:     ld      a,c                     ; Load current Time Base scaling factor
            or      a                       ; Test if Time Base scale is zero
            ret     z                       ; If zero, bypass movement calculations

; ----> UPDATE HORIZONTAL COORDINATE (X-AXIS)
            ld      l,(ix+13)               ; L = Low byte of X coordinate (fraction)
            ld      h,(ix+14)               ; H = High byte of X coordinate (integer)
            ld      e,(ix+15)               ; E = Low byte of X velocity (fraction)
            ld      d,(ix+16)               ; D = High byte of X velocity (integer)
            ld      b,c                     ; B = Scale factor loop counter

.vlp1:      add     hl,de                   ; Integrate X velocity into X coordinate
            djnz    .vlp1                   ; Loop until Time Base ticks are exhausted

            ld      a,h                     ; Load updated integer X coordinate
            cp      $50                     ; Compare with screen width boundary (80 dec)
            jr      nc,NUD                  ; If coordinate >= $50, go to despawn

            ld      (ix+13),l               ; Store updated fractional X back to task
            ld      (ix+14),h               ; Store updated integer X back to task

; ----> UPDATE VERTICAL COORDINATE (Y-AXIS)
            ld      l,(ix+19)               ; L = Low byte of Y coordinate (fraction)
            ld      h,(ix+20)               ; H = High byte of Y coordinate (integer)
            ld      e,(ix+21)               ; E = Low byte of Y velocity (fraction)
            ld      d,(ix+22)               ; D = High byte of Y velocity (integer)
            ld      b,c                     ; B = Scale factor loop counter

.vlp2:      add     hl,de                   ; Integrate Y velocity into Y coordinate
            djnz    .vlp2                   ; Loop until Time Base ticks are exhausted

            ld      a,h                     ; Load updated integer Y coordinate
            cp      $BA                     ; Compare with height boundary (186 dec)
            jr      nc,NUD                  ; If coordinate >= $BA, go to despawn

            ld      (ix+19),l               ; Store updated fractional Y back to task
            ld      (ix+20),h               ; Store updated integer Y back to task

            ld      (ix+8),$28              ; Reset task Exclusion Zone Width (VXZW = 40 dec)
            ret                             ; Return safely

; ----> BOUNDARY DESPAWN FALLBACK
NUD:        res     7,(ix+0)                ; Clear PQSRH bit (halt the task)
            set     6,(ix+0)                ; Set PQSDW bit (suppress rendering)
            ret                             ; Return
```

### Architectural Clamping Logic
*   **Time-Slicing loop (`.vlp1` / `.vlp2`):** Adds the 16-bit velocity `DE` to the 16-bit position `HL` exactly `B` times. If a game exhibits frame rate stutter, the VGER OS automatically increases the Time Base scaler in register `C` (via `TBCALC`), forcing the update loops to step further per frame and maintain consistent playaction speeds.
*   **The Border Trigger `$50` (hexadecimal) / 80 (decimal):** Composed of 80 (decimal) bytes, each horizontal scanline fits exactly 160 (decimal) pixels at 4 (decimal) pixels per byte. When the integer coordinate `H` crosses `$50` (hexadecimal), the sprite has travelled completely off-screen and is unlinked.
*   **The Border Trigger `$BA` (hexadecimal) / 186 (decimal):** Since the screen is 204 (decimal) lines high, `$BA` (hexadecimal) represents the lower horizontal blanking boundary.
*   **The `NUD` Action:** When an object flies out of bounds, `NUD` immediately clears the task's execution run bit (**`PQSRH`** - bit 7 (decimal) of status offset `$00` hex) and sets the suppress drawing bit (**`PQSDW`** - bit 6 (decimal) of status offset `$00` hex). On the next scheduler interrupt pass, the system unlinks the task from the queue and recycles its RAM.

---

## 3. How Does Double-Derivative Motion Produce a Trajectory?

For more complex physical simulations—such as a rising and falling baseball, wind resistance on a batted ball, or diving patterns for alien spacecraft—VGER implements **`VECTDD` (Vector Double-Derivative translation)**.

This routine implements a double-integration algorithm:
1.  It integrates the 16-bit Acceleration Vector (`VDDX`) into the 16-bit Velocity Vector (`VDX`).
2.  It integrates the modified Velocity Vector (`VDX`) into the 16-bit Position Vector (`VX`).

This loop is executed dynamically based on the current Time Base ticks.

### Standard Z80 Disassembly: `VECTDD`
### Conceptual Checkpoint

`VECTDD` adds one more level to the same model: acceleration changes velocity, and velocity changes position. The assembly below is the implementation of that two-stage update.


```assembly
;=========================================================================================
; ----> VECTDD           DOUBLE DERIVATIVE Trajectory UPDATE            (Block 0150)
;   Performs dual-level integration (Acceleration -> Velocity -> Position) across PQTB.
;   Input:   IX = Base address of active task node
;            C  = Time Base multiplier (PQTB)
;   Output:  Altered coordinates, velocities, and status flags
;=========================================================================================
VECTDD:     bit     0,(ix+0)                ; Check PQSFRZ bit (offstage freeze flag)
            jr      z,.proc_vect            ; If clear, proceed with physics calculations
            set     6,(ix+0)                ; If frozen, set PQSDW (suppress draw)
            ret                             ; Exit immediately

.proc_vect: ld      a,c                     ; Load Time Base scale
            or      a                       ; Test if scale is zero
            ret     z                       ; If zero, bypass updates

            push    af                      ; Save Time Base scale loop counter

; ----> UPDATE X-AXIS TRAJECTORY
            ld      l,(ix+13)               ; L = Low byte of X coordinate
            ld      h,(ix+14)               ; H = High byte of X coordinate
            ld      e,(ix+15)               ; E = Low byte of X velocity
            ld      d,(ix+16)               ; D = High byte of X velocity
            ld      c,(ix+17)               ; C = Low byte of X acceleration
            ld      b,(ix+18)               ; B = High byte of X acceleration

.vupx:      ex      de,hl                   ; Swap position (HL) and velocity (DE)
            add     hl,bc                   ; Integrate acceleration (BC) into velocity (HL)
            ex      de,hl                   ; Swap back: HL = position, DE = velocity
            add     hl,de                   ; Integrate velocity (DE) into position (HL)
            dec     a                       ; Decrement loop counter
            jr      nz,.vupx                ; Repeat double-integration for all ticks

            ld      (ix+15),e               ; Save updated fractional X velocity
            ld      (ix+16),d               ; Save updated integer X velocity
            ld      (ix+13),l               ; Save updated fractional X coordinate
            ld      (ix+14),h               ; Save updated integer X coordinate

            ld      a,h                     ; Load updated integer X coordinate
            cp      $80                     ; Compare with offstage limit (128 dec)
            jr      c,.proc_y               ; If X < 128, skip to Y update
            set     0,(ix+0)                ; Set PQSFRZ (freeze vector offstage)
            set     6,(ix+0)                ; Set PQSDW (suppress write)

; ----> UPDATE Y-AXIS TRAJECTORY
.proc_y:    pop     af                      ; Restore Time Base scale loop counter
            ld      l,(ix+19)               ; L = Low byte of Y coordinate
            ld      h,(ix+20)               ; H = High byte of Y coordinate
            ld      e,(ix+21)               ; E = Low byte of Y velocity
            ld      d,(ix+22)               ; D = High byte of Y velocity
            ld      c,(ix+23)               ; C = Low byte of Y acceleration
            ld      b,(ix+24)               ; B = High byte of Y acceleration

.vupy:      ex      de,hl                   ; Swap position (HL) and velocity (DE)
            add     hl,bc                   ; Integrate acceleration (BC) into velocity (HL)
            ex      de,hl                   ; Swap back
            add     hl,de                   ; Integrate velocity (DE) into position (HL)
            dec     a                       ; Decrement loop counter
            jr      nz,.vupy                ; Repeat for all scale ticks

            ld      (ix+21),e               ; Save updated fractional Y velocity
            ld      (ix+22),d               ; Save updated integer Y velocity
            ld      (ix+19),l               ; Save updated fractional Y coordinate
            ld      (ix+20),h               ; Save updated integer Y coordinate

            ld      a,h                     ; Load updated integer Y coordinate
            cp      182                     ; Compare with vertical limit (182 dec)
            ret     c                       ; If Y < 182, exit safely
            set     0,(ix+0)                ; Set PQSFRZ (freeze vector offstage)
            set     6,(ix+0)                ; Set PQSDW (suppress write)
            ret                             ; Return
```

### Applying Gravity Simulation
By configuring the vertical acceleration vector (**`VDDYL`/`VDDYH`** at offsets `$17–$18` hex) to point continuously downward (e.g., loading `$0004` hex to apply a slight downward force), `VECTDD` naturally curves any launched object into a parabolic flight path. The velocity is modified on every background tick, causing a thrown baseball to slow as it rises, peak, and accelerate downward toward the grass.

---

## 4. How Does Joystick Input Affect Motion?

For interactive player-controlled entities, VGER implements **`JOYUPD` (Joystick Vector Update)**. This routine links raw hardware input signals directly to the vector trajectory engine.

Instead of instantly teleporting an actor, `JOYUPD` reads Port `$12` hex (or Port `$11` hex in cocktail mode) to determine the player's joystick state and smoothly adds or subtracts acceleration vectors, simulating realistic friction and momentum.

> **Note on Port $7B Multiplexing:** Bally's custom blitter silicon intentionally shares Port `$7B` to conserve CPU I/O space. The port acts as `PBAREADRL` when specifying the initial VRAM destination boundary, and then automatically behaves as `PBXMOD` once a blit is triggered to control how many bytes the blitter skips when wrapping to the next raster column.

### Standard Z80 Disassembly: `JOYUPD`
```assembly
;=========================================================================================
; ----> JOYUPD           JOYSTICK-DRIVEN POSITION UPDATE                (Block 0152)
;   Directly translates hardware joystick inputs into acceleration updates.
;   Input:   IX = Base address of active task node
;            C  = Time Base multiplier (PQTB)
;=========================================================================================
JOYUPD:     ld      a,c                     ; Load Time Base scale
            or      a                       ; Test if scale is zero
            ret     z                       ; If zero, bypass updates

            call    gj                      ; Read joystick input via RAM vector
            and     $0C                     ; Mask for Vertical inputs (Up / Down)
            jr      z,JXCK                  ; If no vertical inputs, skip to horizontal

            ld      l,(ix+19)               ; L = Low byte of Y coordinate
            ld      h,(ix+20)               ; H = High byte of Y coordinate
            ld      e,(ix+21)               ; E = Low byte of Y velocity
            ld      d,(ix+22)               ; D = High byte of Y velocity
            ld      b,c                     ; B = Scale factor loop counter

            call    gj                      ; Read joystick again
            and     $08                     ; Check Up switch (bit 3 active-high)
            jr      z,.joy_down             ; If clear, process Down input

; ----> PROCESS JOYSTICK UP (SUBTRACT ACCELERATION)
.jlp_up:    and     a                       ; Clear carry
            sbc     hl,de                   ; Subtract velocity from position
            ld      a,h                     ; Move integer position to A
            cp      (ix+23)                 ; Compare with low Y limit (offset 23)
            jr      c,.up_clamp             ; If coordinate < limit, clamp Y
            ld      h,(ix+23)               ; Else, force position to Y limit
            ld      l,0                     ; Clear fractional part
.up_clamp:  djnz    .jlp_up                 ; Loop for all Time Base scale ticks
            jr      .save_y                 ; Skip to save

; ----> PROCESS JOYSTICK DOWN (ADD ACCELERATION)
.joy_down:  add     hl,de                   ; Add velocity to position
            ld      a,h                     ; Move integer position to A
            cp      (ix+24)                 ; Compare with high Y limit (offset 24)
            jr      nc,.down_clamp          ; If coordinate >= limit, clamp Y
            ld      h,(ix+24)               ; Force position to Y limit
            ld      l,0                     ; Clear fractional part
.down_clamp:djnz    .joy_down               ; Loop for all Time Base scale ticks

.save_y:    ld      (ix+19),l               ; Save updated Y fraction
            ld      (ix+20),h               ; Save updated Y integer

; ----> PROCESS HORIZONTAL JOYSTICK AXIS
JXCK:       call    gj                      ; Read joystick
            and     $03                     ; Mask for Horizontal inputs
            ret     z                       ; If zero, exit routine

            ld      l,(ix+13)               ; L = Low byte of X coordinate
            ld      h,(ix+14)               ; H = High byte of X coordinate
            ld      e,(ix+15)               ; E = Low byte of X velocity
            ld      d,(ix+16)               ; D = High byte of X velocity
            ld      b,c                     ; B = Scale factor loop counter

            call    gj                      ; Read joystick again
            and     $02                     ; Check Left switch (bit 1 active-high)
            jr      z,.joy_right            ; If clear, process Right input

; ----> PROCESS JOYSTICK LEFT
.jlp_left:  and     a                       ; Clear carry
            sbc     hl,de                   ; Subtract velocity from position
            ld      a,h                     ; Move integer position to A
            cp      (ix+17)                 ; Compare with low X limit (offset 17)
            jr      c,.left_clamp           ; If coordinate < limit, clamp X
            ld      h,(ix+17)               ; Force position to X limit
            ld      l,0                     ; Clear fraction
.left_clamp:djnz    .jlp_left               ; Loop for all scale ticks
            jr      .save_x                 ; Skip to save

; ----> PROCESS JOYSTICK RIGHT
.joy_right: add     hl,de                   ; Add velocity to position
            ld      a,h                     ; Move integer position to A
            cp      (ix+18)                 ; Compare with high X limit (offset 18)
            jr      nc,.right_clamp         ; If coordinate >= limit, clamp X
            ld      h,(ix+18)               ; Force position to X limit
            ld      l,0                     ; Clear fraction
.right_clamp:djnz   .joy_right              ; Loop for all scale ticks

.save_x:    ld      (ix+13),l               ; Save updated X fraction
            ld      (ix+14),h               ; Save updated X integer
            ret                             ; Return safely
```

---

## 5. How Are Polar Coordinates Converted to Motion?

Beyond standard linear cartesian translation, the VMR subsystem contains a complete trigonometry execution block. This block enables **Polar-to-Cartesian vector conversion**, simplifying circular paths, complex sweep movements, and dynamic targeting trajectories.

### Angle Representation
In the VGER polar system, angles are defined as a single-byte value ranging from **$00 to $FF** (0 to 255 decimal) representing a full 360-degree circle:

*   **Angle $00:** Points directly along the positive X-axis (0 degrees, pointing right).
*   **Angle $40 (64 dec):** Points directly along the positive Y-axis (90 degrees clockwise, pointing down).
*   **Angle $80 (128 dec):** Points directly along the negative X-axis (180 degrees, pointing left).
*   **Angle $C0 (192 dec):** Points directly along the negative Y-axis (270 degrees, pointing up).

### The Sine Table and Scaling Multipliers
To calculate trigonometric coefficients without floating-point support, VGER embeds a 64-byte (decimal) **`sin-table`** representing a 90-degree quadrant ($0$ to $63$ decimal) mapped to fractional values from $0$ to $255$ decimal (where $255$ represents $1.0$ mathematically).

```assembly
;=========================================================================================
; ----> SINE             LOOKUP SINE COEFFICIENT MULTIPLIER             (Block 0200)
;   Fetches sine multiplier from sin-table and scales it by the input vector.
;   Input:   A  = Angle (0 to 63 decimal, mapping 0 to 90 degrees)
;            HL = Base speed or radius scaling factor
;   Output:  H  = Integer component of calculated vector
;=========================================================================================
SINE:       push    hl                      ; Save the base scale factor on the stack
            ld      e,a                     ; Move angle to E
            ld      d,0                     ; Clear D: DE = angle index
            ld      hl,sin_table            ; Load base address of sine table
            add     hl,de                   ; HL = Address of target sine coefficient
            ld      e,(hl)                  ; E = 8-bit sine multiplier coefficient
            pop     hl                      ; Retrieve the base scale factor
            call    UMPY                    ; HL = 16-bit speed (HL) * 8-bit coeff (E)
            ld      a,h                     ; Move calculated integer portion to A
            ret                             ; Return with scaled integer in register A

;=========================================================================================
; ----> COSINE           LOOKUP COSINE COEFFICIENT MULTIPLIER           (Block 0200)
;   Computes cosine coefficient using sine symmetry: cos(x) = sin(90 - x)
;   Input:   A  = Angle (0 to 63 decimal)
;            HL = Base speed or radius scaling factor
;   Output:  H  = Integer component of calculated vector
;=========================================================================================
COSINE:     ld      e,a                     ; Move angle to E
            ld      a,63                    ; Load 90 degrees offset limit (63 decimal)
            sub     e                       ; A = 63 - E
            jr      SINE                    ; Jump directly into SINE lookup
```

### High-Level Trajectory Modifiers
By utilizing these lower-level lookup routines, VGER exposes high-level, virtualized trigonometric verbs that can be executed directly inside animation scripts or playaction subroutines:

*   **`GETCOS`:** Multiplexes angle and speed to compute instantaneous cartesian velocity deltas.
*   **`TURN`:** Generates a smooth rotational sweep. It calculates the necessary change in rectangular velocities over a specified Time Base duration, automatically curving an object’s path.
*   **`RADIUSTURN`:** Performs a constant radius turn (`r`) through a given angle change (`d`) at the velocity defined in **`VPLRVEL`**. It computes the required step timing and applies the acceleration adjustments automatically behind the scenes.
```


---

# Chapter V: The Custom Blitter & Video Hardware Interface (SUR)

## 1. The Screen Update Routine (SUR) Pipeline

Physics changes a Task's coordinates; the SUR subsystem turns those Task values into graphics operations. This chapter therefore follows the path from a Task's graphics fields, through `vwrite` and `verase`, into the Pattern Board hardware.

The technical sections then describe the Pattern Board registers, the transfer routine, raster synchronization, and cocktail-cabinet coordinate handling.

This pipeline delegates drawing to the custom hardware **Pattern Board** blitter, which transfers sprite patterns from ROM or RAM directly into the 16 KB (kilobyte) viewable VRAM buffer mapped at **`$4000` to `$7FBF` (hex)**.

The SUR pipeline provides two standardized multitasking interface routines to draw and erase Vector Objects automatically: **`vwrite`** and **`verase`**. Both of these routines operate directly on the 64 (decimal) byte **Task Header Block** currently loaded into the Z80's index registers (using `IX` as the task pointer and `IY` as the queue pointer).

### A. The `vwrite` Routine (Draw Sprite)
### Implementation Reference

The sequence below is the low-level implementation of the SUR draw operation described above.


When the background scheduler runs, or when an object is spawned, VGER calls `vwrite`. This routine loads the sprite properties from the Task Header Block and programs the blitter.

The execution steps are:
1. Fetch the Palette Color Code offset from `VXPAND` (offset 28 decimal / `$1C` hex) into register `B`.
2. Fetch the Blitter Magic Properties from `VMAGIC` (offset 27 decimal / `$1B` hex) into register `C`.
3. Fetch the absolute vertical and horizontal coordinate positions from `VYH` and `VXH` to determine coordinate positioning.
4. Call **`ffrelabs`** (Flip-Flop Relative to Absolute conversion) to translate the 2D Cartesian screen coordinates into a linear destination VRAM address.
5. Store the calculated screen address into `VSAL/VSAH` (offsets 25–26 decimal / `$19–$1A` hex). This acts as a persistent record of where the sprite was drawn so that it can be erased exactly from this spot on the next frame.
6. Fetch the graphic pattern ROM/RAM address from `VPATL/VPATH` (offsets 29–30 decimal / `$1D–$1E` hex) and load it into index register `IY`.
7. Call **`writep`** (Write Pattern with Header) to initiate the hardware transfer.
8. Save the blitter's shift remainder state byte into `VSHFTA` (offset 44 decimal / `$2C` hex). This remainder is required during deletion to ensure the erase blit perfectly aligns with the original draw boundaries.

```assembly
;=========================================================================================
; ----> vwrite           WRITE VECTOR SPRITE TO VRAM                    (Block 0116)
;   Input:   IX = Address of active 64-byte Task Header Block
;   Output:  Updates VSAL/VSAH and VSHFTA fields inside the task block
;=========================================================================================
vwrite:     ld      b,(ix+$1C)              ; B = VXPAND (Palette Mask)
            ld      c,(ix+$1B)              ; C = VMAGIC (Blitter Properties)
            ld      d,(ix+$14)              ; D = VYH (Y coordinate MSB)
            ld      e,(ix+$0E)              ; E = VXH (X coordinate MSB)
            ld      h,(ix+$1E)              ; H = VPATH (Pattern address MSB)
            ld      l,(ix+$1D)              ; L = VPATL (Pattern address LSB)
            push    hl                      ; Save pattern address on stack
            push    ix                      ; Swap IX/IY context: move task pointer...
            pop     iy                      ; ...into IY for address calculation
            ld      h,(ix+$14)              ; Load Y coordinate into H
            ld      l,(ix+$13)              ; Load fractional Y into L
            call    ffrelabs                ; Call Relative to Absolute address calc
            ld      (ix+$1A),h              ; Store calculated Screen Address MSB (VSAH)
            ld      (ix+$19),l              ; Store calculated Screen Address LSB (VSAL)
            call    writep                  ; Initiate hardware Pattern Board write
            ld      (ix+$2C),c              ; Store resultant Shift value into VSHFTA
            pop     iy                      ; Restore original queue context into IY
            ret                             ; Return
```

### B. The `verase` Routine (Erase Sprite)
Because VGER uses transparent **XOR blitting**, erasing an existing sprite is mathematically identical to drawing it a second time over the same VRAM address. `verase` operates on the historical coordinates and shift parameters recorded during the previous `vwrite` cycle.

```assembly
;=========================================================================================
; ----> verase           ERASE VECTOR SPRITE FROM VRAM                  (Block 0116)
;   Input:   IX = Address of active 64-byte Task Header Block
;   Output:  Sprite is erased from VRAM using previous coordinates and shift
;=========================================================================================
verase:     ld      b,(ix+$1C)              ; B = VXPAND (Palette Mask)
            ld      c,(ix+$2C)              ; C = VSHFTA (Saved Shift from last write)
            ld      h,(ix+$1E)              ; H = VPATH (Pattern address MSB)
            ld      l,(ix+$1D)              ; L = VPATL (Pattern address LSB)
            push    hl                      ; Save pattern address on stack
            push    ix                      ; Setup IY for register swapping
            pop     iy                      ; IY = Task Address
            ld      h,(ix+$1A)              ; H = VSAH (Historical Screen Address MSB)
            ld      l,(ix+$19)              ; L = VSAL (Historical Screen Address LSB)
            call    writep                  ; Re-blit at exact location to erase
            pop     iy                      ; Restore original queue context into IY
            ret                             ; Return
```

---

## 2. How Does the Pattern Board Receive a Blit?

VGER's graphics system is centered around two custom integrated circuits: the **custom Address LSI** (0066-115XX) and the **custom Data LSI** (0066-116XX). These chips are interfaced by the Z80 through 8 (decimal) hardware configuration ports and 2 (decimal) primary registers:
1.  **`MAGIC` (Port `$0C` hex / 12 decimal):** The **Magic Function Generator (MFG)** controls logical operations applied to graphic data as it is blitted into memory.
2.  **`XPAND` (Port `$19` hex / 25 decimal):** The **Color Expander Register** maps 1-bit-per-pixel (1bpp) fonts and line-art into full 2-bit-per-pixel (2bpp) color indices.

### A. The Pattern Board Port Map (I/O Ports `$78 – $7E` hex)
The Pattern Board utilizes a dedicated set of 7 (decimal) hardware write-only registers to direct blitting operations:

| I/O Port (Hex) | Port Constant | Direction | Function and Description |
| ------ | ------ | ------ | ------ |
| **`$78`** | `PBLINADRL` | Write-Only | **Pattern Source Address LSB:** Starting low byte of pattern data. |
| **`$79`** | `PBLINADRH` | Write-Only | **Pattern Source Address MSB:** Starting high byte of pattern data. |
| **`$7A`** | `PBSTAT` | Write-Only | **Pattern Board Status Register:** Configures the hardware transfer mode. |
| **`$7B`** | `PBAREADRL` | Write-Only | **Destination Screen Address LSB:** Target VRAM low byte. |
| **`$7B`** | `PBXMOD` | Write-Only | **Horizontal Line Skip (Xmod):** Byte offset skipped when advancing rows. |
| **`$7C`** | `PBAREADRH` | Write-Only | **Destination Screen Address MSB:** Target VRAM high byte. |
| **`$7D`** | `PBXWIDE` | Write-Only | **Pattern Width (X Width):** 0-relative width of the sprite in bytes. |
| **`$7E`** | `PBYHIGH` | Write-Only | **Pattern Height (Y Height):** 0-relative height of the sprite in lines. |

> **Note on Port $7B Multiplexing:** Bally's custom blitter silicon intentionally shares Port `$7B` to conserve CPU I/O space. The port acts as `PBAREADRL` when specifying the initial VRAM destination boundary, and then automatically behaves as `PBXMOD` once a blit is triggered to control how many bytes the blitter skips when wrapping to the next raster column.

### B. Status and Properties Register Bitmasks

#### I. Magic Register Bits (`MAGIC` Port `$0C` hex)
The byte written to the `MAGIC` port determines how the custom Address LSI intercepts and transforms the Z80's writes to VRAM:
*   **Bit 7 (`MRFLIP`):** Flips the pattern horizontally.
*   **Bit 6 (`MRFLOP`):** Flips the pattern vertically.
*   **Bit 5 (`MRXOR`):** Enables XOR write mode. Writes are combined with existing screen data using exclusive OR logic (the standard VGER blitting mode).
*   **Bit 4 (`MROR`):** Enables OR write mode. Sprites are written using logical OR addition.
*   **Bit 3 (`MREXP`):** Enables hardware Color Expansion. Translates 1bpp monochrome font arrays into 2bpp color sprite buffers.
*   **Bit 2 (`MRROT`):** Enables pattern rotation.

#### II. Pattern Board Status Bits (`PBSTAT` Port `$7A` hex)
The status control byte written to `PBSTAT` modifies the blitter state machine directly:
*   **Bit 5 (`PBFLOP`):** Directs the blitter to decrement the vertical scanline counter, flipping the graphic vertically.
*   **Bit 4 (`PBFLIP`):** Directs the blitter to reverse horizontal scanning direction, flipping the graphic horizontally.
*   **Bit 3 (`PBFLUSH`):** Appends a terminal 0 (decimal) byte to the end of each horizontal scanline. This clears trailing edge artifacts left over from previous blits.
*   **Bit 2 (`PBCONS`):** Sets the blitter to fill the area with a constant solid color value instead of reading graphic patterns.
*   **Bit 1 (`PBEXP`):** Directs the state machine to increment the source address pointer every *other* cycle, stretching pixels horizontally.
*   **Bit 0 (`PBDIR`):** Sets the transfer direction. A value of 0 (decimal) copies data from the pattern source to the VRAM area, while a value of 1 (decimal) reads from VRAM back to the source address.

---

## 3. How Does the Hardware Transfer Routine Program the Blitter?

The custom hardware blitter executes transfers in the background once the initiator register (`PBYHIGH` at port `$7E` hex) is written. To handle this process safely, the VGER kernel uses a highly refined low-level utility subroutine named **`write`**.

`write` takes input registers from the CPU, formats the status byte (`PBSTAT`), calculates the line-skip skip value (`PBXMOD`), and programs the Pattern Board ports.

### A. The `Xmod` Skipping Calculation
A crucial piece of system math is the calculation of **`Xmod` (Horizontal Line Skip)**. Because VGS monitors are vertically oriented (tilted 90 degrees left), sprites are written column-by-column rather than line-by-line.

To move to the start of the next scanline row in a standard 80-byte (decimal) wide screen buffer, the blitter must skip exactly **80 (decimal) bytes** minus or plus the sprite's width. The skip calculation depends on horizontal and vertical mirror states:

*   **Standard Mirroring (FLIP=0, FLOP=0):**
    $$\\text{Xmod} = 80 - \\text{Width}$$
*   **Vertically Flipped (FLIP=0, FLOP=1):**
    $$\\text{Xmod} = 80 + \\text{Width}$$
*   **Horizontally Flipped (FLIP=1, FLOP=0):**
    $$\\text{Xmod} = -80 - \\text{Width}$$
*   **Fully Flipped/Flopped (FLIP=1, FLOP=1):**
    $$\\text{Xmod} = -80 + \\text{Width}$$

This math alters the blitter's internal pointer arithmetic, allowing hardware mirroring to execute in zero overhead.

### B. Hardware `write` Disassembly Walkthrough
The following Z80 implementation illustrates the bare-metal register sequence used to initiate the blit.

```assembly
;=========================================================================================
; ----> write            PROGRAM PATTERN BOARD BLITTER                  (Block 0041)
;   Interfaces directly with the custom Pattern Board and MFG.
;   Input:   B  = VXPAND color code (colors to expand 1bpp patterns to)
;            C  = VMAGIC control properties (Flip, Flop, Expand, XOR, OR)
;            D  = Y size (height of pattern in bytes)
;            E  = X size (width of pattern in bytes)
;            HL = Destination address on screen (scradr)
;            IY = Source address of Pattern (patadr)
;   Output:  Hardware blits pattern to destination VRAM in background.
;=========================================================================================
write:      ld      a,b                     ; Get expand color byte
            out     ($19),a                 ; Set XPAND port ($19 hex)
            ld      a,c                     ; Get Magic properties byte
            out     ($0C),a                 ; Set MAGIC port ($0C hex)

            ; Build baseline PBSTAT status byte (default: PBFLOP [bit 5] & PBCONS [bit 2] set)
            ld      b,$24                   ; Binary: 0010 0100

            ; Handle FLIP/FLOP status updates
            bit     7,c                     ; Check Magic Register FLIP bit
            jr      z,_write_noflip         ; If 0, skip horizontal flip
            set     4,b                     ; Set PBFLIP bit in status register
_write_noflip:
            bit     6,c                     ; Check Magic Register FLOP bit
            jr      z,_write_noflop         ; If 0, skip vertical flip
            res     5,b                     ; Remove PBFLOP bit from status register
_write_noflop:
            push    hl                      ; Save Destination Address on stack
            push    iy                      ; Get pattern source address...
            pop     hl                      ; ...into HL

            ; Handle Expansion status updates
            bit     3,c                     ; Check Magic Register EXPAND bit
            jr      z,_write_noexpand       ; If 0, bypass color expansion
            set     1,b                     ; Set PBEXP bit in status register
            jr      _write_pbst_done        ; Done with PBSTAT configuration
_write_noexpand:
            set     3,b                     ; If not expanding, apply PBFLUSH bit
            inc     e                       ; Adjust width for flush byte boundary
_write_pbst_done:
            ld      a,b                     ; Load compiled status byte
            out     ($7A),a                 ; Output Status byte to PBSTAT register

            ; Output Pattern Source Address
            ld      a,l                     ;
            out     ($78),a                 ; Output Pattern Source LSB (PBLINADRL)
            ld      a,h                     ;
            out     ($79),a                 ; Output Pattern Source MSB (PBLINADRH)

            ; Output VRAM Destination Address
            pop     hl                      ; Retrieve VRAM destination address from stack
            ld      a,l                     ;
            out     ($7B),a                 ; Output Destination Address LSB (PBAREADRL)
            ld      a,h                     ;
            out     ($7C),a                 ; Output Destination Address MSB (PBAREADRH)

            ; Calculate Xmod skipping increment
            ld      h,e                     ; H = Width of pattern
            bit     3,c                     ; Check EXPAND bit
            jr      z,_write_skip_exp_scale ; If not expanding, bypass size scaling
            rlc     h                       ; If expanding, double the X width (*2)
_write_skip_exp_scale:
            dec     h                       ; Make width zero-relative (for hardware counter)
            bit     7,c                     ; Check horizontal FLIP
            jr      z,_write_skip_flip_calc ; If horizontal flip is 0, skip to normal calc

            ; FLIP is set (Backward Horizontal Direction)
            bit     6,c                     ; Check vertical FLOP
            jr      z,_write_flip_noflop    ; If vertical FLOP is 0
            ld      a,$B0                   ; Both Flipped: A = -80 (hex)
            add     a,h                     ; Xmod = -80 + Width
            jr      _write_xmod_out         ; Output skip value
_write_flip_noflop:
            ld      a,$B0                   ; FLIP set, FLOP clear: A = -80 (hex)
            sub     h                       ; Xmod = -80 - Width
            jr      _write_xmod_out         ; Output skip value
_write_skip_flip_calc:
            ; FLIP is clear (Forward Horizontal Direction)
            bit     6,c                     ; Check vertical FLOP
            jr      z,_write_noflip_noflop  ; If vertical FLOP is 0
            ld      a,$50                   ; FLIP clear, FLOP set: A = 80 (decimal)
            add     a,h                     ; Xmod = 80 + Width
            jr      _write_xmod_out         ; Output skip value
_write_noflip_noflop:
            ld      a,$50                   ; Both Clear: A = 80 (decimal)
            sub     h                       ; Xmod = 80 - Width
_write_xmod_out:
            out     ($7B),a                 ; Output calculated Xmod to PBXMOD register

            ; Trigger background transfer
            ld      a,h                     ;
            out     ($7D),a                 ; Output zero-relative X Width to PBXWIDE
            ld      a,d                     ;
            dec     a                       ; Convert Height to 0-relative
            out     ($7E),a                 ; Output Height to PBYHIGH (Initiates Blit!)
            ret                             ; Return
```

---

## 4. How Are Raster Timing and Blanking Controlled?

In a cathode-ray tube (CRT) arcade monitor, the electron gun continuously scans from the top-left to the bottom-right of the screen. Writing to a VRAM buffer while the electron beam is scanning that same region causes **screen tearing** or visual artifacts.

To achieve flicker-free rendering, VGER integrates strict raster-blanking controls and screen-split boundaries.

### A. Blanking & Line Splits
During system initialization, the kernel configures the horizontal drive and vertical blanking limits using **`INITSCREEN`** (Block 192 / Gorf `W_1476`):
1.  **`VERBL` (Vertical Blank Line register, Port `$0A` hex):** Written with **`$CC` (hex)** (204 decimal). This limits VRAM scanning to exactly 204 (decimal) scanlines, preventing the display hardware from scanning the Off-Screen Work Area (`$7C00–$7FFF` hex) where garbage pixels are actively computed.
2.  **`HORCB` (Horizontal Color Boundary, Port `$0D` hex):** Written with **`$0D` (hex)** (13 decimal). This aligns color priorities across horizontal raster sweeps.

### B. Vertical Beam Verification: `GETSYC`
To calculate the electron beam's current position, VGER reads the vertical line feedback register (`VERAF` at port `$0E` hex) via the **`GETSYC`** subroutine.

```assembly
;=========================================================================================
; ----> GETSYC           RETRIEVE CRT ELECTRON BEAM SCANLINE            (Block 0132)
;   Input:   None
;   Output:  A = Current vertical scanline position (0 to 262 decimal)
;=========================================================================================
GETSYC:     xor     a                       ; Clear A
            ld      (LPFLAG),a              ; Reset Light Pen Flag (LPFLAG)
            ld      a,$18                   ; Load vertical interrupt enable command
            out     (INMOD),a               ; Output to INMOD port ($0E hex)
_get_syc_loop:
            ld      a,(LPFLAG)              ; Check if Light Pen interrupt updated line
            and     a                       ;
            jr      z,_get_syc_loop         ; Loop until LPFLAG is non-zero
            ld      a,(LPYC)                ; A = LPYC (Vertical Line Feedback)
            ret                             ; Return
```

---

## 5. How Does Cocktail-Mode Display Flipping Work?

For dual-player cocktail arcade cabinets, Player 2 sits opposite Player 1, viewing the display upside-down. Rather than duplicating graphic assets in ROM to support inverted perspectives, VGER dynamically alters address translation within the **SUR pipeline**.

VGER implements this by dynamically swapping the relative-to-absolute address translation pointers (**`RELABS`** and **`FFRELABS`**) in memory based on the state of the system’s **`COCKTAIL`** flag:

*   **Player 1 Active (`COCKTAIL = 0`):** `RELABS` jumps directly to `norrel` (Normal Relative) and `FFRELABS` jumps to `ffnorrel` (Flip-Flop Relative).
*   **Player 2 Active (`COCKTAIL = 1`):** `RELABS` is redirected to **`cockrel`** and `FFRELABS` is redirected to **`cockff`**.

```assembly
;=========================================================================================
; ----> cockrel          INVERT COORDINATES FOR COCKTAIL MODE           (Block 0039)
;   Input:   BC = exp/mag properties
;            DE = relative X coordinate
;            HL = relative Y coordinate
;   Output:  BC = inverted exp/mag shift
;            HL = inverted absolute Screen RAM address
;=========================================================================================
cockrel:    call    norrel                  ; Calculate normal screen address (HL = scradr)
            ex      de,hl                   ; DE = scradr
            ld      hl,$3FBF                ; HL = last viewable byte of screen VRAM buffer
            and     a                       ; Clear carry flag
            sbc     hl,de                   ; HL = $3FBF - scradr (invert destination byte)
            ld      a,c                     ; Get exp/mag Properties
            xor     $C0                     ; XOR bits 6 & 7 (flips pattern board scan bits)
            ld      c,a                     ; Save inverted properties back to C
            ret                             ; Return
```

By subtracting the screen address from the highest viewable byte of the frame buffer (`$3FBF` hex), VGER cleanly mirrors the entire screen output.

Additionally, executing `xor $C0` flips both the horizontal and vertical scanning flags inside the pattern register. This causes the hardware blitter to draw the sprite backwards and upside down, perfectly correcting the graphic perspective for the opposing player in cocktail cabinets without a single CPU cycle of rendering overhead.


---

# Chapter VI: Collision Detection & Intercept Testing

## 1. How Does VGER Detect Collisions?

VGER uses two levels of collision handling. Software performs a broadphase check using Task metadata and axis-aligned bounds. The custom video hardware can then provide pixel-level intercept information during drawing operations.

The important distinction is that these mechanisms answer different questions: the software pass asks which objects are close enough to examine, while the hardware path reports an intersection during a graphics transfer.

VGER solves this processing bottleneck by implementing a highly elegant **hybrid collision detection framework**. This system balances software broadphase sweep-and-pruning against bare-metal hardware-accelerated pixel intersections:

*   **Software Broadphase (The `CHECKALL` & `CHECKVEC` Subsystems):** When high-level playaction logic requires scanning the surrounding space—such as an enemy spacecraft checking if it has collided with the player, or an infielder sweeping for a baseball—VGER executes an optimized **Axis-Aligned Bounding Box (AABB)** sweep in software. The algorithm dynamically extracts sprite dimensions directly from pattern headers in ROM and filters targets using task identity masks to bypass irrelevant checks, keeping software overhead to an absolute minimum.
*   **Hardware Narrowphase (Silicon-Accelerated Intercepts):** For real-time, pixel-perfect collision detection, VGER offloads the mathematics entirely to the Bally Astrocade custom video silicon—specifically the **Magic Function Generator (MFG)** embedded inside the custom Data LSI chip. When the custom video processor writes pixels to viewable VRAM, specialized hardware bus transceivers automatically detect if non-zero color pixels overlap existing visible pixels on the monitor. This hardware intersection event is latched into a dedicated read-only I/O port. By wrapping this hardware check inside standard screen-update routines, VGER achieves **zero-CPU-overhead narrowphase collisions**, instantly triggering asynchronous callback subroutines registered within the colliding task's header.

---

## 2. How Does the Software Broadphase Work?

When a task requires a proactive check of its physical boundaries against other objects in the active queue, it invokes VGER's software collision engine. This broadphase engine is centered around two highly optimized subroutines: `CHECKVEC` (evaluating a collision between two specific tasks) and `CHECKALL` (evaluating a single task against a filtered subset of the active queue).

### A. Bounding Box Evaluation (`CHECKVEC`)

The **`CHECKVEC`** subroutine (located in Block 0159) performs a standard AABB intersection test between two Vector Objects. The active task executing the routine is loaded into the **`IX`** index register, while the candidate target task to evaluate is loaded into the **`IY`** index register.

Before performing any mathematical coordinate comparisons, `CHECKVEC` evaluates the target's operating status to prevent phantom collisions with inactive objects:

1.  **Halt Check:** The routine reads bit 7 (decimal) (`PQSRH` / Run-Halt flag) of the status byte (`PQS` offset 0 decimal) from candidate `IY`. If this bit is clear (indicating the candidate task is halted or dead), the routine immediately aborts, returning a status of no collision.
2.  **Screen Write Check:** The routine reads bit 5 (decimal) (`PQSDE` / \"Don't Erase\" / \"Don't Collide\" flag) of the status byte. If the candidate object has not yet been drawn or is flagged to bypass collision checks, the routine aborts to prevent evaluating off-screen or uninitialized objects.

If the target is valid, VGER extracts the physical dimensions of both sprites directly from their pattern headers in ROM:

*   It loads the 16-bit sprite pattern address from the `VPATL/H` fields (offsets 29 and 30 decimal / `$1D` and `$1E` hex) of the `IX` task. The first 2 (decimal) bytes of this pattern structure in ROM contain the sprite's dimensions: Byte 0 (decimal) is the **Width** in bytes, and Byte 1 (decimal) is the **Height** in lines. VGER reads these dimensions, storing the `IX` width in register **`C`** and the `IX` height in register **`E`**.
*   It performs the same sequence for candidate `IY`, reading its pattern pointers and storing the candidate's width in register **`B`** and height in register **`D`**.

Using these dimensions and the persistent coordinates stored in the Task Header Blocks, the software evaluates boundary limits on both axes:

#### Y-Axis Overlap Check:
VGER calculates the signed vertical distance between the two objects:
$$\\Delta Y = Y_X - Y_Y = \\text{VYH}(IX) - \\text{VYH}(IY)$$

The engine evaluates the resulting sign of $\\Delta Y$ using the Z80's sign flag:
*   **If $Y_X \\geq Y_Y$ (positive):** The engine compares $\\Delta Y$ with the height of candidate $Y$ (stored in register `D`). If $\\Delta Y \\geq \\text{Height}_Y$, the objects are too far apart vertically to intersect. The routine branches to the exit label **`NOINT`**.
*   **If $Y_X < Y_Y$ (negative):** The engine adds the height of $X$ (stored in register `E`) to the negative delta $\\Delta Y$. If the result remains negative ($\\Delta Y + \\text{Height}_X < 0$), the candidate $Y$ is positioned completely above the boundaries of $X$. The routine branches to **`NOINT`**.

#### X-Axis Overlap Check:
If the Y-axis check succeeds, VGER evaluates horizontal overlap using the exact same logic:
$$\\Delta X = X_X - X_Y = \\text{VXH}(IX) - \\text{VXH}(IY)$$

*   **If $X_X \\geq X_Y$ (positive):** The engine compares $\\Delta X$ with the width of candidate $Y$ (stored in register `B`). If $\\Delta X \\geq \\text{Width}_Y$, the objects are too far apart horizontally to intersect. The routine branches to **`NOINT`**.
*   **If $X_X < X_Y$ (negative):** The engine adds the width of $X$ (stored in register `C`) to the negative delta $\\Delta X$. If the result remains negative ($\\Delta X + \\text{Width}_X < 0$), candidate $Y$ is positioned completely to the left of the boundaries of $X$. The routine branches to **`NOINT`**.

If the coordinates overlap on both axes, a collision is confirmed. The routine loads register **`A`** with `1` (decimal) and performs `and a` to clear the Zero flag (NZ status), indicating a positive hit, before returning.

```text
       Y-Axis Overlap Evaluation                  X-Axis Overlap Evaluation

       (Target Y above source X)                  (Target Y left of source X)
             +----------+                               +----------+
             | Target Y |                               | Target Y |
             +----------+                               +----------+
                  |                                           |
           (Delta Y + H_X < 0)                         (Delta X + W_X < 0)
                  |                                           |
                  v                                           v
             +----------+                               +----------+
             | Source X |                               | Source X |
             +----------+                               +----------+

       No Overlap: Branch to NOINT                No Overlap: Branch to NOINT
```

### B. Queue Sweep & Filtering (`CHECKALL`)

To scan the entire screen for obstacles, the task code calls **`CHECKALL`** (Block 0160). This routine automates traversing the doubly linked circular active task queue starting at the head node, evaluating every active task in the loop against our active task `IX`.

To prevent wasted processing cycles, `CHECKALL` filters target tasks using a **Metadata Mask` passed in register **`C`**:

1.  **Queue Initialization:** The routine loads the address of the first active task in the queue from the **`vqhead`** RAM vector (located at address `$D08C` in write-protected static RAM) into Z80 register pair **`HL`**.
2.  **Self-Collision Exclusion:** Since the active task traversing the queue is itself linked inside the circular list, the routine compares the current candidate address `HL` against our active task address `DE` (transferred from `IX`). If `HL == DE`, the routine automatically bypasses the collision evaluation to prevent an object from colliding with itself, jumping to the queue advancer label **`NOTHIM`**.
3.  **Identity Filter Masking:** If the candidate is a separate object, the routine registers it in the **`IY`** index register and reads its Identity Code (**`VIDENT`** offset 45 decimal / `$2D` hex). It performs a bitwise `AND` on this byte using the mask value in register `C`. For example, in *Gorf*, a player projectile task uses a mask of `$40` (hex) to ignore friendly objects and selectively evaluate collisions only against tasks flagged with enemy identity bits. If the bitwise mask check returns zero, the candidate is ignored, and the loop jumps to **`NOTHIM`**.
4.  **Narrowphase Call:** If the identity bits match, the routine invokes `CHECKVEC` to evaluate the physical bounding boxes. If a collision is returned, the loop terminates immediately, returning to the caller with the **Zero flag cleared (NZ)** and **`IY`** containing the exact RAM address of the collided culprit.
5.  **Queue Pointer Advancement:** If no collision is detected, the routine reads the candidate's Forward Queue Link (**`PQFL/H`** offsets 1 and 2 decimal / `$01–$02` hex) to load the next task address into `HL` and loops back to the comparison block.

---

## 3. How Does the Hardware Detect Pixel Intercepts?

While software bounding boxes are highly effective for coarse broadphase scanning, they cannot easily resolve pixel-perfect intersections of irregular, non-rectangular shapes—such as a pixel-thin beam passing through the narrow wing of a diving alien. For these calculations, VGER relies on Bally's custom video silicon.

The system's custom Data LSI chip houses the **Magic Function Generator (MFG)**, which acts as a hardware co-processor managing raw data writes between the Z80 CPU and the VRAM screen buffer. During standard drawing operations, the MFG monitors data bus activity:

*   When a sprite is blitted to VRAM via the Screen Update Routine (`SUR`), the hardware reads the destination byte currently stored in screen memory (the background pixels) and exclusive-ORs (`XOR`) it with the new sprite pattern bytes.
*   During this `XOR` operation, the hardware evaluated whether a collision has occurred: if any non-zero color pixel (values `1`, `2`, or `3` decimal) from the new sprite pattern overlaps an already written non-zero background pixel in the VRAM byte, the LSI chip's internal logic gates immediately flag a hardware intersection.
*   The hardware registers this overlap event by latching specific bits into the read-only **Intercept Feedback Register** (represented by the constant `INTST` / `INCPT` mapped to Port `$08` hex / 8 decimal).

```text
                    Custom Data LSI (MFG Bus Monitoring)

   Sprite Pattern Byte                    Background VRAM Byte
     (Color Pixel '1')                      (Color Pixel '2')

              \\                                      /
               \\                                    /
                v                                  v
              +--------------------------------------+
              | Hardware XOR Pixel Intersection Gate |
              +--------------------------------------+
                                 |
                                 v
                     [Collision Intercept Detected!]
                                 |
                                 v
         Sets Bit 1 (dec) in Register INTST (Port $08 hex)
```

The Intercept Register (`INTST`) uses a specialized bit layout to identify which specific pixel-pairs intersected during the blit:

*   **Bit 1 (decimal) (`$02` hex):** Set if any color pixel of value `1` (decimal) overlaps another color pixel of value `1` (decimal) in VRAM.
*   **Bit 2 (decimal) (`$04` hex):** Set if any color pixel of value `1` (decimal) overlaps a color pixel of value `2` or `3` (decimal).
*   **Bit 3 (decimal) (`$08` hex):** Set if any color pixel of value `2` or `3` overlaps another color pixel of value `2` or `3`.

Whenever Port `$08` (hex) is read by the CPU, the hardware automatically resets `INTST` to zero (`$00`), clearing the latch to prepare the chip for the next drawing operation.

---

## 4. How Are Collision Results Dispatched?

To harness this hardware-level collision detection, the VGER Kernel provides standardized drawing primitives that integrate automated intercept checking with Z80 callback pointers. This system is managed by two primary subroutines: `VIWRITE` and `XIWRITE`.

### A. The `VIWRITE` Drawing Primitive

The **`VIWRITE`** subroutine (VWrite with Intercept Checking, located in Block 0148) is VGER's master intercept dispatcher. It executes a strict \"clear-draw-read\" sequence to isolate collisions occurring during a single object's draw phase:

1.  **Register Clear:** The routine executes `in a,(INTST)` to read Port `$08` (hex). This read operation automatically flushes any old collision bits currently latched in the MFG's intercept register, resetting it to a clean state.
2.  **Sprite Render:** It calls the low-level Screen Update Routine **`vwrite`**. `vwrite` programs the blitter to draw the sprite at the coordinates specified by fields `VXL/H` and `VYL/H` using the pattern at `VPATL/H`.
3.  **Collision Read:** Immediately upon return from `vwrite`, the routine reads Port `$08` (hex) again: `in a,(INTST)`.
4.  **Callback Verification:** If the accumulator register `A` is non-zero (indicating a hardware collision occurred during the blit), the routine checks if the active task `IX` has registered a custom collision handler address in its **`VIRL/VIRH`** fields (offsets 39 and 40 decimal / `$27–$28` hex in the Task Header Block).
5.  **Asynchronous Execution:** If `VIRL/VIRH` is non-zero, VGER executes an **asynchronous context jump**: it loads the callback address into the Z80 register pair `HL` and executes the register-indirect jump instruction **`jp (hl)`**. This instantly diverts program execution to the task's custom collision handler (such as a bullet explosion sequence), completely bypassing standard linear code execution.

### B. The `XIWRITE` Update Routine

When a dynamic task is scheduled for its frame update, VGER invokes the **`XIWRITE`** subroutine (XOR Update and Write with Intercept Checking, located in Block 0159). This routine coordinates the entire lifecycle of a moving, colliding entity in a single interrupt-safe pass:

1.  **Physics Integration:** Calls `TBCALC` to calculate frame delta-scaling and decrement the task's timers. It then calls `VECTLC` to update the horizontal and vertical screen coordinates using current velocity and acceleration vectors, checking boundary limits to despawn the object if it travels off-screen.
2.  **Erase Phase:** Checks the status mask `PQS`. If the object is active, it calls the **`verase`** routine, which programs the Pattern Board to erase the sprite from its previous VRAM address (`VSAL/VSAH`) using high-speed XOR blitting.
3.  **Animation Step:** Calls `aup` to advance the task's animation frame pointer based on current program state tables.
4.  **Collision-Safe Render:** Calls the `VIWRITE` primitive to draw the newly updated animation frame to VRAM and evaluate immediate pixel overlaps.
5.  **Task Expiration Check:** Calls the `KILLOFF` handler. If the task's master timer or custom collision routine has flagged the object for deletion, `KILLOFF` unlinks the task from the circular queue and returns the 64-byte node back to the `FREELIST` pool.

---

## 5. Collision and Intercept Reference Listings

The following fully annotated, strictly aligned disassemblies illustrate the exact Z80 assembly implementations of VGER's collision and intercept subsystems.

### A. CHECKVEC (Block 0159)
### Implementation Reference

The following listing is the low-level implementation of the AABB test described above.


Evaluates Axis-Aligned Bounding Box (AABB) intersection between two Vector Objects.
```assembly
;=========================================================================================
; ----> CHECKVEC         EVALUATE SOFTWARE COLLISION BETWEEN TWO NODES    (Block 0159)
;   Inputs:  IX = Source Task Address (Object X)
;            IY = Candidate Target Task Address (Object Y)
;   Outputs: Accumulator A = 1 and Zero Flag Cleared (NZ) if collision detected.
;            Accumulator A = 0 and Zero Flag Set (Z) if no collision.
;=========================================================================================
CHECKVEC:   bit     7,(iy+0)                ; Test target's run/halt status (PQS bit 7)
            jr      z,_CHECKVEC_NO_INT      ; If target is halted (dead), exit with no hit

            bit     5,(iy+0)                ; Test target's draw bypass flag (PQS bit 5)
            jr      nz,_CHECKVEC_NO_INT     ; If target is not drawn, exit with no hit

            ; --- Extract dimensions of Source Task IX ---
            ld      l,(ix+29)               ; HL = IX Pattern ROM Address (VPATL LSB)
            ld      h,(ix+30)               ; HL = IX Pattern ROM Address (VPATH MSB)
            ld      c,(hl)                  ; C  = Width of IX in bytes (first header byte)
            inc     hl                      ; Advance to second header byte
            ld      e,(hl)                  ; E  = Height of IX in lines

            ; --- Extract dimensions of Target Task IY ---
            ld      l,(iy+29)               ; HL = IY Pattern ROM Address (VPATL LSB)
            ld      h,(iy+30)               ; HL = IY Pattern ROM Address (VPATH MSB)
            ld      b,(hl)                  ; B  = Width of IY in bytes
            inc     hl                      ; Advance to second header byte
            ld      d,(hl)                  ; D  = Height of IY in lines

            ; --- Evaluate vertical (Y) overlap ---
            ld      a,(ix+20)               ; A  = VYH of IX (integer part of Y coordinate)
            sub     (iy+20)                 ; A  = VYH of IX - VYH of IY
            jr      nc,_CHECKVEC_Y_POS      ; Branch if IX Y >= IY Y (positive delta)

            ; Case: IX Y < IY Y (Y delta is negative)
            add     a,e                     ; Add IX height (E) to negative vertical delta
            jr      m,_CHECKVEC_NO_INT      ; If still negative, IY is above IX boundaries; exit
            jr      _CHECKVEC_X_EVAL        ; Vertical overlap confirmed; proceed to X evaluation

_CHECKVEC_Y_POS:
            ; Case: IX Y >= IY Y (Y delta is positive)
            cp      d                       ; Compare vertical delta with IY height (D)
            jr      nc,_CHECKVEC_NO_INT     ; If delta >= IY height, IY is below IX; exit

_CHECKVEC_X_EVAL:
            ; --- Evaluate horizontal (X) overlap ---
            ld      a,(ix+14)               ; A  = VXH of IX (integer part of X coordinate)
            sub     (iy+14)                 ; A  = VXH of IX - VXH of IY
            jr      nc,_CHECKVEC_X_POS      ; Branch if IX X >= IY X (positive delta)

            ; Case: IX X < IY X (X delta is negative)
            add     a,c                     ; Add IX width (C) to negative horizontal delta
            jr      m,_CHECKVEC_NO_INT      ; If still negative, IY is to the right; exit
            jr      _CHECKVEC_HIT           ; Overlap confirmed on both axes; we have a hit!

_CHECKVEC_X_POS:
            ; Case: IX X >= IY X (X delta is positive)
            cp      b                       ; Compare horizontal delta with IY width (B)
            jr      nc,_CHECKVEC_NO_INT     ; If delta >= IY width, IY is to the left; exit

_CHECKVEC_HIT:
            ld      a,1                     ; Load hit status flag
            and     a                       ; Perform logical AND to clear Zero Flag (NZ)
            ret                             ; Return collision status

_CHECKVEC_NO_INT:
            xor     a                       ; Clear A and set Zero Flag (Z)
            ret                             ; Return no-collision status
```

### B. CHECKALL (Block 0160)
Sweeps the active task queue, applying category filters to evaluate potential collisions with task `IX`.
```assembly
;=========================================================================================
; ----> CHECKALL         SWEEP ACTIVE QUEUE FOR Target INTERCEPTS         (Block 0160)
;   Inputs:  IX = Active Task Address (ME)
;            C  = Identity Mask Byte (filter criteria)
;   Outputs: NZ status and IY pointing to collided target if hit detected.
;            Z status if no collision found.
;=========================================================================================
CHECKALL:   ld      hl,(vqhead)             ; Load address of first task from queue head

_CHECKALL_LOOP:
            ; --- Self-Collision Check ---
            push    ix                      ; Push active task address onto Z80 stack
            pop     de                      ; Pop into DE (DE = ME)
            ld      a,h                     ; Compare high byte of candidate (HL)
            cp      d                       ;   with our task (DE)
            jr      nz,_CHECKALL_NOT_ME     ; If not matching, candidate is different
            ld      a,l                     ; Compare low byte of candidate (HL)
            cp      e                       ;   with our task (DE)
            ret     z                       ; If HL == DE, we cycled back to ourselves; exit (Z)

_CHECKALL_NOT_ME:
            push    hl                      ; Push candidate address HL
            pop     iy                      ; Pop into target index register IY (IY = target)

            ; --- Identity Mask Filtering ---
            ld      a,(iy+45)               ; Load candidate identity byte (VIDENT offset 45)
            and     c                       ; Apply filter mask passed in register C
            jr      z,_CHECKALL_NOT_HIM     ; If no matching bits, candidate is ignored; skip

            ; --- Evaluate Collision ---
            push    bc                      ; Save mask register BC
            call    CHECKVEC                ; Evaluate bounding boxes of IX and IY
            pop     bc                      ; Restore mask register BC
            ret     nz                      ; If collision detected, return immediately (NZ, IY=culprit)

_CHECKALL_NOT_HIM:
            ; --- Advance to Next Task ---
            ld      l,(iy+1)                ; L = Target's Forward Link LSB (PQFL offset 1)
            ld      h,(iy+2)                ; H = Target's Forward Link MSB (PQFH offset 2)
            jr      _CHECKALL_LOOP          ; Loop back to evaluate next candidate
```

### C. VIWRITE (Block 0148)
Hardware-level pixel-perfect draw-and-check primitive.
```assembly
;=========================================================================================
; ----> VIWRITE          VWRITE SPRITE WITH HARDWARE INTERCEPT CHECK      (Block 0148)
;   Inputs:  IX = Active Task Address
;   Outputs: Triggers asynchronous callback VIRL/H if pixel overlap occurs.
;=========================================================================================
VIWRITE:    in      a,(Port_08)             ; Read hardware Port $08 to clear intercept latch
            call    vwrite                  ; Invoke blitter to draw the sprite to VRAM
            in      a,(Port_08)             ; Read Intercept Feedback Register post-draw
            and     a                       ; Check if any intercept bits are set
            ret     z                       ; If zero, no pixel intersection occurred; exit

            ; --- Collision latch detected: Retrieve Callback ---
            ld      l,(ix+39)               ; L = Custom Callback Address LSB (VIRL offset 39)
            ld      h,(ix+40)               ; H = Custom Callback Address MSB (VIRH offset 40)
            ld      a,h                     ; Combine bytes to check for null pointer
            or      l                       ;
            ret     z                       ; If callback address is null (0), ignore event; exit

            jp      (hl)                    ; Asynchronously jump directly to Z80 handler!
```

### D. XIWRITE (Block 0149)
Linear update loop integrating trajectory physics, erase, and draw phases with hardware collision checks.
```assembly
;=========================================================================================
; ----> XIWRITE          XOR WRITE TASK UPDATE & INTERCEPT DISPATCH       (Block 0149)
;   Inputs:  IX = Active Task Address
;=========================================================================================
XIWRITE:    call    TBCALC                  ; Decrement timers and scale frame delta speed
            call    VECTLC                  ; Move task coordinates, checking screen limits

            ; --- Erase Phase ---
            bit     5,(ix+0)                ; Test erase status (PQS bit 5)
            jr      z,_XIWRITE_ERASE        ; If clear, old sprite must be erased
            res     5,(ix+0)                ; Else reset flag for subsequent frame
            jr      _XIWRITE_ANIM           ; Skip erase

_XIWRITE_ERASE:
            call    verase                  ; Erase old sprite from previous screen address

_XIWRITE_ANIM:
            call    aup                     ; Update animation pointer

            ; --- Write & Collision Check Phase ---
            bit     6,(ix+0)                ; Test write status (PQS bit 6)
            jr      z,_XIWRITE_DRAW         ; If clear, new sprite must be written
            res     6,(ix+0)                ; Else reset flag
            set     5,(ix+0)                ; Set erase bypass for next frame
            jr      _XIWRITE_EXIT           ; Skip drawing

_XIWRITE_DRAW:
            call    VIWRITE                 ; Render new sprite and run hardware collision check

_XIWRITE_EXIT:
            jp      KILLOFF                 ; Run deallocation routine if task has expired
```


---

# Chapter VII: Virtual Machines & The Animation Script Interpreter

VGER contains several execution layers rather than one undifferentiated interpreter. Understanding those layers is necessary before reading the animation-script implementation.

This chapter first fixes the relationship among native Z80 code, the TERSE VM, the VGS/VGER vocabulary, and the `ainter` VM. It then follows one animation Task through its private workspace, interpreter loop, opcode dispatch, subroutine calls, native handoffs, and historical script examples.

---

## 1. The Four Execution Layers of the VGER Architecture

To write dependable code for Gorf or Extra Bases, a developer must distinguish between these four co-existing layers:

```text
+-----------------------------------------------------------------------------------+
|  Layer 4: Subordinate Animation Script Interpreter (ainter VM)                     |
|           Runs localized sprite scripts inside individual Task nodes (VPC, VSP).   |
+-----------------------------------------------------------------------------------+
                                         |  Runs within Task Scratchpads
                                         v
+-----------------------------------------------------------------------------------+
|  Layer 3: VGS / VGER Game-Oriented Runtime Vocabulary                              |
|           Verbs for tasks, graphics, physics, and collisions (RELABS, vwrite).    |
+-----------------------------------------------------------------------------------+
                                         |  Implemented as compiled Threaded Words
                                         v
+-----------------------------------------------------------------------------------+
|  Layer 2: TERSE Threaded-Language Interpreter (Forth-Style VM)                     |
|           Main virtual execution engine. BC = IP, SP = Param Stack, IX = Return.  |
+-----------------------------------------------------------------------------------+
                                         |  Dispatched via native routines
                                         v
+-----------------------------------------------------------------------------------+
|  Layer 1: Bare-Metal Z80 Native Machine Code                                      |
|           Low-level assembly primitives and interrupt handlers (getnode, nextq).  |
+-----------------------------------------------------------------------------------+
```

### Layer 1: Bare-Metal Z80 Native Machine Code
At the base of the platform is the native Z80 CPU executing machine instructions directly from ROM. This layer includes the timing-critical scanline interrupt handlers (`TIMINT`, `BGENDI`), the custom blitter register stuffers (`write`), and the high-speed memory-management primitives (`getnode`, `freenode`, `ADDQ`, `nextq`). These routines are written in pure assembly and run at full processor speed.

### Layer 2: The TERSE Threaded-Language Interpreter
The primary execution engine of the game program is the **TERSE Virtual Machine**—an exceptionally compact, Forth-family threaded interpreter. Deployed on games like *Gorf* and *Extra Bases*, the TERSE interpreter hijacks the Z80's registers to drive its virtual execution loop:
*   **Z80 `BC` register** acts as the **TERSE Instruction Pointer (IP)**, pointing to the stream of 16-bit virtual addresses (DTC) or 8-bit tokens (TTC).
*   **Z80 `SP` register** acts as the **TERSE Parameter Stack Pointer (PSP)**, tracking numbers pushed and popped by VM operations.
*   **Z80 `IX` register** acts as the **TERSE Return Stack Pointer (RSP)**, tracking loop boundaries and subroutine return addresses.
*   **Z80 `IY` register** acts as the **Dispatcher Pointer**, pointing to the inner interpreter loop `_DSPATCH`.

When a TERSE program runs, `_DSPATCH` fetches a virtual token or word address from the `BC` stream and jumps through it using Z80 register-indirect instructions, executing high-level game logic inside a tiny memory footprint.

### Layer 3: VGS / VGER Game-Oriented Runtime Vocabulary
Built directly on top of the TERSE VM is the **VGS (Video Game Support) / VGER Vocabulary**. This layer represents a specialized dictionary of compiled threaded words that expose game-oriented actions to the developer. Verbs like `VMOVE`, `VSTART`, `RELABS`, `vwrite`, `verase`, `CHECKVEC`, and `SPEAK` allow developers to spawn screen actors, calculate coordinates, play audio, and execute collision sweeps simply by writing a sequence of high-level virtual instructions.

### Layer 4: The Subordinate Animation Script Interpreter (`ainter`)
The lowest, most specialized layer is the **subordinate Animation Script Interpreter**. Driven by the Z80 native utility routine **`ainter`**, this interpreter is an independent virtual state machine that runs inside the scratchpad memory of individual active Task nodes.

While Layers 2 and 3 manage overall game state, player scores, and entity spawning, Layer 4 focuses entirely on **visual sequencing**. It executes mini macro-scripts that cycle sprite frames, adjust blitter flags, insert frame-rate delays, and execute animation loops. It is a completely separate interpreter with its own Virtual Program Counter (`VPC`) and stack registers, running concurrently across dozens of active Task nodes without interfering with the parent TERSE VM’s stacks or registers.

---

## 2. Where Does Each Task Store Animation State?

To allow dozens of moving entities to animate concurrently at independent rates, VGER isolates each Task's animation parameters. Every standard 64 (decimal) byte Task node allocates exactly 6 (decimal) bytes of its 51-byte (decimal) standardized header to act as a private register file for the subordinate Animation Interpreter:

```text
       Task Node RAM offsets $21 to $26 (hexadecimal)
+-----------------------------------------------------------------+
| Offset (Dec) | Offset (Hex) | Variable | Description            |
+--------------+--------------+----------+------------------------+
|    33–34     |   $21–$22    |  VPCL/H  | Virtual Program Counter|
|    35–36     |   $23–$24    |  VSPL/H  | Virtual Stack Pointer  |
|    37–38     |   $25–$26    | VPTBL/H  | Pattern Table Pointer  |
+-----------------------------------------------------------------+
```

*   **Virtual Program Counter (VPC) (`VPCL/VPCH`):** A 16-bit pointer storing the Task's current execution location inside its compiled animation script in ROM.
*   **Virtual Stack Pointer (VSP) (`VSPL/VSPH`):** A 16-bit pointer tracking the base of the Task's private return stack. This is mapped into the scratchpad area of the Task node (starting at `VASTKS` offset 50 decimal / `$32` hex) to support animation subroutines and nested loops.
*   **Animation Pattern Table Pointer (`VPTBL/VPTBH`):** A 16-bit address pointing to the base array of sprite frame offsets stored in ROM, allowing index-based frame swaps.

---

## 3. How Does `ainter` Execute a Script?

The execution engine driving Layer 4 is the native Z80 subroutine **`ainter`** (located in Block 0145). During every 60Hz scanline pass (specifically during the Scanline 200 `TRYFOREGROUND` scheduler sweep), VGER advances through active Task nodes and calls `ainter` to process their visual frames.

To prevent animation calculations from stalling critical rendering windows, `ainter` is designed with an extremely fast, low-overhead execution loop. It employs a clever **loop re-entry stack trick** to execute multiple non-blocking opcodes in a single frame, immediately returning control back to the scheduler only when a wait command (`RAWAIT`) or a halt command (`RAHALT`) is encountered.

```assembly
;=========================================================================================
; ----> ainter           ANIMATION SCRIPT INTERPRETER LOOP             (Block 0145)
;   Processes macro-animation script opcodes for the active task (IX).
;   Input:   IX = Base address of active task node in RAM
;   Output:  Altered registers: A, B, C, D, E, H, L, IY
;=========================================================================================
_ainter:    ld      a,(ix+$0A)              ; Read VATMR (Animation Timer, offset 10 dec)
            or      a                       ; Check if wait timer is active (non-zero)
            ret     nz                      ; If VATMR > 0, task is waiting; exit interpreter

            ld      l,(ix+$21)              ; Read VPCL (VPC Low, offset 33 dec)
            ld      h,(ix+$22)              ; Read VPCH (VPC High, offset 34 dec)

_ainet_loop:
            ld      de,_ainet_loop          ; Load loop re-entry label address
            push    de                      ; Push to Z80 CPU stack as the return target

            ld      c,(hl)                  ; Fetch 8-bit opcode byte from script VPC
            inc     hl                      ; Advance Virtual PC past opcode byte
            ld      b,$00                   ; Clear B to convert opcode to a 16-bit index

            ex      de,hl                   ; Swap script VPC into DE; restore loop label to HL
            ld      hl,AJTBL                ; Load base address of Opcode Jump Table
            add     hl,bc                   ; Calculate target offset in jump table

            ld      c,(hl)                  ; Read target handler LSB
            inc     hl                      ;
            ld      b,(hl)                  ; Read target handler MSB

            ex      de,hl                   ; Restore script VPC to HL
            push    bc                      ; Push target handler address onto CPU stack
            ret                             ; JUMP TO HANDER via Z80 RET dispatch!
```

### The Re-entry Stack Trick and Non-Blocking Opcodes
1.  **Re-entry Setup:** Before fetching each opcode, the loop pushes its own start address (`_ainet_loop`) onto the physical Z80 stack (`push de`).
2.  **RET Dispatching:** It fetches the target address of the opcode handler from the jump table into `BC`, pushes it onto the stack, and executes `ret`. This transfers execution directly to the handler's bare-metal Z80 code.
3.  **Fast Return:** Standard, non-blocking handlers (such as setting coordinates or updating pattern indexes) perform their task and terminate with a simple Z80 `ret` instruction. Because `_ainet_loop` sits at the top of the stack, the handler returns straight back to the interpreter to process the next instruction in the script on the same 60Hz frame pass.
4.  **Wait Suspension (`RAWAIT` / Block 0140):** When a script hits a wait command (`SWAIT` / `RAWAIT`), the interpreter must freeze execution of this task for a specified duration. To break out of the infinite processing loop, the `RAWAIT` handler performs a **double-pop breakout**:

```assembly
;=========================================================================================
; ----> RAWAIT           ANIMATION WAIT OPCODE HANDLER                  (Block 0140)
;   Saves current VPC and terminates interpreter pass to enforce frame delays.
;=========================================================================================
RAWAIT:     ld      a,(hl)                  ; Read wait duration byte from script argument
            inc     hl                      ; Advance Virtual PC past argument
            ld      (ix+$0A),a              ; Write duration into task's active VATMR register

            ld      (ix+$21),l              ; Save updated VPCL back to task header
            ld      (ix+$22),h              ; Save updated VPCH back to task header

            pop     hl                      ; DISCARD loop return address (_ainet_loop) off stack!
            ret                             ; Return now exits the entire interpreter pass!
```

By popping and discarding `_ainet_loop` from the CPU stack, the final `ret` instruction returns directly to VGER's master scheduler, suspending the script's execution at that exact VPC until `VATMR` decrements back to zero.

---

## 4. How Are Animation Opcodes Dispatched?

The Animation Interpreter Jump Table (**`AJTBL`**) maps 24 (decimal) standardized Virtual Machine verbs. Each entry is a 16-bit Z80 ROM pointer containing the target address of the compiled assembly handler:

| Opcode Index (Dec) | Macro Verb | Assembly Handler | System Action & VM Semantics |
| :---: | :--- | :--- | :--- |
| **0** | `SETP` | `RASETP` | Sets the task's 16-bit ROM pattern pointer (`VPATL/H`, offsets 29-30 dec). |
| **2** | `SETM` | `RASETM` | Sets the task's blitter magic properties register (`VMAGIC`, offset 27 dec). |
| **4** | `SETR` | `RASETR` | Overwrites the task's native routine pointer (`PQRL/H`, offsets 5-6 dec). |
| **6** | `SWAIT` | `RAWAIT` | Sets `VATMR` (offset 10 dec) and suspends `ainter` execution. |
| **8** | `ACALL` | `RACALL` | Pushes current VPC onto `VSPL/H` (offsets 35-36 dec) and branches. |
| **10** | `AJMP` | `RAJMP` | Jumps unconditionally to a new 16-bit script address. |
| **12** | `SETDC` | `RASETDC` | Loads horizontal and vertical velocity values into `VDXL/H` & `VDYL/H`. |
| **14** | `SETDDC` | `RASETDDC` | Loads horizontal and vertical acceleration values into `VDDXL/H` & `VDDYL/H`. |
| **16** | `ARET` | `RARET` | Pops return VPC from `VSPL/H` to return from script subroutine. |
| **18** | `AHALT` | `RAHALT` | Clears the `PQSRH` task run flag (bit 7 offset 0), stopping execution. |
| **20** | `SETI` | `RASETI` | Loads a custom collision intercept routine pointer into `VIRL/H`. |
| **22** | `SETXC` | `RASETXC` | Overwrites the task's horizontal position registers (`VXL/H`, offsets 13-14 dec). |
| **24** | `SETYC` | `RASETYC` | Overwrites the task's vertical position registers (`VYL/H`, offsets 19-20 dec). |
| **26** | `DISPL` | `RADISP` | Displaces the current coordinates relatively by signed values. |
| **28** | `AREPEAT` | `RASETREP` | Pushes a repeat loop counter onto the task's local stack (`VSPL/H`). |
| **30** | `ALOOP` | `RALOOP` | Decrements loop counter; loops back to target address if non-zero. |
| **32** | `SETS` | `RASETS` | Alters individual bits in the task status byte (`PQS` offset 0 dec). |
| **34** | `PATI` | `RAPATI` | Automatically indexes a pattern from the current pattern table `VPTBL/H`. |
| **36** | `ASMCALL` | `RASMCALL` | Calls a native Z80 machine code subroutine, returning control back to VPC. |
| **38** | `SETPT` | `RASETPT` | Sets the base address of the task's pattern table (`VPTBL/H`, offsets 37-38 dec). |
| **40** | `SETFP` | `RASETFP` | Sets the final pattern pointer (`VFNLPL/H`) to display upon execution halt. |
| **42** | `SETXZW` | `RASETXZW` | Overwrites the collision exclusion zone width (`VXZW` offset 8 dec). |
| **44** | `RANDOMDO` | `RARANDOMDO` | Evaluates 8-bit RNG value; branches to target if condition met. |
| **46** | `SETXP` | `RASETXP` | Loads the blitter palette color expansion register (`VXPAND` offset 28 dec). |

---

## 5. How Do Animation Scripts Call and Return?

The subordinate Animation Interpreter supports modular subroutine nesting and machine-code callbacks:

### A. Subroutine Calls (`RACALL` & `RARET` / Block 0140)
To avoid duplicating animation code (such as compiling separate explosion sequences for every alien variant), `ainter` supports script subroutines. `RACALL` reads the 16-bit target address from the script, pushes the current `VPC` onto the task's private virtual stack pointer `VSPL/H`, and branches:

```assembly
;=========================================================================================
; ----> RACALL           CALL SCRIPT SUBROUTINE                        (Block 0140)
;   Pushes current VPC onto the task's virtual stack and branches to target address.
;   Input:   HL = Virtual PC (VPC) pointer inside script ROM
;            IX = Active task node address
;=========================================================================================
_RACALL:    ld      c,(hl)                  ; Read target address LSB from script
            inc     hl                      ;
            ld      b,(hl)                  ; Read target address MSB from script
            inc     hl                      ; HL now points to the subsequent script opcode

            ex      de,hl                   ; DE = Return VPC address
            ld      l,(ix+$23)              ; Read VSPL (Virtual Stack Pointer L, offset 35 dec)
            ld      h,(ix+$24)              ; Read VSPH (Virtual Stack Pointer H, offset 36 dec)

            ld      (hl),e                  ; Write return address LSB onto virtual stack
            inc     hl                      ;
            ld      (hl),d                  ; Write return address MSB onto virtual stack
            inc     hl                      ; Advance Virtual Stack Pointer

            ld      (ix+$23),l              ; Save updated Virtual Stack Pointer L LSB back to node
            ld      (ix+$24),h              ; Save updated Virtual Stack Pointer H MSB back to node

            ld      l,c                     ; Load target address LSB into HL
            ld      h,b                     ; Load target address MSB into HL
            ret                             ; Return back to interpreter loop
```

The matching **`RARET`** routine (Block 0140) reverses this sequence, decrementing the Task's `VSPL/H` pointers by 2 (decimal), pulling the 16-bit return address off the stack, and restoring it to the `VPC` (`HL` register).

### B. Bare-Metal Machine Handoffs (`RASMCALL` / Block 0143)
If an animation script needs to perform advanced physical coordinates tracking, trigger screen-shaking, or check complex game rules, it uses the **`RASMCALL` (Animation Machine Call)** command. `RASMCALL` exits the interpreter to run native Z80 machine code, while safely retaining the script's return address:

```assembly
;=========================================================================================
; ----> RASMCALL         EXECUTE NATIVE MACHINE CODE CALLBACK          (Block 0143)
;   Jumps directly to native assembly from within an animation script.
;   Input:   HL = Virtual PC (VPC) pointer
;=========================================================================================
_RASMCALL:  ld      e,(hl)                  ; Read target machine address LSB
            inc     hl                      ;
            ld      d,(hl)                  ; Read target machine address MSB
            inc     hl                      ; HL now points to script return VPC

            push    hl                      ; Push script return VPC onto native CPU stack
            push    de                      ; Push target machine address onto native stack
            ret                             ; JUMP TO NATIVE ASSEMBLY via ret!
```

---

## 6. What Do Real Animation Scripts Look Like?

These compiled ROM binaries demonstrate how the Animation Interpreter vocabulary was utilized in classic game design:

### Example A: Standard Explosion Subroutine (`EXPISUB` / Gorf Block 0109)
### Concrete Example

The abstract interpreter becomes easier to follow when its commands are viewed as an actual compiled script. The following example shows that relationship.


This shared subroutine cycles through 5 (decimal) explosion animation frames, displaying each frame for 5 (decimal) vertical blank interrupts before clearing the graphic and returning:

```text
Compiled VM Script Bytes in ROM (Address $132C hex):
+---------------------------------------------------------------------------------+
| Offset | Raw Bytes (Hex) | Disassembled Macro / Action                          |
+--------+-----------------+------------------------------------------------------+
| $132C  | 00 1E 22        | SETP  EXPLOSION1_ADDR   ; Load first frame           |
| $132F  | 06 05           | SWAIT 5                 ; Display for 5 ticks        |
| $1331  | 00 22 22        | SETP  EXPLOSION2_ADDR   ; Load second frame          |
| $1334  | 06 05           | SWAIT 5                 ; Display for 5 ticks        |
| $1336  | 00 26 22        | SETP  EXPLOSION3_ADDR   ; Load third frame           |
| $1339  | 06 05           | SWAIT 5                 ; Display for 5 ticks        |
| $133B  | 00 2A 22        | SETP  EXPLOSION4_ADDR   ; Load fourth frame          |
| $133E  | 06 05           | SWAIT 5                 ; Display for 5 ticks        |
| $1340  | 00 2E 22        | SETP  EXPLOSION5_ADDR   ; Load fifth frame           |
| $1343  | 06 05           | SWAIT 5                 ; Display for 5 ticks        |
| $1345  | 00 32 22        | SETP  NULPAT_ADDR       ; Clear visual graphics      |
| $1348  | 16              | ARET                    ; Return to parent script    |
+---------------------------------------------------------------------------------+
```

### Example B: Character Dive-Roll & Flip-Over Script (`FLIPOVER` / Gorf Block 0244)
This script performs a complex acrobatic dive-roll. It rotates the sprite 180 degrees by writing directly to `VMAGIC` (`SETM`), steps index-by-index through a pattern frame table (`PATI`), and restores normal orientation before returning:

```text
Compiled VM Script Bytes in ROM (Address $2034 hex):
+---------------------------------------------------------------------------------+
| Offset | Raw Bytes (Hex) | Disassembled Macro / Action                          |
+--------+-----------------+------------------------------------------------------+
| $2034  | 02 A0           | SETM  $A0               ; Magic: Enable Flip/Flop XOR|
| $2036  | 34 00           | PATI  0                 ; Show pattern index 0       |
| $2038  | 06 02           | SWAIT 2                 ; Display for 2 ticks        |
| $203A  | 34 02           | PATI  2                 ; Show pattern index 2       |
| $203C  | 06 02           | SWAIT 2                 ; Display for 2 ticks        |
| $203E  | 34 04           | PATI  4                 ; Show pattern index 4       |
| $2040  | 06 02           | SWAIT 2                 ; Display for 2 ticks        |
| $2042  | 34 06           | PATI  6                 ; Show pattern index 6       |
| $2044  | 06 02           | SWAIT 2                 ; Display for 2 ticks        |
| $2046  | 34 08           | PATI  8                 ; Show pattern index 8       |
| $2048  | 06 02           | SWAIT 2                 ; Display for 2 ticks        |
| $204A  | 02 20           | SETM  $20               ; Magic: Restore normal XOR  |
| $204C  | 34 06           | PATI  6                 ; Scale back through table   |
| $204E  | 06 02           | SWAIT 2                 ; Display for 2 ticks        |
| $2050  | 34 04           | PATI  4                 ; ...                        |
| $2052  | 06 02           | SWAIT 2                 ; Display for 2 ticks        |
| $2053  | 34 02           | PATI  2                 ; ...                        |
| $2055  | 06 02           | SWAIT 2                 ; Display for 2 ticks        |
| $2057  | 34 00           | PATI  0                 ; Show original starting frame|
| $2059  | 06 04           | SWAIT 4                 ; Settle for 4 frames        |
| $205C  | 16              | ARET                    ; Subroutine complete        |
+---------------------------------------------------------------------------------+
```

---

# Chapter VIII: Co-Processing Audio, Music, & Speech (MUSCPU)

## 1. Dual Custom I/O Sound Subsystem

Audio is another subsystem that VGER keeps separate from ordinary foreground game logic. This chapter follows the sound path from the two custom I/O chips through the background music engine, score parser, stereo panning, and Votrax speech interface.

The same teaching pattern used elsewhere applies here: understand the subsystem's role first, then examine its buffers, commands, registers, and assembly routines.

*   **Chip 1 (Ports `$10 – $17` hex / 16 to 23 decimal):** Mapped as the primary or "Upper/Left" sound generator.
*   **Chip 2 (Ports `$50 – $57` hex / 80 to 87 decimal):** Mapped as the secondary or "Lower/Right" sound generator.

The physical control interface of each Astrocade "IO" chip consists of 8 (decimal) write-only hardware registers, mapped directly to Z80 output ports relative to a base `SOUNDBOX` port variable:

| Register (Dec) | Port Offset (Hex) | Control Parameter / Hardware Function |
| :---: | :---: | :--- |
| **Reg 0** | `+$00` | **Master Oscillator Frequency:** Sets the master clock divider for the noise and vibrato circuits. |
| **Reg 1** | `+$01` | **Tone Generator A Frequency:** Sets the 8-bit frequency divider for square wave Channel A. |
| **Reg 2** | `+$02` | **Tone Generator B Frequency:** Sets the 8-bit frequency divider for square wave Channel B. |
| **Reg 3** | `+$03` | **Tone Generator C Frequency:** Sets the 8-bit frequency divider for square wave Channel C. |
| **Reg 4** | `+$04` | **Vibrato Controls:** Bits 6–7 set the Vibrato Speed; Bits 0–5 set the Vibrato Depth. |
| **Reg 5** | `+$05` | **Noise AM & Volume C:** Bit 5 enables Noise AM; Bit 4 sets the Modulator Multiplexer source (0 = Vibrato, 1 = Noise); Bits 0–3 set Tone C Volume. |
| **Reg 6** | `+$06` | **Tone Volumes A & B:** Bits 4–7 set Tone B Volume; Bits 0–3 set Tone A Volume. |
| **Reg 7** | `+$07` | **Noise Volume:** Sets the 8-bit output volume of the pseudorandom noise generator. |

---

## 2. How Does Background Audio Processing Work?

To guarantee glitch-free musical accompaniment and sound effects during intense gameplay, VGER decouples the audio script interpreter from high-level playaction code. The audio engine executes concurrently within VGER's interrupt and background slices:

1.  **Low-Level Port Output (`portout`):** The engine relies on a strictly guarded assembly utility to write data to the Astrocade hardware registers. This routine performs strict bounds checks, ensuring all destination ports fall strictly within the `$10–$17` (hex) / 16 to 23 (decimal) boundary before transforming Port variables relative to the active `SOUNDBOX` offset:

```assembly
;=========================================================================================
; ----> portout          OUTPUT DATA BYTE TO HARDWARE CHIP REGISTERS     (Block 0070)
;   Inputs:  A = Data value to output, C = Target Z80 I/O port address
;   Outputs: None (Destroys A, E, C registers)
;=========================================================================================
portout:    ld      e,a                     ; E = Save data byte to write
            ld      a,$17                   ; Mapped maximum custom port boundary
            cp      c                       ; Compare target port C with $17 hex
            jp      m,_portout_exit         ; If C > $17, jump to exit (illegal write)

            sub     $08                     ; Subtract 8 (decimal) to find minimum bound
            cp      c                       ; Compare target port C with $0F hex ($17 - $08)
            jp      p,_portout_exit         ; If C <= $0F, jump to exit (illegal write)

            ld      a,$18                   ; Select register select boundary ($18 hex)
            sub     c                       ; C represents offset relative to select port
            sub     (iy+$04)                ; Subtract active channel SOUNDBOX base offset (offset 4)
            neg                             ; Negate to calculate relative write offset
            ld      c,a                     ; Load absolute Z80 port register back into C
            out     (c),e                   ; Fire the byte directly to the hardware chip!

_portout_exit:
            xor     a                       ; Clear accumulator and flags
            ret                             ; Return safely
```

2.  **Sound Track Buffers (`MUSIC-BARRAY-1` and `-2`):** Rather than spawning active, high-overhead tasks in VGER's doubly linked circular queue, the audio engine allocates 2 (decimal) dedicated, static channel buffers in off-screen workspace RAM. Sound data is updated via `MUSCPUS` during the line 100 or 200 `TIMINT` interrupt, and algorithmic sequences are generated via `busaround` during the line 50 `BGENDI` background slice.

The active channel parameters are addressed using positive offsets relative to the **`IY` register**, which is dynamically loaded with the address of the target channel buffer during execution. Offsets within the music channel buffer are organized into functional groups:

*   **Timebase-Mover Offsets (Offsets `$15 – $18` hex / 21 to 24 decimal):** Regulate tempo shifts and duration tracking (`STOPTB`, `TBSTEP`, `TBTB`, `TBTIMER`).
*   **Noise-Mover Offsets (Offsets `$19 – $1D` hex / 25 to 29 decimal):** Regulate sweeps of pseudorandom noise frequencies (`NOSTOP`, `NOSTEP`, `NOTIMER`, `NOTIMEBASE`, `NOVALUE`).
*   **Step-Mover Offsets (Offsets `$1E – $21` hex / 30 to 33 decimal):** Track microtonal pitch slides and tone steps (`STOPSTEPS`, `BIGOFASTEP`, `STEPTIMEBASE`, `STEPTIMER`).
*   **Stereo Panning Offsets (Offsets `$22 – $25` hex / 34 to 37 decimal):** Control left-channel and right-channel stereo imaging (`LEFTPAN`, `PANSTEP`, `PANTIMEBASE`, `PANTIMER`, `PANCOUNTER`).
*   **State Envelopes (Offsets `$26 – $2A` hex / 38 to 42 decimal):** Dynamic volume levels (`VOLHIGHLIM`, `VOLOWLIM`, `VOLSTEP`, `VOLTIMEBASE`, `VOLTIMER`).
*   **Interpreter Trackers (Offsets `$2B – $2F` hex / 43 to 47 decimal):** Track state transitions (`MCTRACKER`, `SYNCMO`, `STARTMC`, `NOTETIMER`, and `MST` Music State Transition offset at `$2F` hex).

---

## 3. How Are Music Commands Encoded and Parsed?

VGER parses compiled musical scores from ROM using a compact set of tokenized operation codes. When the engine processes a score block via `process`, it decodes the opcode byte against a master jump table (`OPADDRESSES`) containing 27 (decimal) standardized actions:

```assembly
;=========================================================================================
; ----> OPADDRESSES      MUSIC ENGINE COMMAND VERB INTERRUPT JUMP TABLE  (Block 0079)
;=========================================================================================
OPADDRESSES:
            DW      _RANDOMNOTES            ; Opcode $00: Output random noise pitches
            DW      _LOADTIMER              ; Opcode $01: Set note timer / gate duration
            DW      _CONTJUMP               ; Opcode $02: Unconditional score branch (Seek)
            DW      _QUITJUMP               ; Opcode $03: Loop branch breakpoint check
            DW      _QUITYET                ; Opcode $04: Stop / quiet current track
            DW      _RAMBLIN                ; Opcode $05: Initialize frequency ramble envelope
            DW      _RAMPIN                 ; Opcode $06: Initialize linear frequency ramp
            DW      _MUSICIN                ; Opcode $07: Enable algorithmic music generator
            DW      _RAMBLE_ON              ; Opcode $08: Force ramble active
            DW      _RAMBLE_OFF             ; Opcode $09: Bypass ramble active
            DW      _LIMITRAMBLE            ; Opcode $0A: Trigger ramble limits
            DW      _STEPMOVIN              ; Opcode $0B: Trigger step-mover envelope
            DW      _LOWMOVIN               ; Opcode $0C: Start low-frequency limit envelope
            DW      _HIGHMOVIN              ; Opcode $0D: Start high-frequency limit envelope
            DW      _TBMOVIN                ; Opcode $0E: Start timebase-tempo sweep
            DW      _NOMOVIN                ; Opcode $0F: Start noise frequency sweep
            DW      _MASTART                ; Opcode $10: Set Master Oscillator register
            DW      _OPPORT                 ; Opcode $11: Output to Register 1 (Tone A)
            DW      _OPPORT                 ; Opcode $12: Output to Register 2 (Tone B)
            DW      _OPPORT                 ; Opcode $13: Output to Register 3 (Tone C)
            DW      _OPPORT                 ; Opcode $14: Output to Register 4 (Vibrato)
            DW      _MCMOVIN                ; Opcode $15: Output to Register 5 (AM Mux)
            DW      _ABVOLIN                ; Opcode $16: Output to Register 6 (A/B Volume)
            DW      _NOISEPORT              ; Opcode $17: Output to Register 7 (Noise Vol)
            DW      _SOUNDMOVIN             ; Opcode $18: Dynamic stereo pan sweep
            DW      _PANLIMITCOUNTIN        ; Opcode $19: Count stereo pan steps
            DW      _VOLMOVIN               ; Opcode $1A: Vol envelope sweep trigger
            DW      _MOHITTIN               ; Opcode $1B: Thumper drum effect trigger
```

Score execution operates via a virtual instruction pointer (**`MUSPC`**) stored in the track's channel buffer. Below is a sample VGER assembly file compiling a dual-channel attract mode sound effect (from Gorf's *COINSOUND1* and *COINSOUND2* sequence):

```assembly
;=========================================================================================
; ----> COINSOUND1       COIN INSERT SOUND SCORE BLOCK                   (Block 0109)
;=========================================================================================
COINSOUND1: DB      $14, $86, $10, $10      ; Set Master Osc ($14 hex) and Vibrato
            DB      $06, $10                ; Select tone ramp speeds
            DB      $3C, $01                ; Output TONES notes (#G1, #E1, #C2)
            DB      $03, $13                ; Set tone volumes A/B/C
            DB      $5E, $12                ; Gate duration / volume fades
            DB      $96, $11                ; Output noise volumes
            DB      $7E, $16                ; Set master envelope thresholds
            DB      $FF, $15, $0F, $01      ; Loop back checks
            DB      $40, $04                ; Break out to QUIET command
```

---

## 4. How Is Stereo Panning Calculated?

To create an immersive spatial perspective on cabinets equipped with dual-speakers, VGER features a high-speed **Trigonometric Volume Panning subsystem**. Volume panning balances are governed by the 64 (decimal) byte **`sin-table`**, which maps a quarter-quadrant of a sine wave scaled to maximum amplitude bounds (`$00` to `$FF` hex / 0 to 255 decimal) across 64 (decimal) distinct positions:

```assembly
;=========================================================================================
; ----> sin_table        64-BYTE SINE WAVE LOOKUP ARRAY                  (Block 0069)
;=========================================================================================
sin_table:  DB      $FF, $FF, $FF, $FF, $FE, $FD, $FC, $FB, $FA, $F8, $F7, $F5, $F3, $F1, $EF, $ED
            DB      $EA, $E7, $E5, $E2, $DF, $DC, $D8, $D5, $D1, $CE, $CA, $C6, $C2, $BE, $B9, $B5
            DB      $B1, $AC, $A7, $A2, $9D, $98, $93, $8E, $89, $84, $7E, $79, $73, $6D, $68, $62
            DB      $5C, $56, $50, $4A, $44, $3E, $38, $32, $2C, $26, $1F, $19, $13, $0D, $06, $00
```

When a panning envelope moves, `MUSCPU` tracks the active speaker position index (0 to 63 decimal) in `LEFTPAN` (offset `$22` hex). It then calls the `sin` subroutine to retrieve the balanced left-channel volume and calculates the matching right-channel volume using inverted coordinates:

$$\text{Vol}_{\text{Left}} = \text{sin\_table}[\text{index}]$$

$$\text{Vol}_{\text{Right}} = \text{sin\_table}[63 - \text{index}]$$

```assembly
;=========================================================================================
; ----> sin              SINE LOOKUP MATH SUBROUTINE                     (Block 0069)
;   Inputs:  E = Pan index (0 to 63 decimal)
;   Outputs: A = Sine wave scale factor (0 to 255 decimal)
;=========================================================================================
sin:        ld      d,$00                   ; Clear high-order offset register
            ld      hl,sin_table            ; HL = Pointer to sine wave table start
            add     hl,de                   ; HL = Target index address
            ld      a,(hl)                  ; Read sine value directly
            ret                             ; Done!
```

---

## 5. How Is Speech Streamed to the Votrax SC-01?

The cabinet's voice is synthesized by a dedicated **Votrax SC-01** phoneme-based speech synthesizer chip. VGER controls the Votrax chip via two primary hardware ports:

*   **`PHONEOUT` (Port `$17` hex / 23 decimal):** The write stuffer port where 6-bit phoneme indices are written to trigger vocalization.
*   **`NEWPHONE` (Port `$12` hex / 18 decimal):** The read request port. When Bit 7 is high, the Votrax chip is ready to receive the next phoneme.

Every spoken sentence is compiled in ROM as a **Talking Primitive**. Primitives are headed by a 1-byte length count followed by sequential, 6-bit phoneme values (`EH3` through `STOP` at `$3F` hex). The low-level interrupt handler **`PHONE`** handles vocalization as an asynchronous background task:

```assembly
;=========================================================================================
; ----> PHONE            ASYNCHRONOUS VOTRAX SPEECH STREAMER            (Block 0102)
;   Slices Z80 cycles during the 60Hz interrupt to stream queued phonemes.
;=========================================================================================
PHONE:      ld      a,(ONHOLD)              ; Read active speech delay timer (ONHOLD)
            or      a                       ; Is speech paused on a timer?
            jr      nz,_phone_timer_tick    ; Yes, decrement timer and exit

            in      a,(NEWPHONE)            ; Read Votrax chip status port ($12 hex)
            bit     7,a                     ; Is the synthesizer ready for a new phoneme?
            ret     z                       ; No, exit and wait for next interrupt tick

            ld      a,(PHONE#)              ; Read active phrase phoneme counter
            or      a                       ; Are we at the end of a speech block?
            jr      nz,_phone_send_next     ; No, jump to send next phoneme byte

            ; --- Load Next Primitive Address from Speech Stack ---
            ld      hl,(TALKIN)             ; HL = Current speech buffer stuffer address
            ld      de,(TALKOUT)            ; DE = Current speech playback address
            or      a                       ; Clear carry
            sbc     hl,de                   ; Compare addresses
            jr      nz,_phone_reload_prim   ; If more phrases queued, load next primitive

            ; --- Speech Buffer Empty: Stop Synthesizer ---
            ld      bc,$3F17                ; BC: C = Port $17 hex; B = $3F (STOP code)
            in      a,(c)                   ; Shut down speech output
            ret                             ; Return

_phone_reload_prim:
            ; (Taps the circular stack, reloads playback pointer into TALKHERE)
            ; (Sets up PHONE# with the new primitive's length byte)
            ret

_phone_send_next:
            dec     a                       ; Decrement active phoneme counter
            ld      (PHONE#),a              ; Store updated phoneme count
            ld      hl,(TALKHERE)           ; HL = Current phoneme address in ROM
            ld      b,(hl)                  ; B = 6-bit phoneme index
            inc     hl                      ; Advance pointer to next phoneme
            ld      c,$17                   ; C = Hardware PHONEOUT port address
            in      a,(c)                   ; Stuff the phoneme directly to Votrax!
            ld      (TALKHERE),hl           ; Save advanced pointer
            ret                             ; Done

_phone_timer_tick:
            dec     a                       ; Decrement delay timer
            ld      (ONHOLD),a              ; Save updated delay back to RAM
            ret                             ; Return
```

---

# Chapter IX: Arcade Case Studies (Extra Bases, Gorf, & Wizard of Wor)

The preceding chapters described VGER as a general system. These case studies show how individual games used that system.

Each example is organized around the hardware configuration first, followed by the game-specific use of VGER memory, physics, sound, speech, threading, or Task links. These examples are where the abstract mechanisms become concrete game behavior.

---

## 1. Extra Bases (1980): The Minimalist Ballistics Platform

*Extra Bases* was designed as a cost-effective cocktail and upright baseball simulation, featuring a highly streamlined cardcage configuration:

```text
Extra Bases Minimalist Cardcage Configuration:
+-----------------------------------------------------------------+
|  Game Logic/IO Board  |     CPU Board     | Dynamic RAM Board   |
|   (A084-90700-D761)   | (A082-91354-0000) | (A082-91356-C000)   |
+-----------------------------------------------------------------+
```

### The Volatile Software Fallback
Unlike later VGER cabinets, *Extra Bases* did not contain an external memory expansion board or battery-backed CMOS static NVRAM. The machine’s entire 16 KB (kilobyte) memory workspace was provided by a single Dynamic RAM (DRAM) Board mapped from `$4000` to `$7FFF` (hex).

Crucially, **the compiled VGER kernel source code remained identical** to other platform games. When saving batting averages, coin logs, and difficulty tables, the game executed the `$A5` (hex) security key handshake to hardware-protect Port `$5B` (hex) and called the protected RAM write primitives (`wp!` / `wpb!`):

```assembly
            ld      hl,$D000                ; Mapped protected RAM base address
            ld      de,$0125                ; Value to write
            call    wp_bang                 ; Call VGER interrupt-safe 16-bit write
```

On the *Extra Bases* bus, this handshake operated in a **"null" hardware environment**. Because there was no physical CMOS lock circuitry to intercept writes, the security strobe was ignored, and the write operations transparently executed as standard volatile RAM writes. As a result, all high scores, coin counts, and diagnostics were completely cleared whenever the cabinet's power switch was cycled.

### Heavy Ballistic Physics (`VECTDD`)
To simulate the parabolic trajectories of batted baseballs, *Extra Bases* made extensive use of VGER’s double-derivative physical integration routine (**`VECTDD`**).

When a ball was hit into the outfield:
1.  The engine spawned a ball Task node and loaded its initial 16-bit fixed-point horizontal velocity (`VDX`) and upward vertical velocity (`VDY`).
2.  Because VGER's vertical coordinate system maps positive Y values downward, the engine loaded a constant **positive** downward acceleration vector into Y-acceleration registers (`VDDYL/VDDYH` offsets `$17–$18` hex, e.g. `$0004` hex) to represent gravity.
3.  On every 60Hz pass, `VECTDD` integrated the positive gravity acceleration into the vertical velocity, and the velocity into the position. This automatically calculated the ball's rising velocity decay, peak, and descending acceleration in a smooth, hardware-automated parabolic arc with zero CPU arithmetic overhead.

### Token-Threaded Code (TTC) Compression
Operating within a strict 16 KB ROM budget, *Extra Bases* rejected the 16-bit Direct Threaded Code (DTC) used in larger cabinets. Instead, it compiled its TERSE virtual machine scripts as single-byte (8-bit) instruction tokens. The TERSE dispatcher used these 8-bit tokens to index a central address jump table, halving the memory footprint of high-level playaction threads and allowing a complex sports simulation to fit into a tiny ROM space.

---

## 2. Gorf (1981): The Expanded Speech & Multitasking Platform

*Gorf* represents the peak of VGER’s co-processing architecture, featuring an expanded cardcage configuration equipped with a custom Speech Board and dedicated battery-backed CMOS static RAM:

```text
Gorf High-Performance Cardcage Configuration:
+-------------------------------------------------------------------------+
| Game Logic Board | CPU Board | Dynamic RAM Board | ROM/RAM Speech Board |
| (A084-90708-X000) | (91354)  | (A082-91356-C000) |  (A082-91364-A000)   |
+-------------------------------------------------------------------------+
```

### Battery-Backed Static CMOS NVRAM
*Gorf* mapped 128 (decimal) bytes of battery-backed CMOS Static RAM from `$D000` to `$D07F` (hex). To guard critical audit tables, difficulty levels (`SKILLFACTOR` at `$D037`), and player high scores from processor runaways during power-down spikes, the hardware bus ignored writes to the `$Dxxx` page by default. Programmers had to call the guarded `wp!` and `wpb!` primitives to unlock the bus with key `$A5` before every write, ensuring bulletproof data integrity across years of commercial cabinet operation.

### Asynchronous Speech Streaming
*Gorf* integrated the **Votrax SC-01** phoneme-based speech synthesizer to deliver dynamic verbal taunts. This co-processed speech pipeline was managed asynchronously during the 60Hz Line 100 scanline interrupt by the **`PHONE`** routine:

1.  When Gorf wanted to speak, game logic called `speak`, which pushed the target phrase's ROM pointer onto an 8-word circular speech stack in RAM (`TALKIN` and `TALKOUT`).
2.  During the 60Hz interrupt, the `PHONE` routine polled Port `$12` (`NEWPHONE`). If Bit 7 was high (synthesizer ready), `PHONE` fetched the next 6-bit phoneme byte from the active ROM address and stuffed it directly into Port `$17` (`PHONEOUT`), advancing the phrase pointer `TALKHERE`.
3.  Once the phrase finished, `PHONE` stuffed the `$3F` (hex) terminal `STOP` phoneme to silence the voice chip.

This handshake allowed the Z80 CPU to stream continuous spoken phrases in a tiny handful of instructions, leaving the processor completely free to run the active gameplay loops.

### Dynamic Speech & Rank Selection (`_GETRANK`)
To celebrate player achievements, the game utilized the TERSE virtual machine to dynamically select and speak military difficulty ranks. Below is Gorf’s compiled script disassembly for the **`_GETRANK`** routine (Block 0109):

```assembly
;=========================================================================================
; ----> _GETRANK         DYNAMIC SPEECH & DIFFICULTY COMPILER           (Block 0109)
;   Cappers player's SKILLFACTOR and plays matching speech phrase.
;=========================================================================================
_GETRANK:   DB      _ENTER              ; Enter threaded TERSE interpreter mode (RST $08)
            DW      _LITword            ; Push literal address of SKILLFACTOR ($D037)
            DW      SKILLFACTOR         ;
            DW      _Bat                ; B@: Fetch players current difficulty (0-5)
            DW      _LITbyte            ; Push limit cap
            DB      $05                 ; Cap value (Difficulty 5 = "Avenger")
            DW      _MIN                ; MIN: Cap the player's rank value at 5
            DW      _LITword            ; Push speech address for "SPACE"
            DW      SPK_SPACE           ; Address $1185
            DW      _SPEAK              ; SPEAK: Trigger voice chip to say "SPACE"
            DW      _ARRAY              ; INDEX into the Rank Tables word array
            DW      RKTBL               ; Table base address $1326
            DW      _at                 ; @: Fetch target speech address from RKTBL
            DW      _RETURN             ; Exit, leaving selected speech vector on stack
```

When game logic called `_GETRANK`, the routine capped the player's difficulty at 5, commanded the Votrax chip to say **"SPACE"**, indexed the `RKTBL` table, and returned the address of the corresponding difficulty rank phrase (e.g., `SPK_AVENGER` at index 5) on the stack for the caller to speak, compiling a highly dynamic gameplay routine in just 26 bytes of ROM.

---

## 3. Wizard of Wor (1980): Repurposed Link Pointers for Active Radar Tracking

*Wizard of Wor* utilized a similar high-performance cardcage configuration to *Gorf*, mapping 64 (decimal) bytes of hardware-locked static NVRAM from `$D000` to `$D03F` (hex).

### Repurposing the Linked Vector Pointer (`VFVPL/VFVPH`)
In the VGER core manual, the 16-bit **Linked Vector Pointer** (offsets 31 and 32 decimal / `$1F–$20` hex) is documented as a formation linkage tool—allowing a squadron member to copy its leader's movement or a ballistic ball task to update its corresponding drop-shadow vector.

In *Wizard of Wor*, the game designers repurposed this generic linking register to drive the game's **real-time active radar HUD**:

1.  The screen featured a bitmapped main maze and a separate, miniature radar screen at the bottom of the display.
2.  To track invisible monsters running through the corridors, the game spawned a visible **Radar Dot** task for each monster in the maze.
3.  VGER bound these objects together by storing the memory address of the physical Monster task directly inside the Radar Dot task's **`VFVPL/VFVPH`** registers.
4.  On every 60Hz background pass, the Radar Dot's update routine read the target address from `VFVPL/VFVPH`, fetched the monster's active coordinates (`VXL/VYH`), divided those coordinates by a scaling factor to fit the mini radar display, and blitted the corresponding radar pixel to the screen.

By repurposing this uniform linking pointer, *Wizard of Wor* updated complex spatial tracking vectors across dozens of moving characters in real time, demonstrating the exceptional flexibility of VGER's object-oriented task model.

---

# Appendix A: 51-Byte Task Header Quick Reference Table

The following table provides the authoritative byte-by-byte memory layout of VGER's 51-byte (decimal) Task Header Block, spanning offsets 0 to 50 (decimal) (`$00` to `$32` hex).

| Dec | Hex | Field Name | Size / Type | System Function & Virtual Machine Semantics |
| :--- | :--- | :--- | :--- | :--- |
| **0** | `$00` | `PQS` | 1 Byte | **Task Status Bitmask:** Tracks active (`TBACT`), asleep (`TBSLEEP`), and freeze (`PQSFRZ`) states. |
| **1–2** | `$01`–`$02` | `PQFL` / `PQFH` | 2 Bytes (Word) | **Forward Link:** Pointer to the next active node in the doubly linked circular queue. |
| **3–4** | `$03`–`$04` | `PQBL` / `PQBH` | 2 Bytes (Word) | **Backward Link:** Pointer to the previous active node in the doubly linked circular queue. |
| **5–6** | `$05`–`$06` | `PQRL` / `PQRH` | 2 Bytes (Word) | **Task Routine Address:** Pointer to the native Z80 execution handler of the task. |
| **7** | `$07` | `PQTB` | 1 Byte | **Time Base:** Delta scalar multiplier used to regulate physical movement increments. |
| **8** | `$08` | `VXZW` | 1 Byte | **Exclusion Zone Width:** Horizontal boundary size used in raster-safe coordinate checks. |
| **9** | `$09` | `VAUXS` | 1 Byte | **Auxiliary Status:** General status flags, such as squadron/formation locks. |
| **10** | `$0A` | `VATMR` | 1 Byte | **Animation Timer:** Countdown timer automatically decremented by the 60Hz interrupt scheduler. |
| **11–12** | `$0B`–`$0C` | `VTLL` / `VTLH` | 2 Bytes (Word) | **Master Time Limit:** Lifespan counter of the task before auto-erasing and despawning. |
| **13–14** | `$0D`–`$0E` | `VXL` / `VXH` | 2 Bytes (Word) | **X Coordinate:** 16-bit horizontal screen position (Integer upper, fractional lower). |
| **15–16** | `$0F`–`$10` | `VDXL` / `VDXH` | 2 Bytes (Word) | **X Velocity:** Signed 16-bit speed along the horizontal axis. |
| **17–18** | `$11`–`$12` | `VDDXL` / `VDDXH` | 2 Bytes (Word) | **X Acceleration:** Signed 16-bit horizontal acceleration. |
| **19–20** | `$13`–`$14` | `VYL` / `VYH` | 2 Bytes (Word) | **Y Coordinate:** 16-bit vertical screen position. |
| **21–22** | `$15`–`$16` | `VDYL` / `VDYH` | 2 Bytes (Word) | **Y Velocity:** Signed 16-bit speed along the vertical axis. |
| **23–24** | $17–$18 | VDDYL / VDDYH | 2 Bytes (Word) | **Y Acceleration / Limits:** Signed 16-bit vertical acceleration (for gravity), or reused as Y clamping limits in player tasks. |
| **25–26** | $19–$1A | VSAL / VSAH | 2 Bytes (Word) | **Screen Address:** The calculated destination memory offset in viewable VRAM. |
| **27** | `$1B` | `VMAGIC` | 1 Byte | **Blitter Properties:** Hardware mode flags (XOR, transparent expanding, flips). |
| **28** | `$1C` | `VXPAND` | 1 Byte | **Palette Mask:** Selects which hardware palette index is applied to expanded sprites. |
| **29–30** | `$1D`–`$1E` | `VPATL` / `VPATH` | 2 Bytes (Word) | **Sprite Pattern Pointer:** Memory address of the source graphic pattern stored in ROM. |
| **31–32** | `$1F`–`$20` | `VFVPL` / `VFVPH` | 2 Bytes (Word) | **Formation Link Pointer:** Pointer to secondary tasks (e.g., ball linked to shadow). |
| **33–34** | `$21`–`$22` | `VPCL` / `VPCH` | 2 Bytes (Word) | **Animation VPC:** Virtual program counter tracking current position in scripts. |
| **35–36** | `$23`–`$24` | `VSPL` / `VSPH` | 2 Bytes (Word) | **Animation Stack Pointer:** Pointer to private return stack for nested script loops. |
| **37–38** | `$25`–`$26` | `VPTBL` / `VPTBH` | 2 Bytes (Word) | **Animation Table Pointer:** Base memory address of the task's script pattern frames. |
| **39–40** | `$27`–`$28` | `VIRL` / `VIRH` | 2 Bytes (Word) | **Intercept Hook Pointer:** Memory address of custom intercept check routine. |
| **41** | `$29` | `VINTER` / `VRACK`| 1 Byte | **Intercept / Rack Code:** Tracks hardware collision registers and squadron states. |
| **42–43** | `$2A`–`$2B` | `VFNLPL` / `VFNLPH`| 2 Bytes (Word) | **Final Pattern:** ROM pattern address to display upon script termination/halt. |
| **44** | `$2C` | `VSHFTA` | 1 Byte | **Magic Shift Value:** LSI shift remainder tracked from the last draw operation. |
| **45** | `$2D` | `VIDENT` | 1 Byte | **Object Identity Code:** System-wide unique ID designating the object category. |
| **46–47** | `$2E`–`$2F` | `VFXBL` / `VFXBH` | 2 Bytes (Word) | **Formation X Bias:** Horizontal offset distance relative to the squadron leader. |
| **48–49** | `$30`–`$31` | `VFYBL` / `VFYBH` | 2 Bytes (Word) | **Formation Y Bias:** Vertical offset distance relative to the squadron leader. |
| **50** | `$32` | `VASTKS` | 1 Byte | **Animation Stack Start:** First offset of local return stack workspace. |


# Appendix B: Bare-Metal Hardware I/O Port Assignments

The following table documents the core hardware ports exposed by the Bally/Midway cardcage architecture and utilized by VGER's subsystems.

| Port Address (Hex) | Port Address (Dec) | Direction | Port Constant | Subsystem / Hardware Functionality |
| :--- | :--- | :--- | :--- | :--- |
| **`$00–$07`** | `0–7` | Write | `COL0R–COL3L` | **Color Palette Registers:** Controls active color values for left and right screen halves. |
| Port Address (Hex) | Port Address (Dec) | Direction | Port Constant | Subsystem / Hardware Functionality |
| :--- | :--- | :--- | :--- | :--- |
| **$08** | 8 | Read | INTST | **Hardware Intercept Register:** Collision detection feedback latch. |
| **$08** | 8 | Write | CONCM | **Control Mode Register:** Configures video resolution (written as $01 for high-res mode). |
| **$09** | 9 | Write | HORCB | **Horizontal Color Boundary:** Sets vertical split column for split palette maps. |
| **$0A** | 10 | Write | VERBL | **Vertical Blank Line:** Sets blanking line split (written as $CC to mask workspace). |
| **$0B** | 11 | Write | COLBX | **Color Block Transfer:** Master color-fill register. |
| **$0C** | 12 | Write | MAGIC | **Magic RAM Control:** Programs the Magic Function Generator (XOR, OR, fill, shifts). |
| **$0D** | 13 | Write | BGINTVEC | **Interrupt Vector:** Sets page vector offset for IM 2 handlers. |
| **$0E** | 14 | Read | VERAF | **Vertical Line Feedback:** Retrieves active scanline position of CRT electron beam. |
| **$0E** | 14 | Write | INMOD | **Interrupt Mode Register:** Configures interrupt page and timing parameters. |
| **$0F** | 15 | Read | HORAF | **Horizontal Feedback:** Retrieves active pixel horizontal position. |
| **$0F** | 15 | Write | INLIN | **Interrupt Line:** Sets target scanline boundary for raster triggers. |
| **`$10`** | `16` | Write | `TONMO` | **Sound Chip Voice Mode:** Audio tone mode register. |
| **`$11`** | `17` | Write | `TONEA` | **Sound Chip Voice A:** Tone generator voice A frequency register. |
| **`$12`** | `18` | Write | `TONEB` | **Sound Chip Voice B:** Tone generator voice B frequency register. |
| **`$13`** | `19` | Read | `SETTINGS` | **Cabinet Dipswitches:** Read language, bonus life, and demo sound settings. |
| **`$13`** | `19` | Write | `TONEC` | **Sound Chip Voice C:** Tone generator voice C frequency register. |
| **`$14`** | `20` | Write | `VIBRA` | **Sound Chip Vibrato:** Dual-frequency vibrato register. |
| **`$15`** | `21` | Write | `VOLC` | **Sound Chip Voice C Volume:** Audio volume register for voice C. |
| **`$16`** | `22` | Write | `VOLAB` | **Sound Chip Voice A/B Volume:** Audio volume register for voices A and B. |
| **`$17`** | `23` | Write | `VOLN` | **Sound Chip Noise / Speech Port:** Synthesizer phoneme streamer or noise register. |
| **`$18`** | `24` | Write | `SNDBX` | **Sound Chip Soundbox:** Noise envelope selector. |
| **`$19`** | `25` | Write | `XPAND` | **Blitter Expand Color:** Palette mask register for expanded 1bpp pattern blits. |