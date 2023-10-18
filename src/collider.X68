*,__________________________________________________,
*| Collider                                         |
*| Description: Handles the materials the ship      |
*| is currently on                                  |
*|__________________________________________________|
*`                                                  `

*,__________________________________________________,
*| [Collisions] fn CheckCollisions
*| Description: Checks what material the player is on
cl_CheckCollisions:
    ; Check root of ship location
    move.l d5, d0
    jsr cl_GetCollisionMaterial     ; d0 is now filled with material
    jsr cl_ProcessMaterial

    ; Check top right corner
    move.l d5, d0
    add.l #$000F0000, d0
    jsr cl_GetCollisionMaterial     ; d0 is now filled with material
    jsr cl_ProcessMaterial

    ; Check bottom left corner
    move.l d5, d0
    add.l #$0000000F, d0
    jsr cl_GetCollisionMaterial     ; d0 is now filled with material
    jsr cl_ProcessMaterial

    ; Check bottom right corner
    move.l d5, d0
    add.l #$000F000F, d0
    jsr cl_GetCollisionMaterial     ; d0 is now filled with material
    jsr cl_ProcessMaterial

.Return:

    rts
*| [End of Function] CheckCollisions
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Collisions] fn GetCollisionMaterial
*| Description: Check what material is at a particular pixel address
*| Input: d0: coordintaes (w1: x, w2: y)
cl_GetCollisionMaterial:
    move.l d0, d1
    lsr.l #8, d0            ; X
    lsr.l #8, d0
    and.l #$0000FFFF, d1    ; Y

    mulu.w #SCREEN_WIDTH, d1    ; Y * Screen Width
    add.l d0, d1                ; + X = Index

    move.l #cm_Road, a0
    add.l d1, a0                ; Offset to material

    move.b (a0), d0             ; Grab material
    and.l #$000000FF, d0            ; Cut off leftmost bits

.Return:

    rts
*| [End of Function] GetCollisionMaterial
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| [Collisions] fn ProcessMaterial
*| Description: Check what material is at a particular pixel address
*| Input: d0: material
cl_ProcessMaterial:
.Offroad:
    cmp.l #0, d0    ; Offroad?
    bne.l .Lap

    move.w #1, flag_IsDead  ; You're dead!
    jmp .Return

.Lap:
    cmp.l #2, d0    ; On the lap?
    bne.l .MidLap

    cmp.w #0, flag_CanLap   ; Are we in a valid lap state?
    beq.l .Return           ; If not, invalid

    jsr ss_IncrementLap
    move.w #0, flag_CanLap  ; CanLap = false

    jsr pwr_SpawnPowerup    ; New powerup

    jmp .Return

.MidLap:
    cmp.l #3, d0    ; On the mid-lap?
    bne.l .Powerup

    cmp.w #0, flag_CanLap   ; Are we in a valid lap state?
    bne.l .Return           ; If not, invalid

    move.w #1, flag_CanLap  ; CanLap = true

.Powerup:
    cmp.l #4, d0    ; On powerup?
    bne.l .Return   ; End of custom materials

    jsr pwr_FuelUp

.Return:
    ; No special state for any other material

    rts
*| [End of Function] ProcessMaterial
*|__________________________________________________
*`                                                  `

*| Data Type: Collision Map
*| Each byte represents a single pixel on the screen.
*| Dimension is assumed to be the dimensions of the screen.
*| 0 = off the road, 1 = on the road, 
*| 2 = lap, 3 = mid_lap, 4 = power_up
cm_Road         ds.b 307200 ; 640 x 480