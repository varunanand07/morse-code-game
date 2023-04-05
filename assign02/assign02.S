#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified                                                 @ Specify unified assembly syntax
.cpu    cortex-m0plus                                           @ Specify CPU type is Cortex M0+
.thumb                                                          @ Specify thumb assembly for RP2040
.global main_asm                                                @ Provide program starting address to the linker
.align 4                                                        @ Specify code alignment

.equ DFLT_STATE_STRT, 1             @ Specify the value to start flashing
.equ DFLT_STATE_STOP, 0             @ Specify the value to stop flashing
.equ DFLT_ALARM_TIME, 1000000       @ Specify the default alarm timeout
.equ GPIO_BTN_MSK, 0x00400000       @ Bit-22 for falling-edge event on GP21
.equ GPIO_BTN, 21                   @ Specify pin for push-button for the game
.equ GPIO_DIR_IN, 0                 @ Specify input direction for a GPIO pin
.equ GPIO_ISR_OFFSET, 0x74          @ GPIO is int #13 (vector table entry 29)
.equ ALARM_ISR_OFFSET, 0x40         @ ALARM0 is int #0 (vector table entry 16)
.equ ALARM0, 0x1                    @ ALARM0, bit-0
.equ GPIO, 0x2000                   @ GPIO, bit-13

@ Entry point to the ASM portion of the program
main_asm:
    bl      init_gpio_btn        @ Initialise GP21 push-button
    bl      install_gpio_isr     @ Install the GPIO interrupt service routine
    bl      install_alarm_isr    @ Install the ALARM interrupt service routine
    @ Set first alarm
    ldr     r4, =ltimer                     @ load address of the global variable for the timer
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
    b       loop                 @ Infinite loop

@ Subroutine used to intialise the PI Pico built-in button GP21
init_gpio_btn:
    push    {lr}
    movs    r0, #GPIO_BTN
    bl      asm_gpio_init
    movs    r0, #GPIO_BTN
    movs    r1, #GPIO_DIR_IN
    bl      asm_gpio_set_dir
    movs    r0, #GPIO_BTN_MSK
    bl      asm_gpio_set_irq
    pop     {pc}

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
    @ If button pressed
button_gp21:
    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)         @ loads the address for GPIO and the offset address for the GPIO interrupt status #2 register into r2
    ldr     r1, [r2]                                                   @ loads the value in address r2 into r1
    ldr     r2, =#GPIO_BTN_MSK                                         @ loads bit-22 for falling-edge event on GP21 into r2                                
    cmp     r1, r2                                                     @ checks if the GP21 button has been pressed
    beq     check_button_state                                         @ branch to the subroutine to check the flashing state for GP21
check_button_state:
    ldr     r5, =lstate                                                @ loads the address of the global variable for the flashing state into r5
    ldr     r6, [r5]                                                   @ loads the value contained within the global variable into r6
    cmp     r6, #1                                                     @ checks if the flashing state is equalled to "1"
    beq     set_off                                                    @ if the flashing state is equalled to "1", jump to the code to set the flashing state to "0"
    ldr	    r6, =#DFLT_STATE_STRT                                      @ loads the value for the flashing state to start into r6
    str     r6, [r5]                                                   @ stores the flashing state value in r6 into the address of the global variable for the flashing state, that is in r5
    b       clear_gp21                                                 @ branches to the subroutine to clear the interrupt for GP21
reset_timer:
    push    {lr}                                                       @ push the link register, to save the return address
    ldr     r5, =ltimer                                                @ loads the address of the global variable for the timer into r5 
    ldr     r6, =#DFLT_ALARM_TIME                                      @ loads the default timer value into r6
    str     r6, [r5]                                                   @ stores the default timer value in r6 into the address for the global variable for the timer, that is in r5
    pop     {pc}                                                       @ pop's the saved information, so that it can return to the next instruction immediately after the calling point
set_off:
    ldr     r6, =#DFLT_STATE_STOP                                      @ loads the value for the flashing state to stop into r6
    str     r6, [r5]                                                   @ stores the flashing state value in r6 into the address for the global variable for the flashing state, that is in r5
clear_gp21:
    @ clear GP21 interrupt
    ldr     r2, =#IO_BANK0_BASE                                        @ loads the base address for GPIO into r2
    ldr     r3, =#IO_BANK0_INTR2_OFFSET                                @ loads the offset address for the GPIO raw interrupts #2 register into r3
    add     r2, r3                                                     @ adds the base address in r2 and offset address in r3 and stores the result in r2
    ldr     r1, =#GPIO_BTN_MSK                                         @ loads bit-22 for falling-edge event on GP21 into r1
    str     r1, [r2]                                                   @ writes the specified bit value in r1 back to the address in r2
    b       end_gpio                                                   @ jumps to the end of gpio_isr 
end_gpio:
    pop     {pc}                                                       @ pop's the saved information, so that it can return to the next instruction immediately after the calling point

@ ALARM interrupt service handler routine
.thumb_func                                 @ Required for all interrupt service routines
alarm_isr:
    push    {lr}                            @ push the link register, to save the return address
    @ clear the ALARM interrupt 
    ldr     r2, =#TIMER_BASE                @ loads the base address for the timer component into r2
    ldr     r1, =#ALARM0                    @ loads ALARM's bit-0 into r1
    ldr     r3, =#TIMER_INTR_OFFSET         @ loads the offset address for the TIMER raw interrupts register into r3
    str     r1, [r2, r3]                    @ writes the appropriate bit value back to the TIMER's offset address interrupt reset register that is in r3 and the base address that is in r2
    @ enable the ALARM interrupt
    ldr     r2, =#TIMER_BASE                @ loads the base address for the timer component into r2
    ldr     r1, =#ALARM0                    @ loads ALARM's bit-0 into r1
    ldr     r3, =#TIMER_INTE_OFFSET         @ loads the offset address for the TIMER raw interrupt enable register into r3
    str     r1, [r2, r3]                    @ writes the appropriate bit value back to the TIMER's offset address interrupt enable register that is in r3 and the base address that is in r2
    @ set the next ALARM interrupt
    ldr     r4, =ltimer                     @ loads the address of the global variable for the timer
    ldr     r4, [r4]                        @ load the value contained in the global variable into r4
    ldr     r2, =#TIMER_BASE                @ loads the base address for the timer component into r2
    ldr     r1, =#ALARM0                    @ loads ALARM's bit-0 into r1
    ldr     r3, =#TIMER_TIMELR_OFFSET       @ loads the offset address for the lower 32-bits of the timer register into r3
    ldr     r1, [r2, r3]                    @ loads the address of r3 and r2 into r1
    add     r1, r4                          @ add the length of the alarm contained in r4 with the appropriate bit value of ALARM0 bit-0, which is in r1 and store the result in r1
    ldr     r3, =#TIMER_ALARM0_OFFSET       @ loads the offset address for the ALARM0 control register into r3
    str     r1, [r2, r3]                    @ write the value in r1 back to the base address that is in r2 and the offset address that is in r3
    pop     {pc}                            @ pop's the saved information, so that it can return to the next instruction immediately after the calling point

@ Set data alignment
.align 4

.data
    @ this contains the shared data for flashing state and interval value in this data segment
    lstate: .word DFLT_STATE_STRT   @ start flashing state of the LED, this is declared as a constant 
    ltimer: .word DFLT_ALARM_TIME   @ start interval value, this is declared as a constant
    

