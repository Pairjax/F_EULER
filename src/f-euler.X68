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

    INCLUDE "./file_loader.x68"   ; Handles loading of files during preload phase
* INCLUDE "./renderer.x68"      ; Handles printing sprites & affine transformations.
* INCLUDE "./inputs.x68"        ; Handles player inputs for processing
* INCLUDE "./gameplay.x68"      ; Handles in-game timer, lap counter, and game states
* INCLUDE "./physics.x68"       ; Calculates player acceleration, velocity, and collisions.
* INCLUDE "./7_segment_led.x68" ; Displays a 7-segment LED with the given parameters.

*,__________________________________________________,
*| Constants

ALL_REG             REG D0-D7/A0-A6

*>Renderer
*| Vectors
SCREEN_WIDTH        EQU 640
SCREEN_HEIGHT       EQU 480

*| TRAP Codes
SET_PIXEL_COLOR     EQU 80
PRINT_PIXEL         EQU 82

*,__________________________________________________,
*| fn Main
*| Description: Loads files, sets game state, begins
*|              game loop, and handles quit state
START ORG $1000
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

    move.l #pg_Ship, a0
    jsr r_PrintImage

    jsr r_ClearSprites

    STOP #$2000
*| [End of Function] Main Function
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Renderer] fn PrintImage
*| Inputs: d0=offset: vec2, d1=temporary: bool, a0=image: pixel_grid*
r_PrintImage: 
    movem.l ALL_REG, -(sp)  *| Push registers to stack

    *| Move starting variables to non-volatile positions
    move.l d0, d2           ; offset: vec2
    move.l (a0), d0         ; Image dimensions

    cmp.l #0, d1    ; Is this a sprite?
    beq.l .LoadVarsToRegisters            ; If not, let's skip this step.
    *| We need to store the offset: vec2 and image dimensions: vec2
    *| for clearing next frame's data.
    
    move.l pixel_clear_length, a1
    move.l d2, (a1)  ; Move image offset to pixel_clear_zones
    add.l #4, a1     ; Move to next word
    move.l d0, (a1)  ; Move image dimensions to pixel_clear_zones
    add.l #8, pixel_clear_length     ; Move to next word

.LoadVarsToRegisters:

    *| Set up the starting variables for printing pixels
    move.l d2, d3
    lsr.l #8, d3            ; Offset X
    lsr.l #8, d3
    and.l #$0000FFFF, d2    ; Offset Y
       
    move.l d0, d1
    lsr.l #8, d0            ; Image Width (left word)
    lsr.l #8, d0
    and.l #$0000FFFF, d1    ; Image Height (right word)
        
    move.l d3, d5           ; Start X Position
    
    clr.l d6
    move.w d3, d6           ; End X Position
    add.l d0, d6
    sub.l #1, d6
        
    clr.l d7
    move.w d2, d7           ; End Y Position
    add.l d1, d7
    sub.l #1, d7
    
    add.l #4, a0
        
.PrintPixel:
    move.l #SET_PIXEL_COLOR, d0 ; TRAP Set Pen Color
    move.l (a0), d1             ; Get current pixel color

    and.l #$00FFFFFF, d1        ; Chop off alpha
        
    TRAP #15
               
    move.l #PRINT_PIXEL, d0     ; TRAP Draw Pixel
    move.l d3, d1               ; Pixel X location must be extracted 
   
    TRAP #15
      
    ; Done printing, let's calculate the next target pixel.
    add.l #4, a0            ; Move pointer to next color pixel
        
    add.l #1, d3            ; Move X to the next column
    cmp.l d6, d3            ; Is X past End X Position?
    bls.l .PrintPixel        ; If not, keep on printing
        
    ; Otherwise, we move to the next row
    sub.l d6, d3            ; Move X back to the starting column
    sub.l #1, d3
    add.l #1, d2            ; Move Y down a row
        
    cmp.l d7, d2            ; Is Y past End Y Position?
    ble.l .PrintPixel         ; If not, keep printing.

