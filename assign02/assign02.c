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

// Initialise a GPIO pin – see SDK for detail on gpio_init()
void asm_gpio_init(uint pin) {
    gpio_init(pin);
}

// Set direction of a GPIO pin – see SDK for detail on gpio_set_dir()
void asm_gpio_set_dir(uint pin, bool out) {
    gpio_set_dir(pin, out);
}

// Enable falling-edge interrupt – see SDK for detail on gpio_set_irq_enabled()
void asm_gpio_set_irq(uint pin) {
    gpio_set_irq_enabled(pin, GPIO_IRQ_EDGE_FALL, true);
}

// Global variables
char buffer[5];
char check[5];

// Character array for the alphanumeric digits & letters
char alphanumericCharacters[] = {
    // Alphanumeric letters A - Z
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
    // Alphanumeric digits 0 - 9
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'};

// Character array for the morse code digits & letters
char MorseCodeCharacters[36][5] = { 
    // Morse code for the letters A - Z
    ".-", "-...", "-.-.", "-..", ".", "..-.", "--.", "....",
    "..", ".---", "-.-", ".-..", "--", "-.", "---", ".--.",
    "--.-", ".-.", "...", "-", "..-", "...-", ".--", "-..-",
    "-.--", "--..",
    // Morse code for the digits 0-9
    "-----", ".----", "..---", "...--", "....-", ".....",
    "-....", "--...", "---..", "----."};

void welcome_message_banner() {
  printf("\n+--------------------------------------------------------+\n");
  printf("|              ASSIGNMENT #02      Group 11              |\n");
  printf("+--------------------------------------------------------+\n");
  printf("|    +       +  +------+  +------+   +----+  +------+    |\n");
  printf("|    | \\   / |  |      |  |       +  |       |           |\n");
  printf("|    |   +   |  |      |  |------+   +----+  |----+      |\n");
  printf("|    |       |  |      |  |     \\         |  |           |\n");
  printf("|    +       +  +------+  +      +   +----+  +------+    |\n");
  printf("|                                                        |\n");
  printf("|         +------+  +------+  +----+    +------+         |\n");
  printf("|         |         |      |  |     \\   |                |\n");
  printf("|         |         |      |  |      +  |----+           |\n");
  printf("|         |         |      |  |     /   |                |\n");
  printf("|         +------+  +------+  +----+    +------+         |\n");
  printf("|                                                        |\n");
  printf("|          +------+    ^    +       +  +------+          |\n");
  printf("|          |         /   \\  | \\   / |  |                 |\n");
  printf("|          |   +--|  |---|  |   +   |  |----+            |\n");
  printf("|          |      |  |   |  |       |  |                 |\n");;
  printf("|          +------+  +   +  +       +  +------+          |\n");
  printf("+--------------------------------------------------------+\n");
  printf("|       TO BEGIN, PRESS ON GP21 TO ENTER SEQUENCE        |\n");
  printf("|         \".----\" - LEVEL 01 - CHARACTERS (EASY)         |\n");
  printf("|         \"..---\" - LEVEL 02 - CHARACTERS (HARD)         |\n");
  printf("+--------------------------------------------------------+\n");
  printf("Rules:\n");
  printf("1. Enter the character displayed in morse code.\n");
  printf("2. If you get the character correct you win a life (max number of lives: 3).\n");
  printf("3. Otherwise you lose a life. The LED will show you how many lives you have.\n");
  printf("4. If you do not enter a character for a period of 9 seconds, the game will reset.\n");
  printf("5. If you end up with zero lives, you lose.\n");
  printf("\nCHOOSE A LEVEL FROM THE ONES SHOWN ABOVE: ");
}

/*
 * Main entry point for the code - simply calls the main assembly function.
 */
int main() {
    main_asm();
    // Initialise all STDIO as we will be using the GPIOs
    stdio_init_all();

    return(0);
}