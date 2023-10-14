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

*| Vectors
SCREEN_WIDTH        EQU 640
SCREEN_HEIGHT       EQU 480

*| TRAP Codes
GET_KEY_INPUT_COMMAND   EQU 19

SET_PIXEL_COLOR     EQU 80
PRINT_PIXEL         EQU 82

SWAP_BUFFER         EQU 94

*,__________________________________________________,
*| Includes
    INCLUDE "./file_loader.x68"   ; Handles loading of files during preload phase
    INCLUDE "./renderer.x68"      ; Handles printing sprites & affine transformations.
* INCLUDE "./inputs.x68"        ; Handles player inputs for processing
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
    
    move.l #$00000000, d0
    move.l #$00000000, d1
    move.l #pg_Background, a0
    jsr r_PrintImage
    
    move.l #0, d0
    move.l #1, d1
    move.l #0, d7   ; Halt Flag

    jsr GameLoop

    STOP #$3000
*| [End of Function] Main
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| fn GameLoop
*| Description: Perpetually runs game until the quit 
*| command is given
GameLoop:
    *,___________________________,
    *| STAGE ONE: Capture Inputs |
    *|___________________________|
    *`                           `

    ; jsr CapturePlayerInputs   ; Fills registers (destructively) with player inputs
    ; We use this to run the rest of the operations

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

    add.l #$00010001, d0    ; move XY offset on the diagonal

    cmp.l #0, d7    ; Is Halt Flag true?
    beq.l GameLoop  ; If not, continue loop

    rts
*| [End of Function] GameLoop
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Inputs] fn GetUserInput
*| Description: Captures all relevant game inputs
i_GetuserInput:
    movem.l ALL_REG, -(sp) *| Push registers to stack

    
    
.Return:
    movem.l (sp)+, ALL_REG  *| Pull registers from stack

    rts
*| [End of Function] GetUserInput
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| Input Variables
BackgroundBmpFile   INCBIN "../resources/background.bmp"
; RoadCollisionFile   INCBIN "../resources/collision.txt"

ShipBmpFile         INCBIN "../resources/ship.bmp"
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
