*,__________________________________________________,
*| Display                                          |
*| Description: Handles seven-segment displays      |
*|__________________________________________________|
*`                                                  `

SEVEN_SEG_DIMENSIONS    EQU $0012001F

LAP_DISPLAY_OFFSET          EQU $02540014

TIMER_1_DISPLAY_OFFSET      EQU $00050014
TIMER_2_DISPLAY_OFFSET      EQU $001A0014
TIMER_3_DISPLAY_OFFSET      EQU $00370014
TIMER_4_DISPLAY_OFFSET      EQU $004C0014

*,__________________________________________________,
*| fn InitDisplays
*| Description: Loads starting locations and values
*| for each display in the scene
ss_InitDisplays:
    movem.l ALL_REG, -(sp) *| Push registers to stack

    *| Setting up lap counter
    move.l #ssd_Lap, a0
    move.l #LAP_DISPLAY_OFFSET, (a0)
    move.l #1, d0

    jsr ss_SevenSegUpdate

    *| Setting up timer counters, from leftmost to rightmost
    move.l #ssd_Timer, a0
    move.l #TIMER_1_DISPLAY_OFFSET, (a0)
    add.l #6, a0
    move.w #1, (a0)     ; Lap counter starts at 1
    sub.l #6, a0

    jsr ss_SevenSegUpdate

    add.l #8, a0    ; Move a0 to next display in timer
    move.l #0, d0   ; Timer displays all start at 0

    move.l #TIMER_2_DISPLAY_OFFSET, (a0)

    jsr ss_SevenSegUpdate
        
    add.l #8, a0    ; Move a0 to next display in timer

    move.l #TIMER_3_DISPLAY_OFFSET, (a0)

    jsr ss_SevenSegUpdate

    add.l #8, a0    ; Move a0 to next display in timer

    move.l #TIMER_4_DISPLAY_OFFSET, (a0)

    jsr ss_SevenSegUpdate
.Return:
    movem.l (sp)+, ALL_REG  *| Pull registers from stack

    rts
*| [End of Function] SevSegUpdate
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| fn SevSegUpdate
*| Description: Updates a given seven segment display
*| to a new value. Queues the old image to be deleted
*| and marks this image for display.
*| a0: Pointer to target display, d0: new number
ss_SevenSegUpdate:
    movem.l ALL_REG, -(sp) *| Push registers to stack

    ; Get table value
    move.l #SevenSegTable, a1
    add.l d0, a1            ; Offset to bitmask
    move.b (a1), d2

    ; Update bitmask
    move.l a0, a1
    add.l #4, a1            ; Move to next long
    move.w d2, (a1)         ; Move by word to prevent misalignment
    add.l #2, a1            ; Move to next word
    move.w d0, (a1)         ; Put the actual number in for reference

    ; Wipe other old sprites because sprite clearing only works one image at a time (needs fixing!)
    jsr r_ClearSprites

    ; Mark new clear zone
    move.l (a0), d3
    
    move.l pixel_clear_length, a1
    move.l d3, (a1)                     ; Move image offset to pixel_clear_zones
    add.l #4, a1                        ; Move to next word
    move.l #SEVEN_SEG_DIMENSIONS, (a1)  ; Move image dimensions to pixel_clear_zones
    add.l #8, pixel_clear_length        ; Move to next word

    ; Call an early sprite clear
    jsr r_ClearSprites

    ; Print new display value
    *| Note: A lot of this is necessary boilerplate, 
    *| but also consistent across all 7-seg displays.
.PrintSegments:
    move.l #%10000000, d4   ; Starting bit to check
    move.l #0, d1           ; Are not immediately removed
.First:
    move.l d2, d0
    and.l d4, d0
    cmp.l d4, d0
    bne.l .Second           ; Skip to second
    
    move.l d3, d0
    add.l #$00030000, d0    ; + Local Position
    move.l #pg_7SegHorizontal, a0
    jsr r_PrintImage

