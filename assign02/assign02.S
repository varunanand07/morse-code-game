@ Assembler program to flash three LEDs connected to the
@ Raspberry Pi GPIO using timer interrupts to trigger the
@ next LED to flash.
@
#include "hardware/regs/addressmap.h"
#include "hardware/regs/sio.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/pads_bank0.h"
#include "hardware/regs/m0plus.h"

    .equ DFLT_STATE_STRT, 1 @ Specify the value to start flashing
    .equ DFLT_STATE_STOP, 0 @ Specify the value to stop flashing
    .equ DFLT_ALARM_TIME, 1000000 @ Specify the default alarm timeout
    .equ GPIO_BTN_DN_MSK, 0x00040000 @ Bit-18 for falling-edge event on GP20
    .equ GPIO_BTN_EN_MSK, 0x00400000 @ Bit-22 for falling-edge event on GP21
    .equ GPIO_BTN_UP_MSK, 0x04000000 @ Bit-26 for falling-edge event on GP22
    .equ GPIO_BTN_DN, 20 @ Specify pin for the "down" button
    .equ GPIO_BTN_EN, 21 @ Specify pin for the "enter" button
    .equ GPIO_BTN_UP, 22 @ Specify pin for the "up" button
    .equ GPIO_LED_PIN, 25 @ Specify pin for the built-in LED
    .equ GPIO_DIR_IN, 0 @ Specify input direction for a GPIO pin
    .equ GPIO_DIR_OUT, 1 @ Specify output direction for a GPIO pin
    .equ LED_VAL_ON, 1 @ Specify value that turns the LED "on"
    .equ LED_VAL_OFF, 0 @ Specify value that turns the LED "off"
    .equ GPIO_ISR_OFFSET, 0x74 @ GPIO is int #13 (vector table entry 29)
    .equ ALRM_ISR_OFFSET, 0x40 @ ALARM0 is int #0 (vector table entry)

    .thumb_func @ Needed since SDK uses BX to call us
    .global main_asm @ Provide program starting address
    
    .align 4 @ necessary alignment

    main_asm:
        
        ldr     r5, =0                      @ stop = false
        movs    r0, #GPIO_LED_PIN           @ This value is the GPIO LED pin on the PI PICO board
        bl      asm_gpio_init               @ Call the subroutine to initialise the GPIO pin specified by r0
        movs    r0, #GPIO_BTN_DN            @ This value is the GPIO button 20 on the PI PICO board
        bl      asm_gpio_init               @ Call the subroutine to initialise the GPIO button 20 specified by r0
        movs    r0, #GPIO_BTN_EN            @ This value is the GPIO button 20 on the PI PICO board
        bl      asm_gpio_init               @ Call the subroutine to initialise the GPIO button 21 specified by r0
        movs    r0, #GPIO_BTN_UP            @ This value is the GPIO button 20 on the PI PICO board
        bl      asm_gpio_init               @ Call the subroutine to initialise the GPIO button 21 specified by r0
        movs    r0, #GPIO_LED_PIN           @ This value is the GPIO LED pin on the PI PICO board
        movs    r1, #GPIO_DIR_OUT           @ We want this GPIO pin to be setup as an output pin
        bl      asm_gpio_set_dir            @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
        movs    r0, #GPIO_BTN_DN            @ This value is the GPIO LED pin on the PI PICO board
        movs    r1, #GPIO_DIR_IN            @ We want this GPIO pin to be setup as an output pin
        bl      asm_gpio_set_dir            @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
        bl      asm_gpio_set_irq            @ Enable falling-edge on GP20
        movs    r0, #GPIO_BTN_EN            @ This value is the GPIO LED pin on the PI PICO board
        movs    r1, #GPIO_DIR_IN            @ We want this GPIO pin to be setup as an output pin
        bl      asm_gpio_set_dir            @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
        bl      asm_gpio_set_irq            @ Enable falling-edge on GP21
        movs    r0, #GPIO_BTN_UP            @ This value is the GPIO LED pin on the PI PICO board
        movs    r1, #GPIO_DIR_IN            @ We want this GPIO pin to be setup as an output pin
        bl      asm_gpio_set_dir            @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
        bl      asm_gpio_set_irq            @ Enable falling-edge on GP22
        ldr     r4, =DFLT_ALARM_TIME
        
        BL set_alarm0_isr @ set the interrupt handler
        LDR R0, =DFLT_ALARM_TIME @ load the time to sleep
        BL set_alarm0 @ set the first alarm
        BL set_button_isr
        
    loop:
        B loop @ loop forever

    set_alarm0:
        push {lr}
        @ Set's the next alarm on alarm 0
        @ R0 is the length of the alarm
        @ Enable timer 0 interrupt
        LDR R2, =TIMER_BASE
        movs R1, #1 @ for alarm 0
        STR R1, [R2, #TIMER_INTE_OFFSET]
        @ Set alarm
        LDR R1, [R2, #TIMER_TIMELR_OFFSET]
        ADD R1, R0
        STR R1, [R2, #TIMER_ALARM0_OFFSET]
        pop {pc}

    .thumb_func @ necessary for interrupt handlers
    @ Alarm 0 interrupt handler and state machine.
    alarm_isr:
        PUSH {R0, LR} @ calls other routines
        @ Clear the interrupt
        LDR R0, =message_alarm
        BL printf
        LDR R2, =TIMER_BASE
        movs R1, #1 @ for alarm 0
        STR R1, [R2, #TIMER_INTR_OFFSET]
        cmp r5, #0 @ if stop is false, so if GP21 wasn't pressed
        bne finish @ we branch to finish, if it was pressed
        bl change @ we branch to the change subroutine, if GP21 wasn't pressed
    finish:
        movs r0, r4 @ sleep time
        BL set_alarm0 @ set next alarm
        POP {R0, PC} @ return from interrupt

    set_alarm0_isr:
        push {lr}
        @ Set IRQ Handler to our routine
        LDR R2, =PPB_BASE
        LDR R1, =M0PLUS_VTOR_OFFSET
        ADD R2, R1
        LDR R1, [R2]
        movs R2, #ALRM_ISR_OFFSET @ slot for alarm 0
        ADD R2, R1
        LDR R0, =alarm_isr
        STR R0, [R2]

        @ Enable alarm 0 IRQ (clear then set)
        movs R0, #1 @ alarm 0 is IRQ0
        LDR R2, =PPB_BASE
        LDR R1, =M0PLUS_NVIC_ICPR_OFFSET
        ADD R1, R2
        STR R0, [R1]

        LDR R1, =M0PLUS_NVIC_ISER_OFFSET
        ADD R1, R2
        STR R0, [R1]
        pop {pc}

    .thumb_func @ necessary for interrupt handlers
    @ button interrupt handler and state machine.
    button_isr:
        PUSH {LR} @ calls other routines
        @ Clear the interrupt
        LDR R2, =IO_BANK0_BASE
        LDR R3, =IO_BANK0_PROC0_INTS2_OFFSET
        ADD r2, r2, r3
        LDR R1, [R2]

        @ checking to see, if GP20 was pressed; if it was, we branch to the section that halves the time (or resets the time, if GP21
        @ stopped the blinking)
        ldr r2, =GPIO_BTN_DN_MSK
        cmp r1, r2
        bne end_if1
        bl half_it
    end_if1:

        @ checking to see, if GP21 was pressed; if it was, we branch to the section that starts/stops the blinking of the LED
        ldr r2, =GPIO_BTN_EN_MSK
        cmp r1, r2
        bne end_if2
        bl start_stop
    end_if2:

        @ checking to see, if GP22 was pressed; if it was, we branch to the section that doubles the time (or resets the time, if GP21
        @ stopped the blinking)
        ldr r2, =GPIO_BTN_UP_MSK
        cmp r1, r2
        bne end_if3
        bl double_it
    end_if3:

        POP {PC} @ return from interrupt

    set_button_isr:
        push {lr}
        @ Set IRQ Handler to our routine
        LDR R2, =PPB_BASE
        LDR R1, =M0PLUS_VTOR_OFFSET
        ADD R2, R1
        LDR R1, [R2]
        movs R2, #GPIO_ISR_OFFSET @ slot for button
        ADD R2, R1
        LDR R0, =button_isr
        STR R0, [R2]

        @ Disable button_isr
        ldr R0, =8192
        LDR R2, =PPB_BASE
        LDR R1, =M0PLUS_NVIC_ICPR_OFFSET
        ADD R1, R2
        STR R0, [R1]

        @ Enable button_isr
        LDR R1, =M0PLUS_NVIC_ISER_OFFSET
        ADD R1, R2
        STR R0, [R1]
        pop {pc}
    
    @ this subroutine halves (or resets) the blinking period and prints an appropriate message
    @ after doing so, it clears the interrupt
    half_it:
        push {r0, lr}
        LDR R0, =message_half
        BL printf
        cmp r5, #0
        bne reset_value1
        ldr r6, =2
        ldr r3, =1
        lsr r4, #1
        b end1
    reset_value1:
        ldr r4, =DFLT_ALARM_TIME
    end1:
        LDR R2, =IO_BANK0_BASE
        LDR R3, =IO_BANK0_INTR2_OFFSET
        ADD r2, r2, r3
        LDR r3, =GPIO_BTN_DN_MSK
        STR r3, [r2]
        pop {r0, pc}

    @ this subroutine doubles (or resets) the blinking period and prints an appropriate message
    @ after doing so, it clears the interrupt
    double_it:
        push {r0, lr}
        LDR R0, =message_double
        BL printf
        cmp r5, #0
        bne reset_value2
        ldr r6, =2
        mul r4, r4, r6
        b end2
    reset_value2:
        ldr r4, =DFLT_ALARM_TIME
    end2:
        LDR R2, =IO_BANK0_BASE
        LDR R3, =IO_BANK0_INTR2_OFFSET
        ADD r2, r2, r3
        LDR r3, =GPIO_BTN_UP_MSK
        STR r3, [r2]
        pop {r0, pc}

    @ this subroutine starts or stops the blinking and prints an appropriate message
    @ after doing so, it clears the interrupt
    start_stop:
        push {r0, lr}
        LDR R0, =message_stop_start
        BL printf
        cmp r5, #0
        bne change_to_zero
        ldr r5, =1
        b end3
    change_to_zero:
        ldr r5, =0
    end3:
        LDR R2, =IO_BANK0_BASE
        LDR R3, =IO_BANK0_INTR2_OFFSET
        ADD r2, r2, r3
        LDR r3, =GPIO_BTN_EN_MSK
        STR r3, [r2]
        pop {r0, pc}

    @ Change LED state
    change:
        push    {lr}
        movs    r0, #GPIO_LED_PIN           @ Set the LED GPIO pin number to r0 for use by asm_gpio_get
        bl      asm_gpio_get                @ Get current the value of the LED GPIO pin (returns to r0)
        cmp     r0, #1                      @ if the LED is on
        beq     turn_off                    @ we branch to the turn_off section
        mov     r1, #LED_VAL_ON             @ if the LED is off, we assign r1 the on value
        b       set_state
    turn_off:
        mov     r1, #LED_VAL_OFF            @ if the LED is on, we assign r1 the off value
    set_state:
        ldr     r0, =GPIO_LED_PIN           @ we assign r0 the corresponding pin number associated with the LED
        bl      asm_gpio_put                @ Update the the value of the LED GPIO pin (based on value in r1)
        pop     {pc}

        .align 4 @ necessary alignment
    message_alarm:    .asciz "Blast off!\n"             @ if the alarm interrupt is triggered, we will also print "Blast off!"
    message_half:    .asciz "GP20 was pressed!\n"       @ if the button interrupt is triggered by GP20, we will also print "GP20 was pressed!\n"
    message_stop_start:    .asciz "Gp21 was pressed!\n" @ if the button interrupt is triggered by GP21, we will also print "GP21 was pressed!\n"
    message_double:    .asciz "GP22 was pressed!\n"     @ if the button interrupt is triggered by GP22, we will also print "GP22 was pressed!\n"

    .data
    state: .word 0