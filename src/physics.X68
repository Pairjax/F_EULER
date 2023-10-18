*,__________________________________________________,
*| Physics                                          |
*| Description: Handles rotation, acceleration,     |
*| velocity and position of player ship             |
*|__________________________________________________|
*`                                                  `

*| Physics
MAX_VELOCITY        EQU $00400000
FP_360              EQU $01680000   ; Hex value for 360 degrees in 16.16 fixed point
FP_180              EQU $00B40000   ; Hex value for 180 degrees in 16.16 fixed point
FP_45               EQU $002D0000   ; Hex value for 45 degrees in 16.16 fixed point
FP_22P5             EQU $00168000   ; Hex value for 22.5 degrees in 16.16 fixed point
FP_11P25            EQU $000B4000   ; Hex value for 11.25 degrees in 16.16 fixed point

ACCEL_AMOUNT        EQU $00000100   ; Increases speed at 0.125 pixels per frame 
DECEL_AMOUNT        EQU $00000100   ; Increases speed at 0.0625 pixels per frame 

BOOST_SPEED         EQU $00010000
MAX_SPEED           EQU $00004000

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

    sub.l #1, d2

    jmp .FixAngle

.TurnRight:
    add.l #1, d2
    
.FixAngle:
    cmp.l #15, d2       ; Is d2 greater than 360?
    bgt.l .AngleOver
    cmp.l #0, d2            ; Is d2 negative?
    blt.l .AngleUnder

    jmp .Return

.AngleOver:
    sub.l #16, d2          

    jmp .Return

.AngleUnder:
    add.l #16, d2

.Return:
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

    move.l d2, d0
    add.l #8, d0

    cmp.l #15, d0       ; Is d2 greater than 360?
    ble.l .GetFile

.AngleOver:
    sub.l #16, d0

.GetFile:
    mulu.w #1028, d0     ; Multiply by size of ship's pixel grid
    add.l #pg_ShipRotations, d0
    move.l d0, a3

.Return
    movem.l (sp)+, TRAP_REG  *| Pull registers from stack

    rts
*| [End of Function] SelectShipRotation
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Physics] fn CalculateVelocityMagnitude
*| Description: Takes W & S inputs to calculate velocity magnitude
ph_CalcVelMagnitude:
    movem.l TRAP_REG, -(sp)  *| Push registers to stack

    move.l d3, d0           ; Copying WASD inputs to extract A & D
    move.l d0, d1

    lsr.l #8, d0            ; W key input
    lsr.l #8, d0
    lsr.l #8, d0

    lsr.l #8, d1            ; S key input
    and.l #$000000FF, d1    

    cmp.l d0, d1            ; Are S & S both pressed or not pressed?
    beq.l .Fric             ; If so, let's apply friction.

    cmp.l #0, d0            ; Are we accelerating?
    beq.l .Decel            ; If not, then we must be decelerating. 

.Accel: ; Move forwards
    add.l #ACCEL_AMOUNT, d7 

    ; if boosting, add more?

    jmp .Clamp

.Decel: ; Move backwards
    sub.l #DECEL_AMOUNT, d7 

.Clamp:
.ClampMin:
    cmp.l #0, d7    
    bge.l .ClampMax

    move.l #0, d7

    jmp .Return

.ClampMax:
    cmp.l #MAX_SPEED, d7
    ble.l .Return

    move.l #MAX_SPEED, d7

    jmp .Return

.Fric:  ; Return to 0 over time while not boosting
    asr.l #1, d7
    cmp.l #$FFFFFFFF, d7    ; Is d7 at its lowest possible value?
    bne.l .Return           ; If not, skip this next step

    move.l #0, d7           ; Return to 0 rather than being stuck at almost -0

.Return:
    movem.l (sp)+, TRAP_REG  *| Pull registers from stack

    rts
*| [End of Function] CalculateVelocityMagnitude
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Physics] fn CalculateVelocityDirection
*| Description: Takes rotation & velocity magnitude to find vector of move direction
ph_CalcVelDir:
    movem.l TRAP_REG, -(sp)  *| Push registers to stack

    move.l d2, d0           ; Move angle to register for processing.
    
.Sin:
    jsr ph_Sine             ; sin

    ; We're done with WASD inputs so we can now use d3 for operations
    move.l d0, d3           ; Storing sin(theta)
    move.l d2, d0           ; Move angle to d0 again    
    add.l #4, d0            ; Add pi / 2 to get cosine

.FixAngle:
    cmp.l #16, d0           ; Is d2 greater than 360?
    bgt.l .AngleOver

    jmp .Cos

.AngleOver:
    sub.l #16, d0

.Cos:
    jsr ph_Sine             ; cos

    ; Now d3 holds sin(theta) and d0 holds cos(theta)

    ; Multiply velocity magnitude by x component
    move.l d7, d6
    lsr.l #8, d6
    and.l #$0000FFFF, d6

    muls.w d3, d6   ; d6 now holds 8.8 x component
    lsr.l #8, d6
    and.l #$0000FFFF, d6 ; Reduce to 4.4
    neg.w d6

    move.l d6, d3   ; Store x component in d3
    lsl.l #8, d3
    lsl.l #8, d3    ; Move over to left side for eventual merge

    ; Multiply velocity magnitude by y component    
    move.l d7, d6
    lsr.l #8, d6
    and.l #$0000FFFF, d6
    
    muls.w d0, d6   ; d5 now holds 8.8 y component
    lsr.l #8, d6
    and.l #$0000FFFF, d6 ; Reduce to 4x4
    move.l d6, d0   ; Store y component in d0
    
    or.l d3, d0 ; Merge x and y to form final vector

    move.l d0, d6   ; Move final result to final location for processing

