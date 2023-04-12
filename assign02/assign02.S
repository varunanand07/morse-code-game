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
.equ DFLT_ALARM_TIME, 1000000        @ Specify the alarm time value 
.equ HALF_ALARM_TIME, 500000         @ Specify half the alarm time value
.equ GPIO_BTN_FALL_MSK, 0x00400000   @ Bit-22 for falling-edge event on GP21
.equ GPIO_BTN_RISE_MSK, 0x00800000   @ Bit-23 for rising-edge event on GP21
.equ GPIO_BTN_EN, 21                 @ Specify pin for push-button for the game
.equ GPIO_DIR_IN, 0                  @ Specify input direction for a GPIO pin
.equ GPIO_ISR_OFFSET, 0x74           @ GPIO is int #13 (vector table entry 29)
.equ ALARM_ISR_OFFSET, 0x40          @ ALARM0 is int #0 (vector table entry 16)
.equ ALARM0, 0x1                     @ ALARM0, bit-0
.equ GPIO, 0x2000                    @ GPIO, bit-13
.equ ALARM_TIME, 2000000             @ Specify the 2 seconds alarm timeout
.equ CHAR_DOT, 0                     @ c function addToSequence parameter value for "dot"
.equ CHAR_DASH, 1                    @ c function addToSequence parameter value for "dash"   
.equ CHAR_SPACE, 2                   @ c function addToSequence parameter value for "space"

@ Entry point to the ASM portion of the program
main_asm:
    ldr     r7, =1                          @ boolean set true for first press
    ldr     r5, =0                          @ Default value for time between presses
    bl      init_gpio_btn_gp21              @ Initialise GP21 push-button
    bl      install_gpio_isr                @ Install the GPIO interrupt service routine
    bl      install_alarm_isr               @ Install the ALARM interrupt service routine
    @ Set alarm
    ldr     r4, =gameTimer                  @ load address of the global variable for the "gameTimer"
    ldr     r4, [r4]                        @ loads the value contained in the global variable into r4
    ldr     r2, =#TIMER_BASE                @ loads the base address for the timer component into r2
    ldr     r1, =#ALARM0                    @ bit-0 for ALARM0           
    ldr     r3, =#TIMER_INTE_OFFSET         @ loads the offset address for the TIMER raw interrupt enable register into r3
    str     r1, [r2, r3]                    @ writes the appropriate bit value back to the TIMER's offset address interrupt enable register that is in r3 and the base address that is in r2
    ldr     r3, =#TIMER_TIMELR_OFFSET       @ loads the offset address for the lower 32-bits of the timer register into r3
    ldr     r1, [r2, r3]                    @ loads the address of r3 and r2 into r1
    add     r1, r4                          @ add the length of the alarm contained in r4 with the appropriate bit value of ALARM0 bit-0, which is in r1 and store the result in r1
    ldr     r3, =#TIMER_ALARM0_OFFSET       @ loads the offset address for the ALARM0 control register into r3
    str     r1, [r2, r3]                    @ write the value in r1 back to the base address that is in r2 and the offset address that is in r3
loop:
    @ Wait for interrupt to be triggered
    wfi                                     
    b       loop                            @ Infinite loop

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
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)                       @ This is CORTEX-M0+ internal peripherals & the offset address for the vector table - determines vector location
    ldr     r1, [r2]                                                   @ the vector location stored at address [r2] is loaded into register r1
    movs    r2, #GPIO_ISR_OFFSET                                       @ This is the location of the GPIO with entry 29 - GPIO is int #13 (vector table entry 29)
    add     r2, r1                                                     @ Adds the location of the GPIO entry address to the vector table & loads it into r2
    ldr     r0, =gpio_isr                                              @ loads the address of the GPIO interrupt service handler subroutine into r0
    str     r0, [r2]                                                   @ stores the address of the subroutine found in r0 to the memory address of the vector table
    @ disable the specific interrupt level by writing to the appropriate bit in (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)                  @ loads the offset address for the NVIC Interrupt Clear Pending register into r2
    ldr     r1, =#GPIO                                                 @ loads GPIO's bit-13 into r1 
    str     r1, [r2]                                                   @ writes the approriate bit value back to the address of (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET) that is in r2
    @ enable the specific interrupt level by writing to the appropriate bit in (PPB_BASE + M0PLUS_NIVC_ISER_OFFSET)
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)                  @ loads the offset address for the NVIC Interrupt Set Enable register into r2 
    ldr     r1, =#GPIO                                                 @ loads GPIO's bit-13 in into r1
    str     r1, [r2]                                                   @ writes the appropriate bit value back to the address of (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET) that is in r2
    bx      lr                                                         @ branch back to link register address

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
    bl      watchdog_update
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)         @ loads the address for GPIO and the offset address for the GPIO interrupt status #2 register into r2
    ldr     r1, [r2]                                                   @ loads the value in address r2 into r1
    ldr     r2, =#GPIO_BTN_FALL_MSK                                    @ loads bit-22 for falling-edge event on GP21 into r2    
    ands    r1, r2                            
    cmp     r1, r2                                                     @ checks if the GP21 button has been pressed
    beq     button_pressed                                             @ branch to the subroutine to check the flashing state for GP21
    @ Button has been released - we need to know how long it has been pressed for morse code & length between presses to know which morse code pattern to input
    @ when the button was released & duration of press
