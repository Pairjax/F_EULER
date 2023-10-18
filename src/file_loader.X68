*,__________________________________________________,
*| File Loader                                      |
*| Description: Handles loading of any file type    |
*| into a game-ready state.                         |
*|__________________________________________________|
*`                                                  `

SHIP_BMP_SIZE       EQU 1162    ; The number of bytes betwen each ship file
SHIP_PG_SIZE        EQU 1028     ; The size of a ship sprite in memory

*,__________________________________________________,
*| fn LoadResources
*| Description: Loads every file in the game
fl_LoadFiles:
    *| LoadBitmap(a0=file_root: bitmap*, a1=output_image: pixel_grid*)
    move.l #BackgroundBmpFile, a0   *| file_root
    move.l #pg_Background, a1       *| output_image
    jsr fl_LoadBitmap

    *| LoadBitmap(a0=file_root: bitmap*, a1=output_image: pixel_grid*)
    move.l #SevenSegVerticalBmpFile, a0   *| file_root
    move.l #pg_7SegVertical, a1       *| output_image
    jsr fl_LoadBitmap

    *| LoadBitmap(a0=file_root: bitmap*, a1=output_image: pixel_grid*)
    move.l #SevenSegHorizontalBmpFile, a0   *| file_root
    move.l #pg_7SegHorizontal, a1       *| output_image
    jsr fl_LoadBitmap
    
    *| LoadBitmap(a0=file_root: bitmap*, a1=output_image: pixel_grid*)
    move.l #PowerupBmpFile, a0   *| file_root
    move.l #pg_Powerup, a1       *| output_image
    jsr fl_LoadBitmap

    jsr fl_LoadCollisionMap     ; No inputs needed because there is only one

    jsr fl_LoadShipRotations
    
    rts
*| [End of Function] LoadResources
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| fn LoadShipRotations
*| Description: Loads every ship rotation. Lots of 
*| manual, boring calculations. 
fl_LoadShipRotations:
    move.l #ShipBmpFiles, a0
    move.l #pg_ShipRotations, a1

.LoadBmp:
    jsr fl_LoadBitmap

    add.l #SHIP_BMP_SIZE, a0
    add.l #SHIP_PG_SIZE, a1

    cmp.l #EndShipBmpFiles, a0  ; Are we past the end?
    blt.l .LoadBmp              ; If not, keep on loading.

    rts
*| [End of Function] LoadShipRotations
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| fn LoadBitmap
*| Inputs: file_root: bitmap*, output_image: pixel_grid*
*| Description: Loads a single bitmap
fl_LoadBitmap:
    movem.l ALL_REG, -(sp) *| Push registers to stack

ParseBitmapHeader: ; Gather essential information from the bitmap's header
    ; This will need to be converted to Big Endian later based on the Color Range
    move.l a0, a3
    add.l #$A, a3               ; Offset to pixel array
    move.l (a3), d1
        
    jsr ParseLittleEndianLong
        
    add.l a0, d1
    move.l d1, d4               ; Offset to Pixel Array
        
    move.l a0, a3
    add.l #$12, a3              ; Offset to image width
    move.l (a3), d1             ; Image Width
    jsr ParseLittleEndianLong
    move.l d1, d5
        
    move.l a0, a3
    add.l #$16, a3              ; Offset to image height
    move.l (a3), d1             ; Image Height
    jsr ParseLittleEndianLong
    move.l d1, d6
    
    move.w d5, (a1)             ; Push width & height to pixel grid
    add.l #2, a1
    move.w d6, (a1)
    add.l #2, a1                ; Offset to start of pixel data in pixel grid
        
    add.l #$6, a3
    move.w (a3), d1             ; ColorRange
    rol.w #8, d1

GetBitmapChunks:                ; Get the desired chunks of the bitmap
                                ; Finding starting address
    move.l d6, d0               ; Height (H)
    sub.l #1, d0                ; Sub by 1 to get column H - 1
    move.l d5, d1
    mulu.w d1, d0               ; Multiply by width to get last index of column CY - 1
        
    move.l d0, d1               ; Storing in a separate variable so we can keep the index for other calculations
    lsl.l #2, d1                ; Multiply by size of each pixel (Long Word).
    add.l d4, d1                ; Beginning of Pixel Array + Offset to Chunk Start
    move.l d1, a0               ; Current Pixel Address
        
    ; Finding end-of-row index
    add.l d5, d0                ; Add Chunk Width to push it to the end of the desired chunk's first row.
    lsl.l #2, d0                ; Multiply by size of each pixel (Long Word).
    add.l d4, d0                ; Beginning of Pixel Array + Offset to End-Of-Row
    move.l d0, a2               ; End Of Row Pixel Address
        
    ; Finding ending address
    move.l d4, a3   ; Represents the end row of the chunk's Address.

