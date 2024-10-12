To understand the process of booting a small C program using GRUB (Grand Unified Bootloader), we must first grasp the basic structure and mechanism of GRUB, which works in two stages:

**Stage 1:**  
This is a minimal piece of code placed in the Master Boot Record (MBR) of the storage device, responsible for loading the more complex Stage 2 bootloader.  

**Stage 2:**  
This part of GRUB provides the user with an interface, allowing them to choose which operating system or kernel to boot, should there be multiple options.

Now, let us see how we can boot a simple bare-metal program using GRUB.

### Multiboot Header

The Multiboot header is essential for the bootloader to understand how to load the kernel. The following code defines it:

```c
// Align the loaded binary to a page boundary
#define ALIGNMENT   1 << 0

// Request memory information from the BIOS
#define MEM_INFO    1 << 1

// Define the flags with the above options
#define FLAGS       ALIGNMENT | MEM_INFO

// The "magic" number proves that this header is a true Multiboot header
#define MAGIC       0x1badb002 

// The checksum ensures that the sum of MAGIC, FLAGS, and CHECKSUM equals zero
#define CHECKSUM    -((MAGIC) + (FLAGS))

// Structure to represent the Multiboot header
typedef struct 
{
  // Must match the Multiboot MAGIC number for the loader to recognize it
  multiboot_uint32_t magic;

  // Describes the features requested from the bootloader
  multiboot_uint32_t flags;

  // The sum of magic, flags, and this value must equal zero
  multiboot_uint32_t checksum;
} multiboot_header;

// The compiler is instructed to align the Multiboot header on a 4-byte boundary
__attribute__((aligned(4)))
__attribute__((section(".rodata.multiboot")))
const multiboot_header header = {
    .magic = MAGIC,
    .flags = FLAGS,
    .checksum = CHECKSUM
};
```

The `MAGIC` number (`0x1badb002`) tells the bootloader that this is a Multiboot-compliant header. The `FLAGS` indicate alignment and memory information, while the `CHECKSUM` ensures the total sum of the `MAGIC`, `FLAGS`, and `CHECKSUM` fields is zero, verifying the header's integrity.

### Boot Stack

Next, we define a boot stack for the kernel, which is a temporary area of memory where the program's execution begins.

```c
__attribute__((aligned(16)))
char bootstack[4096];
```

This allocates a 4 KB stack aligned to a 16-byte boundary.

### Entry Point and Stack Setup

The program must have an entry point where execution begins. In this case, we define it with the following code:

```c
__attribute__((naked))
int _start() {
    // Set the stack pointer to the end of the bootstack array
    __asm__(
        "movl %0, %%esp\n"
        "movl %%esp, %%ebp\n"
        ::
        "r" (((unsigned int)bootstack) + sizeof(bootstack))
    );
    
    // Jump to the main function
    __asm__("jmp main");
}
```

The function `_start` is marked as `naked`, which instructs the compiler not to generate standard function prologues or epilogues, making it suitable for low-level boot code. The stack pointer (`esp`) and frame pointer (`ebp`) are set to point to the end of the boot stack, and control is then passed to the `main` function.

### Main Function

The main function will display a single character on the screen using the VGA framebuffer:

```c
void main() {
    // The VGA framebuffer starts at address 0xb8000
    char *frame_buffer = (char *)0xb8000;
    
    // Write the letter 'H' to the framebuffer
    *frame_buffer = 'H';
    
    // Enter an infinite loop to halt the program
    while (1) {}
}
```

Here, the VGA framebuffer is mapped at memory address `0xb8000`. Writing a character here directly manipulates the screen output in text mode.

### Linker Script

The linker script describes how the various sections of the program should be arranged in memory:

```ld
/* file: linker.ld */
ENTRY(_start)

SECTIONS {
    /* Place the program at 1 MB in memory */
    . = 1M;

    /* Multiboot header section */
    .rodata.multiboot : {
        *(.rodata.multiboot)
    }

    /* Code section */
    .text : {
        *(.text)
    }

    /* Read-only data section */
    .boot.rodata : {
        *(.rodata)
    }

    /* Initialized data section */
    .data : {
        *(.data)
    }

    /* Uninitialized data (BSS) section */
    .bss : {
        *(.bss)
    }
}
```

This script places the Multiboot header, code, and data in appropriate memory locations. The entry point is set to `_start`, and the entire program is loaded at 1 MB (`1M`), which is the standard location for kernel images.

### Compilation

To compile the program, we use the following GCC command:

```bash
gcc main.c -Wall -Isrc/include -nostdlib \
-ffreestanding -fno-stack-protector -fno-pic -fno-pie -static -fno-strict-aliasing \
-fno-builtin -fno-omit-frame-pointer -m32 -Wextra -Wall -T linker.ld
```

This command compiles the program in 32-bit mode (`-m32`) without linking the standard library (`-nostdlib`) and ensures that no stack protection, position-independent code, or other unwanted compiler features are enabled.

### Creating an ISO Image

To boot this program using GRUB, we need to create a bootable ISO image:

```bash
GRUB_CFG="menuentry \"a.out\" {multiboot /boot/a.out}"

mkdir -p iso/boot/grub
echo $GRUB_CFG > iso/boot/grub/grub.cfg
cp a.out iso/boot/a.out
grub-mkrescue -o os.iso iso
qemu-system-i386 -cdrom os.iso
```

This script prepares the necessary files for GRUB, including a configuration file (`grub.cfg`) and the compiled binary (`a.out`). The `grub-mkrescue` command creates a bootable ISO file (`os.iso`), which can be tested using QEMU (`qemu-system-i386`).

### Running the Program

Finally, to run the bootable ISO image in QEMU:

```bash
qemu-system-i386 -cdrom os.iso
```

This will launch the program in an emulated x86 environment, and you should see the letter 'H' displayed on the screen, proving that the program has successfully booted and is running.

Thanks for wasting your time. 