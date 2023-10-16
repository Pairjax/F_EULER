*,__________________________________________________,
*| Physics                                          |
*| Description: Handles rotation, acceleration,     |
*| velocity and position of player ship             |
*|__________________________________________________|
*`                                                  `

*| Physics
MAX_VELOCITY        EQU $00030000
FP_360              EQU $01680000   ; Hex value for 360 degrees in 16.16 fixed point
FP_22P5             EQU $00168000   ; Hex value for 22.5 degrees in 16.16 fixed point
FP_11P25            EQU $000B4000   ; Hex value for 11.25 degrees in 16.16 fixed point

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

    sub.l #00040000, d2

    jmp .FixAngle

.TurnRight:
    add.l #00040000, d2
    
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

.Accel:
    move.l #$00000001, d1   ; magnitude of acceleration (0.5)

    jmp .Vec

.Decel:
    move.l #$FFFFFFFE, d1   ; magnitude of acceleration (-0.25)

.Vec:  ; Builds a vector of the x and y component
    move.l d2, d0           ; Move angle to register for processing
    add.l #$00B40000, d0    ; Angle should actually be facing the other way, so +180
    
    jsr ph_Sine              ; sin

    ; We're done with WASD inputs so we can now use d3 for operations
    move.l d0, d3           ; Storing sin(theta)
    move.l d2, d0           ; Move angle to d0 again    
    add.l #$00B40000, d0    ; Angle should actually be facing the other way, so +180
    add.l #$005A0000, d0    ; Add pi / 2 to get cosine

    jsr ph_Sine              ;cos

    muls.w d1, d0           ; Multiply both sin and cosine to get x and y component  
    muls.w d1, d3  

    *| X and Y are now in 12.20. We are going to clamp them back down to 4.12
    *| X fix
    lsr.l #8, d0            ; Cut off excess fractional bits
    and.l #$0000FFFF, d0

    lsr.l #8, d3            ; Cut off excess fractional bits
    and.l #$0000FFFF, d3

    lsl.l #8, d3            ; Move x component to the left side
    lsl.l #8, d3

    or.l d3, d0         ; Merge together into a single vector.
    add.l d0, d7        ; Add to existing acceleration

    jmp .Clamp

.Fric:
    move.l d7, d0           ; Move accel to another register for value extraction
    
    lsr.l #8, d0            ; x component
    lsr.l #8, d0
    lsr.l #1, d0            ; Divide by two

    and.l #$0000FFFF, d7    ; y component
    lsr.l #1, d7            ; Divide by two

    or.l d0, d7            ; New acceleration

.Clamp: ; clamps acceleration - TODO

.Return:
    movem.l (sp)+, TRAP_REG  *| Pull registers from stack

    rts
*| [End of Function] CalculateAcceleration
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Physics] fn CalculateVelocity
*| Description: Take acceleration and use it to calculate velocity
ph_CalculateVelocity:
    movem.l TRAP_REG, -(sp)  *| Push registers to stack
    
    move.l d7, d0
    lsr.l #4, d0            ; Shift everything to chop off excess fractionals
    and.l #$0FFF0FFF, d0    ; Chop off hanging fractional on y vector
    
    move.l d0, d1           ; Case: Was X or Y negative? 
.xNeg:
    and.l #$08000000, d1    ; X case
    cmp.l #$08000000, d1    ; was X negative? (was leftmost bit 1?)
    bne.l .yNeg


    
.yNeg:


.Fric: ; Apply friction to slow the vehicle down

.Apply:
    *| ClampVector(d0=magnitude_sqr: word, d1=vector) -> d1=clamped_vector
    move.l d6, d1
    move.l #$00000001, d0   *| Max of 1

    jsr ph_ClampVector
    
    move.l d1, d6

.Return:
    movem.l (sp)+, TRAP_REG  *| Pull registers from stack

    rts
*| [End of Function] CalculateVelocity
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Physics] fn CalculatePosition
*| Description: Take velocity and use it to calculate position
ph_CalculatePosition:
    movem.l TRAP_REG, -(sp)  *| Push registers to stack

    move.l d6, d0
    lsr.l #8, d0            ; Shift everything to chop off fractionals
    and.l #$00FF00FF, d0    ; Chop off remaining fractionals

    add.l d0, d5

.Return:
    movem.l (sp)+, TRAP_REG  *| Pull registers from stack

    rts
*| [End of Function] CalculatePosition
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Physics] fn ClampNumber
*| Description: Clamp a word between two values
*| Inputs: d0: value to clamp, d1: left word min, right word max
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
    lsl.l #1, d1
    and.l #$FFFF7FFF, d1    ; Cut off hanging bit at 9th bit

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
    lsr.l #8, d0
    lsr.l #8, d0        ; Chopping off fractional

    cmp.l #90, d0       ; Is the angle greater than 90?
    blt.l .Q1           ; If not, we're in quadrant 1
    
    cmp.l #180, d0      ; Is the angle greater than 180?
    blt.l .Q2           ; If not, we're in quadrant 2

    cmp.l #270, d0      ; Is the angle greater than 270?
    blt.l .Q3           ; If not, we're in quadrant 3
    
    jmp .Q4             ; We are in quadrant 4 by process of elimination

.Q1:    ; Quadrant 1
    lsl.l #1, d0        ; Multiply by 2 (length of word)

    move.l #sinTable, a0
    add.l d0, a0        ; Offset to desired index of sin table

    move.w (a0), d0     ; Extract fractional

    jmp .Return

.Q2:    ; Quadrant 2
    sub.l #90, d0       ; Start at 90 degrees
    lsl.l #1, d0        ; Multiply by 2 (length of word)

    move.l #sinTable, a0
    add.l #SINTABLESIZE, a0 ; Moving index to end of array since we're working backwards
    sub.l d0, a0        ; Offset to desired index of sin table (backwards)

    move.w (a0), d0     ; Extract fractional

    jmp .Return

.Q3:    ; Quadrant 3
    sub.l #180, d0       ; Start at 180 degrees
    lsl.l #1, d0        ; Multiply by 2 (length of word)

    move.l #sinTable, a0
    add.l d0, a0        ; Offset to desired index of sin table

    move.w (a0), d0     ; Extract fractional
    neg.w d0            ; Flip to negative

    jmp .Return

.Q4:    ; Quadrant 4
    sub.l #270, d0       ; Start at 90 degrees
    lsl.l #1, d0         ; Multiply by 2 (length of word)

    move.l #sinTable, a0
    add.l #SINTABLESIZE, a0 ; Moving index to end of array since we're working backwards
    sub.l d0, a0        ; Offset to desired index of sin table (backwards)

    move.w (a0), d0     ; Extract fractional

    neg.w d0            ; Flip to negative

.Return:

    rts
*| [End of Function] Sine
*|__________________________________________________
*`                                                  `

*| Sin table used for sin calculations. Each element is the output of
*| sine() in 4.12 fixed point for a single degree, starting at 0 and ending at 360
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

SINTABLESIZE            EQU 180 ; 90 * 2 (word size)
*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