button_released:
    ldr     r1, =#TIMER_BASE                                           @ loads the base address for the timer component into r2
    ldr     r3, =#TIMER_TIMELR_OFFSET                                  @ loads the offset address for the TIMER raw interrupts register into r3
    ldr     r0, [r1, r3]                                               @ current timer after the button has been released
    ldr     r1, =time
    ldr     r1, [r1]
    subs    r0, r0, r1                                                     @ subtract the time of press from the time of release, to find out the duration of the press
    bl      morse_code_sequence                                        @ branch to code to input into morse code sequence
    b       clear_button_release                                       @ clear interrupt for rising-edge event on GP21

button_pressed:
    ldr     r2, =#TIMER_BASE                                           @ loads the base address for the timer component into r2
    ldr     r3, =#TIMER_TIMELR_OFFSET                                  @ loads the offset address for the TIMER raw interrupts register into r3
    ldr     r0, [r2, r3]
    ldr     r1, =time
    str     r0, [r1]
    b       clear_button_press                                         @ clear interrupt for falling-edge event on GP21

clear_button_release:
    ldr     r1, =#GPIO_BTN_RISE_MSK                                    @ loads the bit for the rising-edge event on GP21
    b       end_gpio                                                   @ branch to clear interrupt for rising-edge event on GP21

clear_button_press:
    ldr     r1, =#GPIO_BTN_FALL_MSK                                    @ loads bit for rising-edge event on GP21 into r1
    b       end_gpio                                                   @ loads bit-22 for falling-edge event on GP21 into r1
    /*        INPUT TO MORSE CODE SEQUENCE - START        */ 
    // check if something was input before at least one second
morse_code_sequence:
    push    {r0, r1, lr}                                                       @ load "timer" into r3                                                  @ load the value stored at the address of "halfTimer" into r3
    ldr     r1, =#HALF_ALARM_TIME
    cmp     r0, r1                                                     @ if the button press is less than one second, then we will input a dot
    blt     input_dot                                                  @ branch to subroutine to input a dot into the morse code sequence    
    movs    r0, #CHAR_DASH                                             @ pass in "dash" parameter for the addToSequence c function
    b       sequence_add                                               @ branch to code to add the character into the morse code sequence 
input_dot:
    movs    r0, #CHAR_DOT                                              @ pass in "dot" parameter for the addToSequence c function
    b       sequence_add                                               @ branch to code to add the character into the morse code sequence 
sequence_add:
    bl      Gameflow                                                   @ call c function to add the ASCII character in r0 to the morse code sequence
    bl      reset_timer
    pop     {r0, r1, pc}
    /*        INPUT TO MORSE CODE SEQUENCE - END         */ 
end_gpio:
    @ clear GP21 interrupt
    ldr     r2, =#IO_BANK0_BASE                                        @ loads the base address for GPIO into r2
    ldr     r3, =#IO_BANK0_INTR2_OFFSET                                @ loads the offset address for the GPIO raw interrupts #2 register into r3
    add     r2, r3                                                     @ adds the base address in r2 and offset address in r3 and stores the result in r2
    str     r1, [r2]                                                   @ writes the specified bit value in r1 back to the address in r2
    pop     {pc}                                                       @ pop's the saved information, so that it can return to the next instruction immediately after the calling point

reset_timer:
    push    {lr}
    @ Set alarm
    ldr     r4, =gameTimer                  @ load address of the global variable for the "gameTimer"
    ldr     r2, =#TIMER_BASE                @ loads the base address for the timer component into r2
    ldr     r1, =#ALARM0                    @ bit-0 for ALARM0           
    ldr     r3, =#TIMER_INTE_OFFSET         @ loads the offset address for the TIMER raw interrupt enable register into r3
    str     r1, [r2, r3]                    @ writes the appropriate bit value back to the TIMER's offset address interrupt enable register that is in r3 and the base address that is in r2
    ldr     r3, =#TIMER_TIMELR_OFFSET       @ loads the offset address for the lower 32-bits of the timer register into r3
    ldr     r1, [r2, r3]                    @ loads the address of r3 and r2 into r1
    add     r1, r4                          @ add the length of the alarm contained in r4 with the appropriate bit value of ALARM0 bit-0, which is in r1 and store the result in r1
    ldr     r3, =#TIMER_ALARM0_OFFSET       @ loads the offset address for the ALARM0 control register into r3
    str     r1, [r2, r3]                    @ write the value in r1 back to the base address that is in r2 and the offset address that is in r3
    pop     {pc}

@ ALARM interrupt service handler routine
.thumb_func                                                            @ Required for all interrupt service routines
alarm_isr:
    push    {lr}                                                       @ push the link register, to save the return address
    @ reset the first button press boolean
    ldr     r0, =2
    bl      Gameflow
    ldr     r7, =1
    ldr     r6, =-1
    ldr     r5, =1
    @ clear the ALARM interrupt 
    ldr     r2, =#TIMER_BASE                                           @ loads the base address for the timer component into r2
    ldr     r1, =#ALARM0                                               @ loads ALARM's bit-0 into r1
    ldr     r3, =#TIMER_INTR_OFFSET                                    @ loads the offset address for the TIMER raw interrupts register into r3
    str     r1, [r2, r3]                                               @ writes the appropriate bit value back to the TIMER's offset address interrupt reset register that is in r3 and the base address that is in r2
    pop     {pc}                                                       @ pop's the saved information, so that it can return to the next instruction immediately after the calling point

@ Set data alignment
.align 4
    .data
    halfTimer: .word HALF_ALARM_TIME        @ Half the alarm time value, this is declared as a constant
    timer: .word DFLT_ALARM_TIME            @ Alarm time value, this is declared as a constant
    gameTimer: .word ALARM_TIME             @ Alarm time value for the game, this is declared as a constant
    time: .word 0
