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

SWAP_BUFFER         EQU 94

*| Input Codes
ENTER               EQU $D
ESC                 EQU $1B
SHIFT               EQU $10
SPACE               EQU $20

*| Physics
MAX_VELOCITY        EQU $00030000
FP_360              EQU $01680000   ; Hex value for 360 degrees in 16.16 fixed point
FP_22P5             EQU $00168000   ; Hex value for 22.5 degrees in 16.16 fixed point
FP_11P25            EQU $000B4000   ; Hex value for 11.25 degrees in 16.16 fixed point

*,__________________________________________________,
*| Includes
    INCLUDE "./file_loader.x68"   ; Handles loading of files during preload phase
    INCLUDE "./renderer.x68"      ; Handles printing sprites & affine transformations.
    INCLUDE "./inputs.x68"        ; Handles player inputs for processing
* INCLUDE "./gameplay.x68"      ; Handles in-game timer, lap counter, and game states
* INCLUDE "./physics.x68"       ; Calculates player acceleration, velocity, and collisions.
* INCLUDE "./7_segment_led.x68" ; Displays a 7-segment LED with the given parameters.

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
    move.l #pg_Background, a0
    jsr r_PrintImage
    
    ; Set up start variables for game loop
    move.l #$0221012C, d0   ; Start position of ship
    move.l #1, d1   ; Is ship a sprite? Yes!

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

    *,___________________________,
    *| STAGE THREE: UI Pass      |
    *|___________________________|
    *`                           `

    *,___________________________,
    *| STAGE FOUR: Rendering     |
    *|___________________________|
    *`                           `
    ; Clear old sprites from screen
    jsr r_ClearSprites ; Wipe sprites from screen

    ; Render ship
    ; move.l #pg_Ship, a0
    move.l a3, a0   ; Move ship image address to the correct location
    jsr r_PrintImage

    ; Render other things

    ; Swap Buffer
    jsr SwapBuffer

    and.l #$00FF0000, d4
    cmp.l #$00FF0000, d4    ; Did player press ESC?
    bne.l GameLoop  ; If not, continue loop

    rts
*| [End of Function] GameLoop
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Physics] fn CalculateRotation
*| Description: Take A & D inputs and rotate ship.
ph_CalculateRotation:
    movem.l TRAP_REG, -(sp)  *| Push registers to stack

    move.l d3, d0   ; Copying WASD inputs to extract A & D
    move.l d0, d1

    lsr.l #8, d0            ; A key input
    lsr.l #8, d0
    and.l #$000000FF, d0    ; Chopping off W input

    and.l #$000000FF, d1    ; D key input

    cmp.l d0, d1            ; Are A & D both pressed or not pressed?
    beq.l .Return           ; If so, let's skip to the end.

.TurnLeft:
    cmp.l #0, d0
    beq.l .TurnRight

    sub.l #00010000, d2

    jmp .FixAngle

.TurnRight:
    add.l #00010000, d2
    
.FixAngle:
    cmp.l #FP_360, d2       ; Is d2 greater than 360?
    bgt.l .AngleOver
    cmp.l #0, d2            ; Is d2 negative?
    blt.l .AngleUnder

    jmp .Return

.AngleOver:
    sub.l #FP_360, d2          

    jmp .Return

.AngleUnder:
    add.l #FP_360, d2

.Return
    movem.l (sp)+, TRAP_REG  *| Pull registers from stack

    rts
*| [End of Function] CalculateRotations
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Physics] fn SelectShipRotation
*| Description: Takes current rotation & selects ship image based off of it
ph_SelectShipRotation:
    movem.l TRAP_REG, -(sp)  *| Push registers to stack

    move.l d2, d0   ; Take angle to temporary variable
    move.l #0, d1   ; d1 stores ship index
    sub.l #FP_11P25, d0 ; Subtract angle by 11.25

.NextRot:
    add.l #1, d1        

    sub.l #FP_22P5, d0  ; Subtract angle by 11.25
    cmp.l #0, d0        ; Is angle under 0?
    bge.l .NextRot      ; If not, get next rotation

    ; We de-increment by 1 to go back to the desired index
    sub.l #1, d1

    cmp.l #16, d1       ; Is d1 greater than 15?
    blt.l .GetFile      ; If not, we ignore the next step

    move.l #0, d1       ; If we went past 15, we reset back to the first index

