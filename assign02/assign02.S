#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified                      @ Specify unified assembly syntax
.cpu    cortex-m0plus                @ Specify CPU type is Cortex M0+
.thumb                               @ Specify thumb assembly for RP2040
.global main_asm                     @ Provide program starting address to the linker
.align 4                             @ Specify code alignment

.equ DFLT_STATE_STRT, 1              @ Specify the value to start flashing
.equ DFLT_STATE_STOP, 0              @ Specify the value to stop flashing
.equ DFLT_ALARM_TIME, 1000000        @ Specify the default alarm timeout
.equ GPIO_BTN_FALL_MSK, 0x00400000   @ Bit-22 for falling-edge event on GP21
.equ GPIO_BTN_RISE_MSK, 0x00800000   @ Bit-23 for rising-edge event on GP21
.equ GPIO_BTN_EN, 21                 @ Specify pin for push-button for the game
.equ GPIO_DIR_IN, 0                  @ Specify input direction for a GPIO pin
.equ GPIO_ISR_OFFSET, 0x74           @ GPIO is int #13 (vector table entry 29)
.equ ALARM_ISR_OFFSET, 0x40          @ ALARM0 is int #0 (vector table entry 16)
.equ ALARM0, 0x1                     @ ALARM0, bit-0
.equ GPIO, 0x2000                    @ GPIO, bit-13
.equ TWO_ALARM_TIME, 1000000         @ Specify the 2 seconds alarm timeout
.equ ONE_ALARM_TIME, 50000           @ Specify the 1 second alarm timeout  
.equ MEMORY, 0x10100450              @ Address where the morse string will be stored

@ Entry point to the ASM portion of the program
main_asm:
    ldr     r7, =1                   @ Sets r7 to the value 1, to test the falling-edge event on GP21
    bl      init_gpio_btn_gp21       @ Initialise GP21 push-button
    bl      install_gpio_isr         @ Install the GPIO interrupt service routine
    bl      install_alarm_isr        @ Install the ALARM interrupt service routine
loop:
    wfi                              @ Wait here for interrupt to be triggered
    b       loop                     @ Infinite loop

@ Subroutine used to intialise the PI Pico built-in button GP21
init_gpio_btn_gp21:
    push    {lr}                     @ push the link register, to save the return address
    movs    r0, #GPIO_BTN_EN         @ This is the value of the GPIO button on the PI PICO board
    bl      asm_gpio_init            @ Call the subroutine to initialise the GPIO button specified by r0
    movs    r0, #GPIO_BTN_EN         @ This is the value of the GPIO button on the PI PICO board
    movs    r1, #GPIO_DIR_IN         @ We want this GPIO button to be setup as an input
    bl      asm_gpio_set_dir         @ Call the subroutine to set the GPIO button specified by r0 to state specified by r1
    movs    r0, #GPIO_BTN_EN         @ This is the value of the GPIO button on the PI PICO board
    bl      asm_gpio_set_irq         @ Enables falling-edge & rising-edge interrupt
    pop     {pc}                     @ pop's the saved information, so that it can return to the next instruction immediately after the calling point

@ Subroutine used to install the GPIO interrupt service handler
install_gpio_isr:
@ part of it's functionality should be to clear the pending interrupt that it is servicing before it completes
    @ copy the address of the new ISR to the appropriate interrupt service handler 
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)                     @ This is CORTEX-M0+ internal peripherals & the offset address for the vector table - determines vector location
    ldr     r1, [r2]                                                 @ the vector location stored at address [r2] is loaded into register r1
    movs    r2, #GPIO_ISR_OFFSET                                     @ This is the location of the GPIO with entry 29 - GPIO is int #13 (vector table entry 29)
    add     r2, r1                                                   @ Adds the location of the GPIO entry address to the vector table & loads it into r2
    ldr     r0, =gpio_isr                                            @ loads the address of the GPIO interrupt service handler subroutine into r0
    str     r0, [r2]                                                 @ stores the address of the subroutine found in r0 to the memory address of the vector table
    @ disable the specific interrupt level by writing to the appropriate bit in (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)                @ loads the offset address for the NVIC Interrupt Clear Pending register into r2
    ldr     r1, =#GPIO                                               @ loads GPIO's bit-13 into r1 
    str     r1, [r2]                                                 @ writes the approriate bit value back to the address of (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET) that is in r2
    @ enable the specific interrupt level by writing to the appropriate bit in (PPB_BASE + M0PLUS_NIVC_ISER_OFFSET)
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)                @ loads the offset address for the NVIC Interrupt Set Enable register into r2 
    ldr     r1, =#GPIO                                               @ loads GPIO's bit-13 in into r1
    str     r1, [r2]                                                 @ writes the appropriate bit value back to the address of (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET) that is in r2
    bx      lr                                                       @ branch back to link register address

