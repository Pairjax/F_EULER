*,______________________________________________________,
*|__________  ______________  ________________________  |
*|___  ____/  ___  ____/_  / / /__  /___  ____/__  __ \ |
*|__  /_________  __/  _  / / /__  / __  __/  __  /_/ / |
*|_  __//_____/  /___  / /_/ / _  /___  /___  _  _, _/  |
*|/_/         /_____/  \____/  /_____/_____/  /_/ |_|   |
*|                                                      |
*|            The 68k high-speed racing game            |
*|                                                      |
*|  Made By: Austin Smith        Date Started: 10/7/23  |
*|______________________________________________________|
*`                                                      `

    ORG $1000

*,__________________________________________________,
*| Constants

ALL_REG             REG D0-D7/A0-A6
TRAP_REG            REG D0-D1/A0-A2

*| Vectors
SCREEN_WIDTH        EQU 640
SCREEN_HEIGHT       EQU 480

*| TRAP Codes
GET_KEY_INPUT_COMMAND   EQU 19

SET_PIXEL_COLOR     EQU 80
PRINT_PIXEL         EQU 82

GET_TIME            EQU 8

SWAP_BUFFER         EQU 94

*| 7 Segment Stuff
SEVEN_SEG_DIMENSIONS    EQU $0012001F

*,__________________________________________________,
*| Includes
    INCLUDE "./file_loader.x68"   ; Handles loading of files during preload phase
    INCLUDE "./renderer.x68"      ; Handles printing sprites & affine transformations.
    INCLUDE "./inputs.x68"        ; Handles player inputs for processing
* INCLUDE "./gameplay.x68"        ; Handles in-game timer, lap counter, and game states
    INCLUDE "./physics.x68"       ; Calculates player acceleration, velocity, and collisions.
    INCLUDE "./display.x68"       ; Displays a 7-segment LED with the given parameters.

*,__________________________________________________,
*| fn Main
*| Description: Loads files, sets game state, begins
*|              game loop, and handles quit state
START ORG $2000
Main:
    ; Initialize pixel_clear_length
    move.l #pixel_clear_zones, pixel_clear_length

    move.l #92, d0
    move.l #17, d1
    
    TRAP #15

    jsr fl_LoadFiles
    
    move.l #$00000000, d0   ; Position has no offset
    move.l #$00000000, d1   ; This is not a sprite, it's the background
    move.l #$00000000, d2
    move.l #pg_Background, a0
    jsr r_PrintImage
    
    jsr ss_InitDisplays
    
    ; Set up start variables for game loop
    move.l #$0221012C, d5   ; Start position of ship

    move.l #GET_TIME, d0    ; Get current time (start of game time)
    TRAP #15

    move.l d1, LastSecond    ; This time is the start of the game

    jsr GameLoop

    STOP #$3000
*| [End of Function] Main
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| fn GameLoop
*| Description: Perpetually runs game until the quit 
*| command is given.
*| Persistent Variables:
*| d2: Rotation, DeltaTime 
*| d3: WASD Inputs, d4: Enter, Esc, Shift, and Space Inputs
*| d5: Position, d6: Velocity, d7: Acceleration
*| a3: Ship model to use
GameLoop:
    move.l #8, d0  ; Time Code - maybe reuse later?

    TRAP #15

    jsr UpdateTimer         ; Updates the in-game timer if a second has passed

    move.l d1, d0
    sub.l LastTime, d0
    cmp.l #5, d0            ; Is time elapsed less than 5/100ths of a second?
    bls.l GameLoop          ; If not, wait
    move.l d1, LastTime     ; Otherwise, this is the new last time

    *,___________________________,
    *| STAGE ONE: Capture Inputs |
    *|___________________________|
    *`                           ` 
    jsr i_CaptureInputs   ; Fills registers d3-d4 (destructively) with player inputs

    *,___________________________,
    *| STAGE TWO: Physics Pass   |
    *|___________________________|
    *`                           `
    jsr ph_CalculateRotation
    jsr ph_SelectShipRotation

    jsr ph_CalcVelMagnitude
    jsr ph_CalcVelDir
    jsr ph_CalculatePosition

    jsr cl_CheckCollisions

    *,___________________________,
    *| STAGE THREE: Rendering    |
    *|___________________________|
    *`                           `
    ; Clear old sprites from screen
    jsr r_ClearSprites ; Wipe sprites from screen

    ; Render ship
    ; move.l #pg_Ship, a0
    move.l a3, a0   ; Move ship image address to the correct location
    move.l d5, d0   ; Move position to offset
    jsr r_PrintImage

    ; Swap Buffer
    jsr SwapBuffer

    cmp.w #1, flag_IsDead   ; did player die?
    beq.l .Return  ; If so, end loop

    and.l #$00FF0000, d4
    cmp.l #$00FF0000, d4    ; Did player press ESC?
    beq.l .Return  ; If so, continue loop

    jmp GameLoop