.Return:
    movem.l (sp)+, TRAP_REG  *| Pull registers from stack

    rts
*| [End of Function] CalculateVelocityDirection
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Physics] fn CalculatePosition
*| Description: Take velocity and use it to calculate position
ph_CalculatePosition:
    movem.l TRAP_REG, -(sp)  *| Push registers to stack

    move.l d6, d0
    move.l d0, d1

    lsr.l #8, d0
    lsr.l #8, d0
    and.l #$0000FFFF, d1

.negX:
    cmp.w #0, d0    ; Is d0 less than zero?
    bge.l .posX 

    neg.w d0

    ; If so, let's transform to 16.16 
    lsl.l #8, d0
    neg.l d0

    jmp .negY

.posX:
    lsl.l #8, d0

.negY:
    cmp.w #0, d1    ; Is d1 less than zero?
    bge.l .posY

    neg.w d1

    ; If so, let's transform to 16.16 
    lsl.l #8, d1
    neg.l d1

    jmp .updatePos

.posY:
    lsl.l #8, d1

.updatePos:
    ; Update precise ship position
    move.l #ShipPosition, a4

    add.l (a4), d0  ; Ship X Position 
    add.l #4, a4
    add.l (a4), d1  ; Ship Y Position

    move.l d1, (a4)
    sub.l #4, a4
    move.l d0, (a4)

    ; Now, update integer ship position (pixel)

    and.l #$FFFF0000, d0    ; X is already in position
    lsr.l #8, d1            ; Y is shifted right, for once.
    lsr.l #8, d1

    or.l d0, d1

    move.l d1, d5

.Return:
    movem.l (sp)+, TRAP_REG  *| Pull registers from stack

    rts
*| [End of Function] CalculatePosition
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Physics] fn ClampNumber
*| Description: Clamp a word between two values
*| Inputs: d0: value to clamp, d1: min, d3: max
*| Returns: d0: clamped value
ph_ClampNumber:
    move.l d2, -(sp) ; Temporarily move d2 out of the way

    move.l d1, d2
    lsr.l #8, d1
    lsr.l #8, d1
    and.l #$0000FFFF, d2

    *| Compare by word here because it is signed 
    cmp.w d1, d0    ; Is value less than min?
    blt .Under    
    
    cmp.w d2, d0    ; Is value greater than max?
    bgt.l .Over

    jmp .Return     ; Within range, do nothing

.Under:     ; We need to clamp value to min
    move.l d1, d0

    jmp .Return

.Over:      ; We need to clamp value to max
    move.l d2, d0

    jmp .Return

.Return:
    move.l (sp)+, d2

    rts
*| [End of Function] ClampNumber
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Physics] fn ClampVector
*| Description: Clamp a vector to a maximum absolute magnitude
*| Inputs: d0: maximum magnitude squared, d1: coordinates: vec2
*| Returns: d1: Clamped vector
ph_ClampVector:
    move.l d2, -(sp)    ; Temporarily move d2 out of the way
    move.l d3, -(sp)    ; Temporarily move d3 out of the way

    move.l d1, d2       ; Extract X & Y value of vector
    move.l d2, d3
    lsr.l #8, d2
    lsr.l #8, d2
    and.l #$0000FFFF, d3

    muls.w d2, d2   ; x ^ 2
    muls.w d3, d3   ; y ^ 2
    add.l d2, d3    ; x ^ 2 + y ^ 2 = c ^ 2

    ; (x ^ 2) + (y ^ 2) must be converted from 16.16 to 8.8
    lsr.l #8, d3
    and.l #$0000FFFF, d3

    cmp.l d0, d3    ; Is magnitude greater than max?
    ble.l .Return   ; If not, carry on as usual

    ; If so, let's CUT IT IN HALF muahahaha
    move.l d1, d2

    lsr.l #8, d2
    lsr.l #8, d2
    and.l #$0000FFFF, d1
    
    asr.w #1, d2            ; X
    asr.w #1, d1            ; Y
    
    lsl.l #8, d2
    lsl.l #8, d2

    or.l d2, d1

.Return:
    move.l (sp)+, d3
    move.l (sp)+, d2

    rts
*| [End of Function] ClampVector
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Physics] fn Sine
*| Description: Takes an 8.8 number and finds the
*| closets sin value for it.
*| Input: d0: fixed16.16
*| Returns: d0: fixed4.12
ph_Sine:
    cmp.l #8, d0        ; Is the angle greater than 180?
    blt.l .Pos          ; If not, we're in quadrant 1-2
    
    jmp .Neg            ; We are in quadrant 4 by process of elimination

.Pos:    ; Quadrant 1 & 2
    lsl.l #1, d0        ; Multiply by 2 (length of word)

    move.l #sinTable, a0
    add.l d0, a0        ; Offset to desired index of sin table

    move.w (a0), d0     ; Extract fractional

    jmp .Return

.Neg:    ; Quadrant 3 & 4
    sub.l #8, d0        ; Start at 180 degrees
    lsl.l #1, d0        ; Multiply by 2 (length of word)

    move.l #sinTable, a0
    add.l d0, a0        ; Offset to desired index of sin table

    move.w (a0), d0     ; Extract fractional
    neg.w d0            ; Flip to negative

    jmp .Return

.Return:

    rts
*| [End of Function] Sine
*|__________________________________________________
*`                                                  `

*| Sin table used for sin calculations. Each element is the output of
*| sine() in 4.12 fixed point for a single degree, starting at 0 and ending at 180
sinTable        dc.w    $0,$61F,$B50,$EC8
                dc.w    $1000,$EC8,$B50,$61F

SINTABLESIZE            EQU 180 ; 90 * 2 (word size)

ShipPosition        dc.l $02210000,$012C0000  ; Position in 16.16 fixed point

*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