@ Subroutine used to install the ALARM interrupt service handler
install_alarm_isr:
@ part of it's functionality should be to clear the pending interrupt that it is servicing before it completes
    @ copy the address of the new ISR to the appropriate entry in the vector table
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)                       @ This is CORTEX-M0+ internal peripherals & the offset address for the vector table - determines vector location
    ldr     r1, [r2]                                                   @ the vector location stored at address [r2] is loaded into register r1
    movs    r2, #ALARM_ISR_OFFSET                                      @ This is the location of the ALARM with entry number 16 - ALARM is int #0 (vector table entry 16)
    add     r2, r1                                                     @ Adds the location of the ALARM entry address to the vector table & loads it into r2
    ldr     r0, =alarm_isr                                             @ loads the address of the ALARM interrupt service handler subroutine into r0
    str     r0, [r2]                                                   @ stores the address of the subroutine found in r0 to the memory address of the vector table
    @ disable the specific interrupt level by writing to the appropriate bit in (PPB_BASE + M0PLUS_ICPR_OFFSET) 
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)                  @ loads the offset address for the NVIC Interrupt Clear Pending register into r2
    ldr     r1, =#ALARM0                                               @ loads ALARM's bit-0 into r1
    str     r1, [r2]                                                   @ writes the appropriate bit value back to the address of (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET) that is in r2
    @ enable the specific interrupt level by writing to the appropriate bit in (PPB_BASE + M0PLUS_ISER_OFFSET)
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)                  @ loads the offset address for the NVIC Interrupt Set Enable register into r2
    ldr     r1, =#ALARM0                                               @ loads ALARM's bit-0 into r1
    str     r1, [r2]                                                   @ writes the appropiate bit value back to the address of (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET) that is in r2
    bx      lr                                                         @ branch back to link register address

@ GPIO interrupt service handler routine
.thumb_func                                                            @ Required for all interrupt service routines
gpio_isr:
    push    {lr}                                                       @ push the link register, to save the return address
    @ Button has been pressed
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)         @ loads the address for GPIO and the offset address for the GPIO interrupt status #2 register into r2
    ldr     r1, [r2]                                                   @ loads the value in address r2 into r1
    ldr     r2, =#GPIO_BTN_FALL_MSK                                    @ loads bit-22 for falling-edge event on GP21 into r2                                
    cmp     r1, r2                                                     @ checks if the GP21 button has been pressed
    beq     start_timer                                                @ branch to the subroutine to check the flashing state for GP21
    @ Button has been released - we need to know how long it has been pressed for morse code & length between presses to know which morse code pattern to input
    @ time between presses
    ldr     r2, =#TIMER_BASE                                           @ loads the base address for the timer component into r2
    ldr     r3, =#TIMER_INTR_OFFSET                                    @ loads the offset address for the TIMER raw interrupts register into r3
    ldr     r4, [r2, r3]                                               @ current timer after the button has been released
    subs    r0, r4, r2                                                 @ subtract the time of press from the time of release, to find out the duration of the press
    /*        INPUT TO MORSE CODE SEQUENCE - START        */ 
    // check if something was input before at least one second
morse_code_sequence:
    ldr     r2, =ONE_ALARM_TIME                                        @ loads the value of one second into r2
    cmp     r5, r2                                                     @ if the time between presses is greater than one second
    blt     input_space                                                @ branch to input a space character
    cmp     r0, r2                                                     @ if the button press is less than one second, then we will input a dot
    blt     input_dot                                                  @ branch to subroutine to input a dot into the morse code sequence 
    movs    r0, #45                                                    @ ASCII value for the "dash" (aka: hyphen) character, that we want to input into our morse code sequence 
    b       add_reset                                                  @ branch to code to add the ASCII character into the morse code sequence and reset the timer
input_dot:
    movs    r0, #46                                                    @ ASCII value for the "dot" character, that we want to input into our morse code sequence
    b       add_reset                                                  @ branch to code to add the ASCII character into the morse code sequence and reset the timer
input_space:
    movs    r0, #32                                                    @ ASCII value for the "space" character, that we want to input into our morse code sequence
add_reset:
    bl      addSymbolToAnswer                                          @ call c function to add the ASCII character in r0 to the morse code sequence
    bl      reset_timer                                                @ branch to subroutine to reset the timer for next press
    b       clear_button_release                                       @ branch to clear interrupt for rising-edge event on GP21