.Return:

    rts
*| [End of Function] GameLoop
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| fn UpdateTimer
*| Description: Checks if a second has passed to update
*| the timer
*| Inputs: d1: Current Time
UpdateTimer:
    movem.l ALL_REG, -(sp)  *| Push registers to stack

    move.l d1, d0
    sub.l LastSecond, d0
    cmp.l #100, d0          ; Is time elapsed 1 second?
    bls.l .Return            ; If not, carry on as normal

    move.l d1, LastSecond   ; Otherwise, we're now in the next second

    clr.l d0                ; clear d0 for next step

    move.l #ssd_Timer, a0   ; Let's now update the timer
    add.l #24, a0           ; Offset to 4th display (00:0X)

.AddSecond:
    add.l #6, a0            ; Offset to actual number
    move.w (a0), d0         ; Grab number
    add.l #1, d0            ; Increment by 1
    cmp.l #9, d0            ; Has its number gone over 9?
    ble.l .EndOverflow      ; If not, we're done.

    ; Otherwise, we overflow to the next display
    sub.l #6, a0            ; offset to start of current display
    move.l #0, d0           ; New number in display must be 0
    jsr ss_SevenSegUpdate

    sub.l #8, a0            ; offset to start of last display
    jmp .AddSecond          ; Continue loop

.EndOverflow:
    sub.l #6, a0            ; Offset back to start of display addr
    jsr ss_SevenSegUpdate   ; Print this display's new number

.Return:
    movem.l (sp)+, ALL_REG  *| Pull registers from stack

    rts
*| [End of Function] UpdateTimer
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Collisions] fn CheckCollisions
*| Description: Checks what material the player is on
cl_CheckCollisions:
    ; Check root of ship location
    move.l d5, d0
    jsr cl_GetCollisionMaterial     ; d0 is now filled with material
    jsr cl_ProcessMaterial

    ; Check top right corner
    move.l d5, d0
    add.l #$000F0000, d0
    jsr cl_GetCollisionMaterial     ; d0 is now filled with material
    jsr cl_ProcessMaterial

    ; Check bottom left corner
    move.l d5, d0
    add.l #$0000000F, d0
    jsr cl_GetCollisionMaterial     ; d0 is now filled with material
    jsr cl_ProcessMaterial

    ; Check bottom right corner
    move.l d5, d0
    add.l #$000F000F, d0
    jsr cl_GetCollisionMaterial     ; d0 is now filled with material
    jsr cl_ProcessMaterial

.Return:

    rts
*| [End of Function] CheckCollisions
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Collisions] fn GetCollisionMaterial
*| Description: Check what material is at a particular pixel address
*| Input: d0: coordintaes (w1: x, w2: y)
cl_GetCollisionMaterial:
    move.l d0, d1
    lsr.l #8, d0            ; X
    lsr.l #8, d0
    and.l #$0000FFFF, d1    ; Y

    mulu.w #SCREEN_WIDTH, d1    ; Y * Screen Width
    add.l d0, d1                ; + X = Index

    move.l #cm_Road, a0
    add.l d1, a0                ; Offset to material

    move.b (a0), d0             ; Grab material
    and.l #$000000FF, d0            ; Cut off leftmost bits

.Return:

    rts
*| [End of Function] GetCollisionMaterial
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Collisions] fn ProcessMaterial
*| Description: Check what material is at a particular pixel address
*| Input: d0: material
cl_ProcessMaterial:
.Offroad:
    cmp.l #0, d0    ; Offroad?
    bne.l .Lap

    move.w #1, flag_IsDead  ; You're dead!
    jmp .Return

