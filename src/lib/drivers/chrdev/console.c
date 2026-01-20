#include <drivers/vfs.h>
#include <drivers/devices.h>
#include <cpu.h>
#include <core/sprintf.h>
#include <core/string.h>

union colorchar {
    short bits;
    struct {
        unsigned char ch;
        unsigned char color;
    };
};

#define GREY_ON_BLACK 0x07

union colorchar *screen      = (void *) 0xb8000;
#define              SCREEN_ROWS 25
#define              SCREEN_COLS 80

static const char scancode_to_char[128] = {
    [0x01] = 0,        /* ESC */
    [0x02] = '1',
    [0x03] = '2',
    [0x04] = '3',
    [0x05] = '4',
    [0x06] = '5',
    [0x07] = '6',
    [0x08] = '7',
    [0x09] = '8',
    [0x0A] = '9',
    [0x0B] = '0',
    [0x0C] = '-',
    [0x0D] = '=',
    [0x0E] = '\b',     /* Backspace */
    [0x0F] = '\t',     /* Tab */

    [0x10] = 'q',
    [0x11] = 'w',
    [0x12] = 'e',
    [0x13] = 'r',
    [0x14] = 't',
    [0x15] = 'y',
    [0x16] = 'u',
    [0x17] = 'i',
    [0x18] = 'o',
    [0x19] = 'p',
    [0x1A] = '[',
    [0x1B] = ']',
    [0x1C] = '\n',     /* Enter */

    [0x1E] = 'a',
    [0x1F] = 's',
    [0x20] = 'd',
    [0x21] = 'f',
    [0x22] = 'g',
    [0x23] = 'h',
    [0x24] = 'j',
    [0x25] = 'k',
    [0x26] = 'l',
    [0x27] = ';',
    [0x28] = '\'',
    [0x29] = '`',

    [0x2B] = '\\',
    [0x2C] = 'z',
    [0x2D] = 'x',
    [0x2E] = 'c',
    [0x2F] = 'v',
    [0x30] = 'b',
    [0x31] = 'n',
    [0x32] = 'm',
    [0x33] = ',',
    [0x34] = '.',
    [0x35] = '/',

    [0x39] = ' '       /* Space */
};

struct console {
	int position;
	uint8_t open;
};

static struct console console;

static void console_writech(struct console *c, char ch){
	union colorchar cc = {
		.ch = ' ',
		.color = GREY_ON_BLACK,
	};
	switch (ch){
		case '\n':
			c->position += SCREEN_COLS;
			c->position -= c->position % SCREEN_COLS;
			break;
		case '\r':
			c->position -= c->position % SCREEN_COLS;
			break;
		case '\b':
			screen[--c->position] = cc;
			break;
		default:
			cc.ch = ch;
			screen[c->position++] = cc;
			break;

	}

	// Roll up the screen when at the bottom
	cc.ch = ' ';
	if(c->position >= SCREEN_ROWS * SCREEN_COLS){
		memmove(screen, &screen[SCREEN_COLS], SCREEN_COLS*SCREEN_ROWS*2);
		for(int i = SCREEN_COLS * (SCREEN_ROWS-1); i < SCREEN_COLS*SCREEN_ROWS; i++){
			screen[i] = cc;
		}
		c->position -= SCREEN_COLS;
	}
}

static int console_open_dev(struct file *f, unsigned min){
	UNUSED(min);
	f->f_driver_data = &console;
	if(console.open) return 0;

	console.position = 0;
	for (int i = 0; i < SCREEN_ROWS * SCREEN_COLS; i++){
		// Clear the screen
		console_writech(f->f_driver_data, ' ');
	}
	console.position = 0;

	return 0;

}

static ssize_t console_write(struct file *f, const void *src, size_t count, loff_t *off){
	UNUSED(off);
	struct console *c = f->f_driver_data;
	for(size_t i = 0; i < count; i++){
		console_writech(c, ((char*)src)[i]);
	}
	outb(0x0f, 0x3d4);
	outb(c->position & 0xff, 0x3d5);
	outb(0x0e, 0x3d4);
	outb((c->position>>8) & 0xff, 0x3d5);

	return count;
}


static uint8_t last_scancode = 0x00;
static ssize_t console_read(struct file *f, void *dst, size_t count, loff_t *t){
	UNUSED(f);
	UNUSED(count);
	UNUSED(t);
	
	int res = -1;

	uint8_t scancode = inb(0x60);
	if(scancode != last_scancode && scancode <= 0x57){
		*(char*)dst = scancode_to_char[scancode];
		res = 1;
	}
	last_scancode = scancode;
	

	return res;
}


static const struct file_operations console_ops = {
	.name = "console",
	.open_dev = console_open_dev,
	.read = console_read,
	.write = console_write,
};

int init_driver_console(void){
	
	return chrdev_register(MAJ_CONSOLE, &console_ops);

}
