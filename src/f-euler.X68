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

GET_TIME            EQU 8

SWAP_BUFFER         EQU 94

*,__________________________________________________,
*| Includes
    INCLUDE "./file_loader.x68"   ; Handles loading of files during preload phase
    INCLUDE "./renderer.x68"      ; Handles printing sprites & affine transformations.
    INCLUDE "./inputs.x68"        ; Handles player inputs for processing
* INCLUDE "./gameplay.x68"        ; Handles in-game timer, lap counter, and game states
    INCLUDE "./physics.x68"       ; Calculates player acceleration, velocity, and collisions.
    INCLUDE "./display.x68"       ; Displays a 7-segment LED with the given parameters.
    INCLUDE "./collider.x68"      ; Handles the materials the ship is currently on

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
    move.l #$00000000, d2
    move.l #pg_Background, a0
    jsr r_PrintImage
    
    jsr ss_InitDisplays
    
    ; Set up start variables for game loop
    move.l #$0221012C, d5   ; Start position of ship

    move.l #GET_TIME, d0    ; Get current time (start of game time)
    TRAP #15

    move.l d1, LastSecond    ; This time is the start of the game

    jsr pwr_SpawnPowerup

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
*| d2: Rotation, DeltaTime 
*| d3: WASD Inputs, d4: Enter, Esc, Shift, and Space Inputs
*| d5: Position, d6: Velocity, d7: Acceleration
*| a3: Ship model to use
GameLoop:
    move.l #8, d0  ; Time Code - maybe reuse later?

    TRAP #15

    jsr UpdateTimer         ; Updates the in-game timer if a second has passed

    move.l d1, d0
    sub.l LastTime, d0
    cmp.l #5, d0            ; Is time elapsed less than 5/100ths of a second?
    bls.l GameLoop          ; If not, wait
    move.l d1, LastTime     ; Otherwise, this is the new last time

    *,___________________________,
    *| STAGE ONE: Capture Inputs |
    *|___________________________|
    *`                           ` 
    jsr i_CaptureInputs   ; Fills registers d3-d4 (destructively) with player inputs

    *,___________________________,
    *| STAGE TWO: Physics Pass   |
    *|___________________________|
    *`                           `
    jsr ph_CalculateRotation
    jsr ph_SelectShipRotation

    jsr ph_CalcVelMagnitude
    jsr ph_CalcVelDir
    jsr ph_CalculatePosition

    jsr cl_CheckCollisions

    *,___________________________,
    *| STAGE THREE: Rendering    |
    *|___________________________|
    *`                           `
    ; Clear old sprites from screen
    jsr r_ClearSprites ; Wipe sprites from screen

    ; Render ship
    ; move.l #pg_Ship, a0
    move.l a3, a0   ; Move ship image address to the correct location
    move.l d5, d0   ; Move position to offset
    jsr r_PrintImage

    ; Swap Buffer
    jsr SwapBuffer

    cmp.w #1, flag_IsDead   ; did player die?
    beq.l .Return  ; If so, end loop

    and.l #$00FF0000, d4
    cmp.l #$00FF0000, d4    ; Did player press ESC?
    beq.l .Return  ; If so, continue loop

    jmp GameLoop

.Return:

    rts
*| [End of Function] GameLoop
*|__________________________________________________
*`                                                  `

*,__________________________________________________,
*| fn UpdateTimer
*| Description: Checks if a second has passed to update
*| the timer
*| Inputs: d1: Current Time
UpdateTimer:
    movem.l ALL_REG, -(sp)  *| Push registers to stack

    move.l d1, d0
    sub.l LastSecond, d0
    cmp.l #100, d0          ; Is time elapsed 1 second?
    bls.l .Return            ; If not, carry on as normal

    move.l d1, LastSecond   ; Otherwise, we're now in the next second

    clr.l d0                ; clear d0 for next step

    move.l #ssd_Timer, a0   ; Let's now update the timer
    add.l #24, a0           ; Offset to 4th display (00:0X)

.AddSecond:
    add.l #6, a0            ; Offset to actual number
    move.w (a0), d0         ; Grab number
    add.l #1, d0            ; Increment by 1
    cmp.l #9, d0            ; Has its number gone over 9?
    ble.l .EndOverflow      ; If not, we're done.

    ; Otherwise, we overflow to the next display
    sub.l #6, a0            ; offset to start of current display
    move.l #0, d0           ; New number in display must be 0
    jsr ss_SevenSegUpdate

    sub.l #8, a0            ; offset to start of last display
    jmp .AddSecond          ; Continue loop

.EndOverflow:
    sub.l #6, a0            ; Offset back to start of display addr
    jsr ss_SevenSegUpdate   ; Print this display's new number

.Return:
    movem.l (sp)+, ALL_REG  *| Pull registers from stack

    rts
*| [End of Function] UpdateTimer
*|__________________________________________________
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
    divu.w #5, d0   ; Find rand % 5
    lsr.l #8, d0    ; Only want remainder
    lsr.l #8, d0

    ; d0 now stores the index of the spawn location
.GetLoc: ; Get spawn location
    move.l #arr_PowerupLocations, a0
    lsl.l #4, d0    ; Multiply index by length of element (Long)
    add.l d0, a0

    move.l (a0), d1 ; d1 holds offset to new pickup location

    move.l d1, CurrentPowerupLoc

.ClearLast: ; Clears last powerup    
    jsr pwr_ClearPowerup

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

*,__________________________________________________,
*| Global Variables
LastTime    ds.l 1  ; Stores the last frame's start time
LastSecond   ds.l 1  ; Stores the time the game started

*| Flag (0 is false, >0 is true)
flag_IsDead         dc.w $0
flag_IsBoosting     dc.w $0
flag_CanLap         dc.w $0
    
CurrentPowerupLoc  ds.l 1
arr_PowerupLocations  dc.l $004B004B,$00FA00A0,$01540160,$02030118,$022B0046

    END    START

*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