GetSinglePixel:
    ; Get pixel data
    move.l (a0), d1
        
    jsr ParseLittleEndianLong ; Convert to big endian
    move.l d1, d0   ; Move back to d0 after conversion
       
    move.l d0, d1   ; Red
    lsr.l #8, d1    ; Red is the 3rd element, so we shift it 2 bytes over        
    lsr.l #8, d1    ; Have to cut it in byte increments.
    and.l #$FF, d1  ; Chopping off the channel bits that remain to the left.
    
    move.l d0, d2   ; Green
    lsr.l #8, d2    ; Green is the 2nd element, so we shift it 1 byte.
    and.l #$FF, d2  ; Chopping off the channel bits that remain to the left.
        
    move.l d0, d3   ; Blue
    and.l #$FF, d3  ; Chopping off the channel bits that remain to the left.
        
    ; Shift these bits to the correct location for when we read it in BGR
    lsl.l #8, d3    ; Blue is first, so we're shifting it to the 3rd byte
    lsl.l #8, d3
      
    lsl.l #8, d2    ; Green is next, which goes to the 2nd byte.
        
    ; Red stays in place, now we merge the three variables into one
    and.l #$FF000000, d0
    or.l d1, d0
    or.l d2, d0
    or.l d3, d0
        
    ; Push to BitmapChunk location
    move.l d0, (a1)
        
    ; Move Bitmap Chunk Pointer to next pixel
    add.l #4, a1
        
    ; Move Pixel Array Pointer to the next pixel
    add.l #4, a0            ; Move over 1 pixel
    cmp.l a0, a2            ; Is current Pixel Array Pointer past End of Row?
    bgt.l GetSinglePixel    ; If not, continue the loop 
        
    ; If so, let's move the End of Row to the next row (backwards)
    move.l d5, d0
    lsl.l #2, d0    ; Multiply by size of each index
    sub.l d0, a2
        
    ; Let's also move the Current Pixel Address to the start of the next row.
    move.l d5, d0           ; Move pointer back by 2xImageWidth
    add.l d5, d0
    lsl.l #2, d0
    sub.l d0, a0
        
    ; Have we passed the end of the chunk?
    cmp.l a0, a3            ; Is Current Pixel Address past the index of End of Chunk index?
    ble.l GetSinglePixel    ; If not, continue the loop
        
    ; If so, we've finished sorting.
    movem.l (sp)+, ALL_REG  *| Pull registers from stack

    rts
*| [End of Function] LoadBitmap
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| fn ParseLittleEndianLong
*| Inputs: little_endian: Long
*| Description: Converts a long from big endian to little endian
ParseLittleEndianLong:  ; Simple function to convert d1 LW from Little Endian to Big Endian
    rol.w #8, d1
    swap d1
    rol.w #8, d1
        
    rts
*| [End of Function] ParseLittleEndianLong
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| fn LoadCollisionMap
fl_LoadCollisionMap:
    move.l #RoadCollisionFile, a0
    move.l #cm_Road, a1 ; Start of array

    move.l #0, d0       ; Current index in array

.GetPixelMat:           ; Get pixel material
    move.b (a0), d1 
    
.OffRoad:
    cmp.b #$30, d1      ; Is material offroad?
    bne.l .OnRoad       ; Move to next case

    move.b #0, (a1)
    add.l #1, d0
    add.l #1, a1

.OnRoad:
    cmp.b #$31, d1      ; Is material onroad?
    bne.l .Lap          ; Move to next case

    move.b #1, (a1)
    add.l #1, d0
    add.l #1, a1

.Lap:
    cmp.b #$32, d1      ; Is material lap?
    bne.l .MidLap       ; Move to next case

    move.b #2, (a1)
    add.l #1, d0
    add.l #1, a1

.MidLap:
    cmp.b #$33, d1      ; Is material mid-lap?
    bne.l .End          ; Move to next case

    move.b #3, (a1)
    add.l #1, d0
    add.l #1, a1

.End:
    add.l #1, a0

    cmp.l #307200, d0   ; Are we at end of array?
    blt.l .GetPixelMat  ; Otherwise, let's start it all over again

.Return:
    rts

*| [End of Function] LoadBitmap
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| Input Variables

BackgroundBmpFile   INCBIN "../resources/background.bmp"
PowerupBmpFile      INCBIN "../resources/pickup.bmp"

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

*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