.Second:    
    lsr.l #1, d4            ; Get next bit to check
    move.l d2, d0
    and.l d4, d0
    cmp.l d4, d0 
    bne.l .Third            ; Skip to third
       
    move.l d3, d0
    add.l #$00000003, d0    ; + Local Position
    move.l #pg_7SegVertical, a0
    jsr r_PrintImage

.Third:
    lsr.l #1, d4            ; Get next bit to check
    move.l d2, d0
    and.l d4, d0
    cmp.l d4, d0 
    bne.l .Fourth           ; Skip to fourth

    move.l d3, d0
    add.l #$000F0003, d0    ; + Local Position
    move.l #pg_7SegVertical, a0
    jsr r_PrintImage

.Fourth:
    lsr.l #1, d4            ; Get next bit to check
    move.l d2, d0
    and.l d4, d0
    cmp.l d4, d0 
    bne.l .Fifth            ; Skip to fifth

    move.l d3, d0
    add.l #$0003000E, d0    ; + Local Position
    move.l #pg_7SegHorizontal, a0
    jsr r_PrintImage

.Fifth:
    lsr.l #1, d4            ; Get next bit to check
    move.l d2, d0
    and.l d4, d0
    cmp.l d4, d0 
    bne.l .Sixth            ; Skip to sixth

    move.l d3, d0
    add.l #$00000010, d0    ; + Local Position
    move.l #pg_7SegVertical, a0
    jsr r_PrintImage

.Sixth:
    lsr.l #1, d4            ; Get next bit to check
    move.l d2, d0
    and.l d4, d0
    cmp.l d4, d0 
    bne.l .Seventh          ; Skip to seventh

    move.l d3, d0
    add.l #$000F0010, d0    ; + Local Position
    move.l #pg_7SegVertical, a0
    jsr r_PrintImage

.Seventh:
    lsr.l #1, d4
    move.l d2, d0
    and.l d4, d0
    cmp.l d4, d0 
    bne.l .Return           ; Skip to end

    move.l d3, d0
    add.l #$0003001C, d0    ; + Local Position
    move.l #pg_7SegHorizontal, a0
    jsr r_PrintImage

.Return:
    movem.l (sp)+, ALL_REG  *| Pull registers from stack

    rts
*| [End of Function] SevSegUpdate
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| IncrementLap
ss_IncrementLap:
    movem.l TRAP_REG, -(sp) *| Push registers to stack

    move.l #ssd_Lap, a0
    add.l #6, a0            ; Offset to actual number
    move.w (a0), d0         ; Grab number
    add.l #1, d0            ; Increment by 1
    cmp.l #3, d0            ; Has its number gone over 3?
    bgt.l .EndGame          ; If so, game over.

    ; Otherwise, let's increment and update
    sub.l #6, a0            ; offset to start of current display
    jsr ss_SevenSegUpdate

    jmp .Return

.EndGame:
    move.w #1, flag_IsDead  ; Game is over!

.Return:
    movem.l (sp)+, TRAP_REG  *| Pull registers from stack
    
    rts
*| [End of Function] SevSegUpdate
*|__________________________________________________
*`                                                  `

SevenSegVerticalBmpFile     INCBIN "../resources/7SegVertical.bmp"
SevenSegHorizontalBmpFile   INCBIN "../resources/7SegHorizontal.bmp"

; A table containing bytes where each bit represents on or off
; for a segment on the display. Table starts at 0 and ends at 9
SevenSegTable       dc.b %11101110,%00100100,%10111010
                    dc.b %10110110,%01110100,%11010110
                    dc.b %11011110,%10100100,%11111110,%11110100

*| Data Type: Seven Segment Display (ssd)
*| $0 = Offset X
*| $2 = Offset Y
*| $4 = Bitmask ; the bitmask representing which bytes to display.
*| $6 = TimeToDisplay?
ssd_Lap         ds.l 2
ssd_Timer       ds.l 8