.GetFile:
    mulu.w #1028, d1     ; Multiply by size of ship's pixel grid
    add.l #pg_ShipRotations, d1
    move.l d1, a3

.Return
    movem.l (sp)+, TRAP_REG  *| Pull registers from stack

    rts
*| [End of Function] SelectShipRotation
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Physics] fn CalculateAcceleration
*| Description: Takes W & S inputs to find acceleration magnitude
ph_CalculateAcceleration:
    move.l d3, d0   ; Copying WASD inputs to extract A & D
    move.l d0, d1

    lsr.l #8, d0            ; W key input
    lsr.l #8, d0
    lsr.l #8, d0

    lsr.l #8, d1            ; S key input
    and.l #$000000FF, d1    

    cmp.l d0, d1            ; Are S & S both pressed or not pressed?
    beq.l .Return           ; If so, let's skip to the end.

    cmp.l #0, d0            ; Are we accelerating?
    beq.l .Decel            ; If not, then we must be decelerating.

.Accel:
    move.l #$0080, d0   ; magnitude of acceleration (0.5)

    jmp .Return

.Decel:
    move.l #$FFCF, d0   ; magnitude of acceleration (-0.25)


.Return:

    rts
*| [End of Function] CalculateAcceleration
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Physics] fn CalculateVelocity
*| Description: Take acceleration and use it to calculate velocity
ph_CalculateVelocity


.Return:

    rts
*| [End of Function] CalculateVelocity
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Math] fn Sine
*| Description: Takes an 8.8 number and finds the
*| closets sin value for it.
*| Input: d0: fixed8.8
*| Returns: d0: fixed8.8 ()
m_Sine:
    rts
*| [End of Function] Sine
*|__________________________________________________
*`                                                  `

sinTable        dc.w    $0,$47,$8E,$D6,$11D,$164,$1AC,$1F3,$23A,$280,$2C7
                dc.w    $30D,$353,$399,$3DE,$424,$469,$4AD,$4F1,$535
                dc.w    $578,$5BB,$5FE,$640,$681,$6C3,$703,$743,$782
                dc.w    $7C1,$7FF,$83D,$87A,$8B6,$8F2,$92D,$967,$9A1
                dc.w    $9D9,$A11,$A48,$A7F,$AB4,$AE9,$B1D,$B50,$B82
                dc.w    $BB3,$BE3,$C13,$C41,$C6F,$C9B,$CC7,$CF1,$D1B
                dc.w    $D43,$D6B,$D91,$DB6,$DDB,$DFE,$E20,$E41,$E61
                dc.w    $E80,$E9D,$EBA,$ED5,$EEF,$F08,$F20,$F37,$F4D
                dc.w    $F61,$F74,$F86,$F97,$FA6,$FB4,$FC1,$FCD,$FD8
                dc.w    $FE1,$FE9,$FF0,$FF6,$FFA,$FFD,$FFF,$FFF

*,__________________________________________________,
*| Input Variables
BackgroundBmpFile   INCBIN "../resources/background.bmp"
; RoadCollisionFile   INCBIN "../resources/collision.txt"

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

; 7SegVerticalBmpFile INCBIN "../resources/7SegVertical.bmp"
; 7SegVerticalBmpFile INCBIN "../resources/7SegHorizontal.bmp"

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

*| Data Type: Pixel Clear Zones -> List<vec2, vec2>
*| An array storing the zones that need to be cleared of pixels
*| Long 1: Stores a vec2 representing the offset in x, y
*| Long 2: Stores a vec2 representing the width and height
pixel_clear_zones   ds.l 40     ; Max of 20 zones to clear at any given time
pixel_clear_length   ds.l 1      ; Pointer to the last empty address

*>7-Segment LED
pg_7SegVertical     ds.l 65     ; 1 + 16x4
pg_7SegHorizontal   ds.l 65     ; 1 + 16x4
    
    END    START








*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
