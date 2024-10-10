### X86 boot with GRUB
The GRUB(Grand Unified Boatloader) is a poweful bootloader used in many unix based systems. It allows users to choose between multiple operating systems or kernel configurations at boot time.
GRUB works in two stages:

**Stage 1:** 

This is a small piece of code stored in the MBR that loads a more complex stage 2 bootloader

**Stage 2:**

This is the part of GRUB that provides a user interface for boot options

Let`s look at how we can boot a small barebones C program using GRUB.

#### multiboot header

file: main.c
```c
// out of scope of this blog
#define ALIGNMENT   1 << 0
// out of scope of this blog
#define MEM_INFO    1 << 1
// out of scope of this blog
#define FLAGS       ALIGNMENT | MEM_INFO
// proofs the header is truely multiboot
#define CHECKSUM    -((MAGIC) + (FLAGS))

// lets bootloader find the header
#define MAGIC       0x1badb002 

typedef struct 
{
// Must be MULTIBOOT_MAGIC - see above.
  multiboot_uint32_t magic;

  // out of scope of this blog
  multiboot_uint32_t flags;

  /* The above fields plus this one must equal 0 mod 2^32. */
  multiboot_uint32_t checksum;
} multiboot_header;

// tell the compiler to align the header at 4 byte boundary
__attribute__((aligned(4)))
__attribute__((section(".rodata.multiboot")))
const multiboot_header header = {
    .checksum = CHECKSUM,
    .flags = FLAGS,
    .magic = MAGIC
};
```
#### boot stack

```c
[...]
const struct multiboot_header header = {
    [...]
};

__attribute__((aligned(16)))
char bootstack[4096];

```

#### Entry point and stack set up
```c
[...]
__attribute__((aligned(16)))
char bootstack[4096];

// tell the compiler to generate this function without prologue and epilogue
__attribute__((naked))
int _start() {
    // set frame and stack pointer as the end of the stack since stack grows downwards
    __asm__(
        "movl %0, %%esp\n"
        "movl %%esp, %%ebp\n"
        ::
        "r" (((unsigned int)bootstack) + sizeof(bootstack))
    );
    // jump to our main function after setting the stack
    asm (
        "jmp main"
    );    
}
```

#### Main function
```c
void main()
{
    // write something onto the screen to show we made it
    char *frame_buffer = (char *)0xb8000;
    *frame_buffer = 'H';
    
    // loop forever
    while (1){} 
}
```

### linkerscript
this describes the layout of our program in RAM

```
/*file: linker.ld*/

ENTRY(_start)

SECTIONS {
    /* we want the first address of our program to be loaded at 1mb in RAM*/
    . = 1M;

    /*where the multiboot header goes*/
    .rodata.multiboot : {
		*(.rodata.multiboot)
	}

    /*where code goes*/
    .text : {
        *(.text)
    }

    /*where read only data goes*/
    .boot.rodata : {
        *(rodata)
    }

    /*where read and write data which is initialized goes*/
    .data : {
        *(.data)
    }

    /*where read and write data which is uninitialized goes*/
    .bss : {
        *(.bss)
    }
}

```
### final main.c
```c
// out of scope of this blog
#define ALIGNMENT   1 << 0
// out of scope of this blog
#define MEM_INFO    1 << 1
// out of scope of this blog
#define FLAGS       ALIGNMENT | MEM_INFO
// proofs the header is truely multiboot
#define CHECKSUM    -((MAGIC) + (FLAGS))

// lets bootloader find the header
#define MAGIC       0x1badb002 

typedef struct 
{
// Must be MULTIBOOT_MAGIC - see above.
  int magic;

  // out of scope of this blog
  int flags;

  /* The above fields plus this one must equal 0 mod 2^32. */
  int checksum;
} multiboot_header;

// tell the compiler to align the header at 4 byte boundary
__attribute__((aligned(4)))
__attribute__((section(".rodata.multiboot")))
const multiboot_header header = {
    .checksum = CHECKSUM,
    .flags = FLAGS,
    .magic = MAGIC
};

__attribute__((aligned(16)))
char bootstack[4096];


__attribute__((naked))
int _start() {
    // set frame and stack pointer as the end of the stack since stack grows downwards
    __asm__(
        "movl %0, %%esp\n"
        "movl %%esp, %%ebp\n"
        ::
        "r" (((unsigned int)bootstack) + sizeof(bootstack))
    );
    // jump to our main function after setting the stack
    asm (
        "jmp main"
    );    
}

void main()
{
    // write something onto the screen to show we made it
    char *frame_buffer = (char *)0xb8000;
    *frame_buffer = 'H';
    
    // loop forever
    while (1){} 
}

```

### Compile
```bash
gcc main.c -Wall -Isrc/include -nostdlib \
-ffreestanding -fno-stack-protector -fno-pic -fno-pie -static -fno-strict-aliasing \
-fno-builtin -fno-omit-frame-pointer -m32 -Wextra -Wall -T linker.ld
```

### Make Iso

```bash
    GRUB_CFG="menuentry \"a.out\" {multiboot /boot/a.out}"

	mkdir -p iso/boot/grub
	echo $GRUB_CFG > iso/boot/grub/grub.cfg
    cp a.out iso/boot/a.out
	grub-mkrescue -o os.iso iso
	qemu-system-i386 -cdrom os.iso
```

### Run
```bash
	qemu-system-i386 -cdrom os.iso
```

<img src="https://murymi.github.io/qemu.png">

