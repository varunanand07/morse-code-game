#include <stdio.h>
#include <stdlib.h>

#include "pico/stdlib.h"
#include "hardware/pio.h"
#include "hardware/clocks.h"
#include "assign02.pio.h"

#define IS_RGBW true        // Will use RGBW format
#define NUM_PIXELS 1        // There is 1 WS2812 device in the chain
#define WS2812_PIN 28       // The GPIO pin that the WS2812 connected to

// Must declare the main assembly entry point before use.
void main_asm();

/*
 * Main entry point for the code - simply calls the main assembly function.
 */
int main() {
    main_asm();
    // Initialise all STDIO as we will be using the GPIOs
    stdio_init_all();

    return(0);
}
