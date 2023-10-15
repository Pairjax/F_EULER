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

*| PHYSICS
MAX_VELOCITY        EQU $00030000

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
    move.l #0, d0   ; Start position of ship
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
*| d2: Rotation, 
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
    move.l #pg_Ship, a0
    jsr r_PrintImage

    ; Render other things

    ; Swap Buffer
    jsr SwapBuffer

    and.l #$000000FF, d3    ; Extracting only D from WASD input

    cmp.l #$FF, d3          ; Is D being pressed?
    bne.l .NoInput          ; If not, let's skip movement

    add.l #$00010000, d0    ; Move the ship to the right.

.NoInput:
    and.l #$00FF0000, d4
    cmp.l #00FF0000, d4    ; Did player press ESC?
    bne.l GameLoop  ; If not, continue loop

    rts
*| [End of Function] GameLoop
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Physics] fn CalculateRotation
*| Description: Take A & D inputs and rotate ship.
ph_CalculateRotation:
    movem.l ALL_REG, -(sp)  *| Push registers to stack

    move.l d3, d0   ; Copying WASD inputs to extract A & D
    move.l d0, d1

    and.l #$000000FF, d1    ; D input
    
    movem.l (sp)+, ALL_REG  *| Pull registers from stack

    rts
*| [End of Function] CalculateRotations
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Physics] fn CalculateAcceleration
*| Description: Takes W & S inputs to find acceleration magnitude

*| [End of Function] CalculateAcceleration
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

ShipBmpFile         INCBIN "../resources/ship.bmp"

*| Ship Rotations
Ship0BmpFile        INCBIN "../resources/ship_rotations/Ship_R0.bmp"
Ship22BmpFile       INCBIN "../resources/ship_rotations/Ship_R22.5.bmp"
Ship45BmpFile       INCBIN "../resources/ship_rotations/Ship_R45.bmp"
Ship67BmpFile       INCBIN "../resources/ship_rotations/Ship_R67.5.bmp"
Ship90BmpFile       INCBIN "../resources/ship_rotations/Ship_R90.bmp"
Ship112BmpFile      INCBIN "../resources/ship_rotations/Ship_R112.5.bmp"
Ship135BmpFile      INCBIN "../resources/ship_rotations/Ship_R135.bmp"
Ship157BmpFile      INCBIN "../resources/ship_rotations/Ship_R157.5.bmp"
Ship180BmpFile      INCBIN "../resources/ship_rotations/Ship_R180.bmp"
Ship202BmpFile      INCBIN "../resources/ship_rotations/Ship_R202.5.bmp"
Ship225BmpFile      INCBIN "../resources/ship_rotations/Ship_R225.bmp"
Ship247BmpFile      INCBIN "../resources/ship_rotations/Ship_R247.5.bmp"
Ship270BmpFile      INCBIN "../resources/ship_rotations/Ship_R270.bmp"
Ship292BmpFile      INCBIN "../resources/ship_rotations/Ship_R292.5.bmp"
Ship315BmpFile      INCBIN "../resources/ship_rotations/Ship_R315.bmp"
Ship337BmpFile      INCBIN "../resources/ship_rotations/Ship_R337.5.bmp"


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
pg_Ship         ds.l 257        ; 1 + 16x16
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