start_timer:
    ldr     r2, =#TIMER_BASE                                           @ loads the base address for the timer component into r2
    ldr     r3, =#TIMER_INTR_OFFSET                                    @ loads the offset address for the TIMER raw interrupts register into r3
    ldr     r2, [r2, r3]                                               @ current timer count when button is first pressed is now in r2
    cmp     r7, #1                                                     @ if this is the first time the button has been pressed we clear it as now we only need to focus on the rising-edge (release times)
    beq     clear_button_press                                         @ clear interrupt for falling-edge event on GP21
    subs    r5, r2, r4                                                 @ subtract the time of the last release with the current press to find out the time between presses
    b       clear_button_release                                       @ clear interrupt for rising-edge event on GP21
reset_timer:                                    
    ldr     r6, =DFLT_STATE_STRT                                       @ loads the value 1 into r6
    ldr     r2, =#TIMER_BASE                                           @ loads the base address for the timer component into r2
    ldr     r1, =#ALARM0                                               @ bit-0 for ALARM0           
    ldr     r3, =#TIMER_INTE_OFFSET                                    @ loads the offset address for the TIMER raw interrupt enable register into r3
    str     r1, [r2, r3]                                               @ writes the appropriate bit value back to the TIMER's offset address interrupt enable register that is in r3 and the base address that is in r2
    ldr     r3, =#TIMER_TIMELR_OFFSET           	                   @ loads the offset address for the lower 32-bits of the timer register into r3
    ldr     r1, [r2, r3]                                               @ loads the address of r3 and r2 into r1
    add     r1, r5                                                     @ add the time between presses in r5 with the appropriate bit value of ALARM0 bit-0, which is in r1 and store the result in r1
    ldr     r3, =#TIMER_ALARM0_OFFSET                                  @ loads the offset address for the ALARM0 control register into r3
    str     r1, [r2, r3]                                               @ write the value in r1 back to the base address that is in r2 and the offset address that is in r3
    /*        INPUT TO MORSE CODE SEQUENCE - END         */ 
clear_button_release:
    ldr     r1, =#GPIO_BTN_RISE_MSK                                    @ loads the bit for the rising-edge event on GP21
    b       end_gpio                                                   @ branch to clear interrupt for rising-edge event on GP21
clear_button_press:
    movs    r6, #0                                                     @ no longer looking at falling-edge so set to one so we can focus on the rising-edge cases
    ldr     r1, =#GPIO_BTN_FALL_MSK                                    @ loads bit for rising-edge event on GP21 into r1
    b       end_gpio                                                   @ loads bit-22 for falling-edge event on GP21 into r1
end_gpio:
    @ clear GP21 interrupt
    ldr     r2, =#IO_BANK0_BASE                                        @ loads the base address for GPIO into r2
    ldr     r3, =#IO_BANK0_INTR2_OFFSET                                @ loads the offset address for the GPIO raw interrupts #2 register into r3
    add     r2, r3                                                     @ adds the base address in r2 and offset address in r3 and stores the result in r2
    str     r1, [r2]                                                   @ writes the specified bit value in r1 back to the address in r2
    pop     {pc}                                                       @ pop's the saved information, so that it can return to the next instruction immediately after the calling point

@ ALARM interrupt service handler routine
.thumb_func                                                            @ Required for all interrupt service routines
alarm_isr:
    push    {lr}                                                       @ push the link register, to save the return address
    @ if it has been over 1 second we input a space and terminate the sequence
    movs    r0, #0                                                     @ ASCII value for "null" to terminate a character
    bl      addSymbolToAnswer                                          @ call c function to add the ASCII character to the sequence
    ldr     r7, =1                                                     @ restore the value of r8, to detect the falling-edge event on GP21 
    ldr     r0,=MEMORY                                                 @ stores the morse code sequence just terminated into the memory address for the sequence
    bl      printPlayerInput                                           @ call the c function to display the morse code sequence to the player
    @ clear the ALARM interrupt 
    ldr     r2, =#TIMER_BASE                                           @ loads the base address for the timer component into r2
    ldr     r1, =#ALARM0                                               @ loads ALARM's bit-0 into r1
    ldr     r3, =#TIMER_INTR_OFFSET                                    @ loads the offset address for the TIMER raw interrupts register into r3
    str     r1, [r2, r3]                                               @ writes the appropriate bit value back to the TIMER's offset address interrupt reset register that is in r3 and the base address that is in r2
    pop     {pc}                                                       @ pop's the saved information, so that it can return to the next instruction immediately after the calling point

.data
    @ Set data alignment
    .align 4
    
