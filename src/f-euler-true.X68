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

*>Renderer
*| Vectors
SCREEN_WIDTH        EQU 640
SCREEN_HEIGHT       EQU 480

SUBSCREEN_WIDTH     EQU 256
SUBSCREEN_HEIGHT    EQU 224
SUBSCREEN_OFFSET_X  EQU 192
SUBSCREEN_OFFSET_Y  EQU 128

ROAD_SCALE_X        EQU 102 ; Original image width / Image scale (1024/10)
ROAD_SCALE_Y        EQU 102 ; Original image height / Image scale (1024/10)
DEPTH_INTENSITY     EQU $267F   ; Fixed Point 1.15 value of approximately 0.3

*| TRAP Codes
SET_PIXEL_COLOR     EQU 80
PRINT_PIXEL         EQU 82

*,__________________________________________________,
*| fn Main
*| Description: Loads files, sets game state, begins
*|              game loop, and handles quit state
START ORG $1000
    jsr fl_LoadFiles
    
    move.l #$00000000, d3
    move.l #pg_Background, a0
    jsr r_PrintImage
    
    move.l #$00000000, vec2_CameraPos *| Starting at 0, 0

    STOP #$2000
*| [End of Function] Main Function
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Renderer] fn PrintImage
*| Inputs: d3=offset: vec2, a0=image: pixel_grid*
r_PrintImage:        
    ; Set up the starting variables for printing pixels      
    move.l d3, d2
    lsr.l #8, d3            ; Current X
    lsr.l #8, d3
    add.l #1, d3
    and.l #$0000FFFF, d2    ; Current Y
    add.l #1, d2
       
    move.l (a0), d0         ; Image dimensions
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
        
PrintPixel:
    move.l #SET_PIXEL_COLOR, d0  ; TRAP Set Pen Color
    move.l (a0), d1             ; Get current pixel color
        
    TRAP #15
               
    move.l #PRINT_PIXEL, d0      ; TRAP Draw Pixel
    move.l d3, d1               ; Pixel X location must be extracted 
   
    TRAP #15
      
    ; Done printing, let's calculate the next target pixel.
    add.l #4, a0            ; Move pointer to next color pixel
        
    add.l #1, d3            ; Move X to the next column
    cmp.l d6, d3            ; Is X past End X Position?
    bls.l PrintPixel        ; If not, keep on printing
        
    ; Otherwise, we move to the next row
    sub.l d6, d3            ; Move X back to the starting column
    add.l #1, d2            ; Move Y down a row
        
    cmp.l d7, d2            ; Is Y past End Y Position?
    ble.l PrintPixel        ; If not, keep printing.
        
    rts
*| [End of Function] PrintImage
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Renderer] fn AffineRenderer
*| Description: Each frame, this goes over each pixel
*| in the subscreen and does a reverse affine transformation
*| to a reference image of the road image.
*| Inputs: d0=position: vec2, d1=rotation: Word
r_AffineRenderer:
    *| sin of angle
    *| cos of angle
    
    *,________________________________,
    *| for y in 0 to SUBSCREEN_HEIGHT
    move.l #0, d2                   ; d2 = y
    move.l #DEPTH_INTENSITY, r_AffineDepthScale     ; d4 = depth_scale (depth intensity / subscreen height)
    divu.w #SUBSCREEN_HEIGHT, r_AffineDepthScale
AffineRender_GetRows:
        *| Depth scale is increased at the end of each loop. NOT done here.

        *| Variable: Width Ratio
        move.l #SUBSCREEN_WIDTH, d3     *| subscreen width
        mulu.w r_AffineDepthScale, d3   *| multiplied by depth scale
        mulu.w #ROAD_SCALE_X, d3        *| multiplied by road_scale_x
                                        *| We need to adjust fixed point to be 8.8
                                    
        *,________________________________,
        *| for x in 0 to SUBSCREEN_WIDTH
        
        *| Variable: X
        *| Is held in the left word of its long
        *| for easier calculation
        move.l #0, d4 
AffineRender_GetPixels:
            *| Variable: Height Ratio
            move.l #SUBSCREEN_HEIGHT, d4    *| subscreen width
            mulu.w r_AffineDepthScale, d4   *| multiplied by depth scale
            mulu.w #ROAD_SCALE_Y, d4        *| multiplied by road_scale_x
                                            *| We need to adjust fixed point to be 8.8
            
            *,________________________________,
            *| Affine Transformations
            *|
            *| This is the very center of this program. We are
            *| calculating the inverse of an affine transformation,
            *| which is too big to put into the comments here.
            *| Point is, it's too much math to reasonably fit into
            *| the registers, which means everything is going to be
            *| put in the heap.
           
            
            *| Variable: Offset_Vector
            *| Represents the current screen pixel shifted relative
            *| to the center of the projected image
            move.l d0, d5   ; [pos_x, pos_y]
            sub.w d2, d5    ; [pos_x, pos_y - y]
            swap.l d5       ; Flip so that x is on rightmost side
            sub.w d4, d5    ; [pos_x - x, pos_y - y]
            swap.l d5       ; Flip back to normal
            
            
            
            
        *| [End of For Loop]
        *|________________________________
        *`                                `
        
    *| [End of For Loop]
    *|________________________________
    *`                                `

*| [End of Function] AffineRenderer
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| Input Variables
BackgroundBmpFile   INCBIN "../resources/background.bmp"

RoadBmpFile         INCBIN "../resources/road.bmp"
; RoadCollisionFile   INCBIN "../resources/collision.txt"

; ShipBmpFile         INCBIN "../resources/ship.bmp"
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
pg_Road         ds.l 1056785    ; 1 + 1028x1028
pg_Ship         ds.l 257        ; 1 + 16x16
pg_Debris       ds.l 257        ; 1 + 16x16

r_AffineDepthScale  ds.l 1      ; Represents the shrink factor of the image as you go higher up the y-coordinat
*>7-Segment LED
pg_7SegVertical     ds.l 65     ; 1 + 16x4
pg_7SegHorizontal   ds.l 65     ; 1 + 16x4

*| Data Type: Vector 3 (vec3)
*| $0 = X, $2 = Y
*>Physics
vec2_CameraPos  ds.l 1
    
    END    START


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
