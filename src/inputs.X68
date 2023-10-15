*,__________________________________________________,
*| Inputs                                           |
*| Description: Handles loading any possible input  |
*| from the player                                  |
*|__________________________________________________|
*`                                                  `

*,__________________________________________________,
*| [Inputs] fn GetUserInput
*| Description: Captures all relevant game inputs
i_CaptureInputs:
    movem.l TRAP_REG, -(sp) *| Push registers to stack

    move.l #GET_KEY_INPUT_COMMAND, d0
    move.l #'W'<<24+'A'<<16+'S'<<8+'D', d1   ; WASD Inputs
    
    TRAP #15
    
    move.l d1, d3   ; d3 stores WASD Inputs for later processing
    
    move.l #ENTER<<24+ESC<<16+SHIFT<<8+SPACE, d1   ; Enter, Esc, Shift, and Space Inputs
    
    TRAP #15
    
    move.l d1, d4   ; d4 stores other Inputs for later processing
    
.Return:
    movem.l (sp)+, TRAP_REG *| Pull registers from stack

    rts
*| [End of Function] GetUserInput
*|__________________________________________________
*`                                                  `