.Lap:
    cmp.l #2, d0    ; On the lap?
    bne.l .MidLap

    cmp.w #0, flag_CanLap   ; Are we in a valid lap state?
    beq.l .Return           ; If not, invalid

    add.l #1, i_CurrentLap  ; Lap += 1 (TODO: Update lap UI)
    move.w #0, flag_CanLap  ; CanLap = false

.MidLap:
    cmp.l #3, d0    ; On the mid-lap?
    bne.l .Powerup

    cmp.w #0, flag_CanLap   ; Are we in a valid lap state?
    bne.l .Return           ; If not, invalid

    move.w #1, flag_CanLap  ; CanLap = true

.Powerup:
    ; TODO: Whatever poewrups do

.Return:
    ; No special state for any other material

    rts
*| [End of Function] ProcessMaterial
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| Input Variables
LastTime    ds.l 1  ; Stores the last frame's start time
LastSecond   ds.l 1  ; Stores the time the game started

BackgroundBmpFile   INCBIN "../resources/background.bmp"
RoadCollisionFile   INCBIN "../resources/collision_map.txt"

*| Ship Rotations
ShipBmpFiles        INCBIN "../resources/ship_rotations/Ship_R0.bmp"
                    INCBIN "../resources/ship_rotations/Ship_R22.5.bmp"
                    INCBIN "../resources/ship_rotations/Ship_R45.bmp"
                    INCBIN "../resources/ship_rotations/Ship_R67.5.bmp"
                    INCBIN "../resources/ship_rotations/Ship_R90.bmp"
                    INCBIN "../resources/ship_rotations/Ship_R112.5.bmp"
                    INCBIN "../resources/ship_rotations/Ship_R135.bmp"
                    INCBIN "../resources/ship_rotations/Ship_R157.5.bmp"
                    INCBIN "../resources/ship_rotations/Ship_R180.bmp"
                    INCBIN "../resources/ship_rotations/Ship_R202.5.bmp"
                    INCBIN "../resources/ship_rotations/Ship_R225.bmp"
                    INCBIN "../resources/ship_rotations/Ship_R247.5.bmp"
                    INCBIN "../resources/ship_rotations/Ship_R270.bmp"
                    INCBIN "../resources/ship_rotations/Ship_R292.5.bmp"
                    INCBIN "../resources/ship_rotations/Ship_R315.bmp"
                    INCBIN "../resources/ship_rotations/Ship_R337.5.bmp"
EndShipBmpFiles


; DebrisBmpFile       INCBIN "../resources/debris.bmp"

*,__________________________________________________,
*| Global Variables

*| Data Type: Pixel Grid (pg)
*| $0 = Width
*| $2 = Height
*| $4 = ABGR Pixels (List, length x * y)
*>Renderer
pg_Background   ds.l 307201     ; 1 + 640x480

pg_ShipRotations        ds.l 4112   ; (1 + 16x16) x 16 for 16 unique sprites

pg_Debris       ds.l 257        ; 1 + 16x16

*| Data Type: Collision Map
*| Each byte represents a single pixel on the screen.
*| Dimension is assumed to be the dimensions of the screen.
*| 0 = off the road, 1 = on the road, 
*| 2 = lap, 3 = mid_lap, 4 = power_up
cm_Road         ds.b 307200 ; 640 x 480

*| Data Type: Pixel Clear Zones -> List<vec2, vec2>
*| An array storing the zones that need to be cleared of pixels
*| Long 1: Stores a vec2 representing the offset in x, y
*| Long 2: Stores a vec2 representing the width and height
pixel_clear_zones   ds.l 40     ; Max of 20 zones to clear at any given time
pixel_clear_length  ds.l 1      ; Pointer to the last empty address

flag_IsDead         dc.w $0
flag_IsBoosting     dc.w $0
flag_CanLap         dc.w $0

i_CurrentLap        dc.w $1

*>7-Segment LED
pg_7SegVertical     ds.l 65     ; 1 + 16x4
pg_7SegHorizontal   ds.l 65     ; 1 + 16x4
    
    END    START




*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
