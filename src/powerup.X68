*,__________________________________________________,
*| Powerup                                          |
*| Description: Handles powerup pickup & use        |
*|__________________________________________________|
*`                                                  `

POWERUP_DIMENSIONS      EQU $00100010

*,__________________________________________________,
*| [Powerup] SpawnPowerup
*| Description: Randomly spawns a new powerup on the map
pwr_SpawnPowerup:
    movem.l ALL_REG, -(sp)  *| Push registers to stack

    move.l #GET_TIME, d0
    TRAP #15

    move.l d1, d0
    moveq #$AF-$100, d1
    moveq #18, d2

.Ninc0:
    add.l d0, d0
    bcc .Ninc1
    eor.b d1, d0

.Ninc1:
    dbf d2, .Ninc0

    ; d0 stores final random number
    and.l #$0000FFFF, d0
    divu.w #5, d0   ; Find rand % 5
    lsr.l #8, d0    ; Only want remainder
    lsr.l #8, d0

    ; d0 now stores the index of the spawn location
.GetLoc: ; Get spawn location
    move.l #arr_PowerupLocations, a0
    lsl.l #2, d0    ; Multiply index by length of element (Long)
    add.l d0, a0

    move.l (a0), d1 ; d1 holds offset to new pickup location

.ClearLast: ; Clears last powerup    
    ; jsr pwr_ClearPowerup
    
    move.l d1, CurrentPowerupLoc ; Now we replace the old value

.PrintSprite:
    move.l d1, d0
    clr.l d1   ; persistent
    move.l #pg_Powerup, a0

    jsr r_PrintImage

.PrintMat:
    move.l d0, d1
    lsr.l #8, d0            ; Current X
    lsr.l #8, d0    
    and.l #$0000FFFF, d1    ; Current Y

    move.l #POWERUP_DIMENSIONS, d6
    move.l d6, d7
    lsr.l #8, d6            ; W
    lsr.l #8, d6
    and.l #$0000FFFF, d7    ; H

    move.l d0, d2
    add.l d6, d2            ; End X

    move.l d1, d3
    add.l d7, d3            ; End Y

    move.l #cm_Road, a0

    *,__________________________________________________,
    *| For Loop: for y = Offset Y, y < Offset Y + Height, y++ 
.MarkRow:
        move.l d1, d4
        mulu.w #SCREEN_WIDTH, d4    ; Current Y times Screen Width (width of collision map)
        add.l d0, d4                ; Then, add x offset

        *,__________________________________________________,
        *| For Loop: for x = Offset X, x < Offset X + Width, x++
.MarkPixel:
            move.l a0, a1   ; Get location in collision map
            add.l d4, a1    ; Stored in bytes

            move.b #4, (a1) ; Replace old material with Road

            add.l #1, d0

            cmp.l d2, d0        ; Are we at end of row?
            blt.l .MarkPixel    ; If not, continue
        *| End For Loop
        
        ; Let's rewind x back to the start
        sub.l d6, d0

        ; Let's push y to the next index
        add.l #1, d1
        cmp.l d3, d1    ; Are we at the end of the chunk?
        blt.l .MarkRow  ; Nope, let's keep on moving

    *| End For Loop

.Return:
    movem.l (sp)+, ALL_REG  *| Pull registers from stack

    rts
*| [End of Function] SpawnPowerup
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Powerup] ClearPowerup
*| Description: Removes the current powerup from the screen
pwr_ClearPowerup:
    movem.l ALL_REG, -(sp)  *| Push registers to stack

    move.l CurrentPowerupLoc, d0
    cmp.l #$FFFFFFFF, d0    ; is powerup location valid?
    beq.l .Return

    move.l pixel_clear_length, a1
    move.l d0, (a1)                     ; Move image offset to pixel_clear_zones
    add.l #4, a1                        ; Move to next word
    move.l #POWERUP_DIMENSIONS, (a1)    ; Move image dimensions to pixel_clear_zones
    add.l #8, pixel_clear_length        ; Move to next word

    ; Call an early sprite clear
    jsr r_ClearSprites

    ; Let's also do the same for the material on the area it was on
.WipeMat:
    move.l d0, d1
    lsr.l #8, d0            ; Current X
    lsr.l #8, d0    
    and.l #$0000FFFF, d1    ; Current Y

    move.l #POWERUP_DIMENSIONS, d6
    move.l d6, d7
    lsr.l #8, d6            ; W
    lsr.l #8, d6
    and.l #$0000FFFF, d7    ; H

    move.l d0, d2
    add.l d6, d2            ; End X

    move.l d1, d3
    add.l d7, d3            ; End Y

    move.l #cm_Road, a0

    *,__________________________________________________,
    *| For Loop: for y = Offset Y, y < Offset Y + Height, y++ 
.WipeRow:
        move.l d1, d4
        mulu.w #SCREEN_WIDTH, d4    ; Current Y times Screen Width (width of collision map)
        add.l d0, d4                ; Then, add x offset

        *,__________________________________________________,
        *| For Loop: for x = Offset X, x < Offset X + Width, x++
.WipePixel:
            move.l a0, a1   ; Get location in collision map
            add.l d4, a1    ; Stored in bytes

            move.b #1, (a1) ; Replace old material with Road

            add.l #1, d0

            cmp.l d2, d0        ; Are we at end of row?
            blt.l .WipePixel    ; If not, continue
        *| End For Loop
        
        ; Let's rewind x back to the start
        sub.l d6, d0

        ; Let's push y to the next index
        add.l #1, d1
        cmp.l d3, d1    ; Are we at the end of the chunk?
        blt.l .WipeRow  ; Nope, let's keep on moving

    *| End For Loop

.Return:
    movem.l (sp)+, ALL_REG  *| Pull registers from stack

    rts
*| [End of Function] ClearPowerup
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Powerup] FuelUp
*| Description: Resets fuel to max
pwr_FuelUp:
    movem.l ALL_REG, -(sp)  *| Push registers to stack

    jsr pwr_ClearPowerup    ; Clear texture & material

.Return:
    movem.l (sp)+, ALL_REG  *| Pull registers from stack

    rts
*| [End of Function] FuelUp
*|__________________________________________________
*`                                                  `



CurrentPowerupLevel dc.l #366

CurrentPowerupLoc  ds.l 1
arr_PowerupLocations  dc.l $004B004B,$00FA00A0,$01540160,$02030118,$022B0046