.SwapBuffer:

    *| Now that we're done, let's swap buffers
    move.l #94, d0
    
    TRAP #15

.Return:

    movem.l (sp)+, ALL_REG  *| Pull registers from stack

    rts
*| [End of Function] PrintImage
*|__________________________________________________
*`                                                  `


*,__________________________________________________,
*| [Renderer] fn ClearSprites
*| Iterates over every clear pixel zone and resets their
*| color to the background image.
r_ClearSprites:
    movem.l ALL_REG, -(sp) *| Push registers to stack

.LoadRegister:
    move.l pixel_clear_zones, a0    ; Current sprite index
    move.l pixel_clear_length, a1   ; End sprite index
    move.l pg_Background, a2        ; Background 

.GetSprite:
    *| Extracting offset into registers for processing.
    move.l (a0), d3                 ; offset: vec2
    
    move.l d3, d2                   ; Separate into two registers

    lsr.l #8, d3                    ; Offset X: int
    lsr.l #8, d3                    ; Will be used as Current X for loop

    and.l #$0000FFFF, d2            ; Offset Y: int
                                    ; Will be used as Current Y for loop

    *| Extracting dimensions to registers for processing
    add.l #2, a0                    ; Push to next long
    move.l (a0), d4                 ; dimensions: vec2
    move.l d4, d5                   ; Separate into two registers

    lsr.l #8, d4                    ; Width: int
    lsr.l #8, d4

    and.l #$0000FFFF, d5            ; Height: int

    *| Get ending x and y positions
    move.l d3, d6                   ; X Offset
    add.l d4, d6                    ; Plus Width
                                    ; = End X Pos
    
    move.l d2, d7                   ; Y Offset
    add.l d5, d7                    ; Plus Height
                                    ; = End Y Pos

*,__________________________________________________,
*| For Loop: for y = Offset Y, y < Offset Y + Height, y++
.ClearSprite:
    *,__________________________________________________,
    *| For Loop: for x = Offset X, x < Offset X + Width, x++
.ClearPixel:
            *| Get Background Pixel
            move.l d2, d1   ; Get offset to pixel address of background.
            sub.l #1, d6    ; y offset - 1
            mulu.w d4, d6   ; multiplied by width
            add.l d3, d6    ; plus X offset
            add.l #1, d6    ; + 1 to account for dimension data in Pixel Grid 
            lsl.l #2, d6    ; Multiplied by size of Long

            move.l a2, a3   ; Add this to the address of the pixel grid
            add.l d6, a3    ; Shifting offset to the desired pixel
            move.l (a3), d1 ; Overwrite d6 to save register space
                            ; d6 now stores the hex color of the pixel
            
.PrintBgPixel:
            *| Note that we set up the previous registers so all data
            *| is in the right location. X is in d3 but will be moved to d1
            *| once the first trap is done.
            move.l #SET_PIXEL_COLOR, d0 ; TRAP Set Pen Color
            move.l d6, d1               ; Get current pixel color
                
            ; TODO: Make backround have no alpha so we can remove this line
            and.l #$00FFFFFF, d1        ; Chop off alpha

            TRAP #15

            move.l d3, d1               ; Move X pos to correct register
                                        ; Y pos is already in correct register.   
                    
            move.l #PRINT_PIXEL, d0     ; TRAP Draw Pixel
        
            TRAP #15

            add.l #1, d0    ; x += 1
            cmp.l d4, d0    ; is x past end x pos?
            ble.l .ClearPixel ; if not, continue parsing pixels
    *| End For Loop

    add.l #1, d1    ; y += 1
    cmp.l d5, d1    ; Is y past end Y pos?
    bls.l .ClearSprite  ; If not, continue to next loop
*| End For Loop

.CheckEndOfSprites:
    cmp.l a0, a1                    ; Is current sprite index at or past end sprite index?
    bls.l .GetSprite                ; If not, let's keep on going.

.Return:

    movem.l (sp)+, ALL_REG  *| Pull registers from stack

    rts
*| [End of Function] ClearSprites
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
