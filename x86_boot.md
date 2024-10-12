
So, you wanna boot your own OS, huh? Well, buckle the hell up, because we’re diving into the deep end with GRUB, the **badass bootloader** that’ll let you shove your code into the computer’s face and say, “**Boot this, you piece of junk!**”

Forget those bloated systems; we’re getting down and dirty with a barebones C program, just you, GRUB, and some low-level magic. No fluff, no safety nets—just you **manhandling the hardware** like a true hacker.

But before that, You gotta know that GRUB works in two parts:

**Stage 1:**  
This is the tiny piece of code sitting in the MBR like a **guard dog**, just waiting to kick the bigger, more complex Stage 2 into gear. Think of it like the bouncer at the door of the nightclub that is your computer.

**Stage 2:**  
Now this is where the magic happens! Stage 2 is GRUB's fancy-ass user interface, letting you choose which operating system or kernel you want to boot, like picking your poison from a lineup.

Now, let’s see how you can get your puny little C program up and running with GRUB.

### Multiboot Header

Here’s the secret sauce that makes the bootloader recognize your kernel. Without this, GRUB will just look at your program and say, **"WTF is this?"**

```c
// Align the binary so it's not all over the damn place
#define ALIGNMENT   1 << 0

// We want memory info because who doesn't want to know where all the good stuff is?
#define MEM_INFO    1 << 1

// Combine those flags like a boss
#define FLAGS       ALIGNMENT | MEM_INFO

// Tell GRUB we're serious with this magic number
#define MAGIC       0x1badb002 

// A checksum to prove we ain't bluffing
#define CHECKSUM    -((MAGIC) + (FLAGS))

typedef struct 
{
  // The magic number that lets the bootloader know this isn’t some random garbage
  multiboot_uint32_t magic;

  // The flags for alignment and memory info
  multiboot_uint32_t flags;

  // Gotta balance the checkbook, or the whole thing falls apart
  multiboot_uint32_t checksum;
} multiboot_header;

// Align this bad boy to 4 bytes because precision matters
__attribute__((aligned(4)))
__attribute__((section(".rodata.multiboot")))
const multiboot_header header = {
    .magic = MAGIC,
    .flags = FLAGS,
    .checksum = CHECKSUM
};
```

Without this header, GRUB's just gonna look at your kernel like it's some sketchy spam email and **trash it right away**.

### Boot Stack

Now you need some place to keep track of all the crap you're going to do. That’s where the boot stack comes in.

```c
__attribute__((aligned(16)))
char bootstack[4096];
```

This 4 KB stack is where you throw everything when the program runs. It's like your **pocket dimension** for temporary chaos.

### Entry Point and Stack Setup

Here's where you take control of the whole damn machine.

```c
__attribute__((naked))
int _start() {
    // Set the stack pointer to the end of the bootstack, 'cause stacks grow down like a hangover
    __asm__(
        "movl %0, %%esp\n"
        "movl %%esp, %%ebp\n"
        ::
        "r" (((unsigned int)bootstack) + sizeof(bootstack))
    );
    
    // Jump straight to the main function like a boss
    __asm__("jmp main");
}
```

This little chunk of code throws you right into the action by setting the stack pointer (`esp`) and frame pointer (`ebp`). From here, you say, **"Screw the setup, let's jump right into 'main'!"**

### Main Function

The **moment of glory**—where you get to leave your mark on the screen!

```c
void main() {
    // VGA framebuffer starts at this magical address, 0xb8000
    char *frame_buffer = (char *)0xb8000;
    
    // Write the letter 'H' onto the screen to show the world you’ve made it
    *frame_buffer = 'H';
    
    // Now chill forever like a lazy boss
    while (1) {}
}
```

Here, you write the letter 'H' to the VGA framebuffer at `0xb8000`, which is pretty much **punching the display in the face** and telling it what to show. After that, you can sit back and let the infinite loop keep you cozy.

### Linker Script

This is where the **real dark magic** happens. The linker script is the GPS for your program, telling it where to put all the important stuff in memory.

```ld
/* file: linker.ld */
ENTRY(_start)

SECTIONS {
    /* Plant the program at 1 MB in memory. Anything lower is for weaklings */
    . = 1M;

    /* Stick the Multiboot header where GRUB can find it */
    .rodata.multiboot : {
        *(.rodata.multiboot)
    }

    /* This is where the code goes down */
    .text : {
        *(.text)
    }

    /* Read-only data, 'cause sometimes you gotta make promises you can't change */
    .boot.rodata : {
        *(.rodata)
    }

    /* Where the initialized data hangs out */
    .data : {
        *(.data)
    }

    /* And here's where the uninitialized data goes to hide */
    .bss : {
        *(.bss)
    }
}
```

This script makes sure everything is **neatly packed** where it belongs, like putting your code, data, and bss in their little homes.

### Compilation

Time to bring the whole **damn thing to life**. Use this GCC command:

```bash
gcc main.c -Wall -Isrc/include -nostdlib \
-ffreestanding -fno-stack-protector -fno-pic -fno-pie -static -fno-strict-aliasing \
-fno-builtin -fno-omit-frame-pointer -m32 -Wextra -Wall -T linker.ld
```

This command basically says, **"Compiler, do what I tell you and no more, no less!"** No standard library, no fancy protections, just straight up **badass code**.

### Creating a Bootable ISO

Now for the final part: making the ISO file that you can boot with GRUB.

```bash
GRUB_CFG="menuentry \"a.out\" {multiboot /boot/a.out}"

mkdir -p iso/boot/grub
echo $GRUB_CFG > iso/boot/grub/grub.cfg
cp a.out iso/boot/a.out
grub-mkrescue -o os.iso iso
qemu-system-i386 -cdrom os.iso
```

This script builds the ISO and prepares it for GRUB to load. Then, it fires up QEMU, so you can see the **sweet 'H'** on the screen, proving that all your work wasn't in vain.

### Running the Program

To run it, just use:

```bash
qemu-system-i386 -cdrom os.iso
```

Boom! The program boots, and you’ve got that **'H' flashing on the screen like a freaking banner**.

---

So there you go, that’s how you take a bare-metal C program, make GRUB bow down to it, and boot it up on your own terms. It's like being the king of your own little kingdom inside the computer, and nothing can stop you now.