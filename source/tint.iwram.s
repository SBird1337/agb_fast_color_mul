.arm
.global TintPalettesFast
.global g_preservation_buffer
.extern s_pltt_buffer
.align 2

.equ IO_BASE, 0x04000000
.equ REG_DMA3SAD, 0xD4


@ Uses a MUL instruction to ColorMultiply 2 components
@ Needs a mul_tmp_reg to store the result in order to not clobber the result register
@ TODO: Check if this is really a problem on real HW
.macro tint_single_word word_reg:req, mask_reg:req, red_reg:req, green_reg:req, blue_reg:req, tmp_reg:req, tmp_out_reg:req, mul_tmp_reg:req
    and \tmp_reg, \mask_reg, \word_reg
    mul \mul_tmp_reg, \tmp_reg, \red_reg
    and \tmp_out_reg, \mask_reg, \mul_tmp_reg, lsr #5

    and \tmp_reg, \mask_reg, \word_reg, lsr #5
    mul \mul_tmp_reg, \tmp_reg, \green_reg
    and \tmp_reg, \mask_reg, \mul_tmp_reg, lsr #5
    orr \tmp_out_reg, \tmp_out_reg, \tmp_reg, lsl #5

    and \tmp_reg, \mask_reg, \word_reg, lsr #10
    mul \mul_tmp_reg, \tmp_reg, \blue_reg
    and \tmp_reg, \mask_reg, \mul_tmp_reg, lsr #5
    orr \word_reg, \tmp_out_reg, \tmp_reg, lsl #10
.endm

@ void TintPalettes(uint16_t mulColor, uint32_t bitmask)
TintPalettesFast:
    .word 0xe3104778
    push {r4-r12, lr}

@ Buffer SP so we can use it as GP register
    adr r2, sp_buffer
    str sp, [r2]

@ Calculate Bitmask 0x001F001F
    mov r9, #0x1F
    orr r9, r9, r9, lsl #16

@ Green Parameter
    and r4, r9, r0, lsr #5

@ Blue Parameter
    and lr, r9, r0, lsr #10

@ Red Parameter
    and r0, r0, #0x1F

@ Base Addresses
    ldr r11, =s_pltt_buffer
    ldr r12, =0x05000000 @PRAM

tint_loop:
    lsrs r1, #1
    bcs tint_inner
    beq tail_copy

@ If the palette is masked, issue blank copy operation
@ NOTE: Possible optimization if registers are renamed: Use only one ldm/stm pair.
    ldmia r11!, {r5-r8}
    stmia r12!, {r5-r8}
    ldmia r11!, {r5-r8}
    stmia r12!, {r5-r8}
    b tint_loop
tint_inner:
    ldmia r11!, {r5-r8}
    tint_single_word r5, r9, r0, r4, lr, r3, r2, sp
    tint_single_word r6, r9, r0, r4, lr, r3, r2, sp
    tint_single_word r7, r9, r0, r4, lr, r3, r2, sp
    tint_single_word r8, r9, r0, r4, lr, r3, r2, sp
    stmia r12!, {r5-r8}
    tst r12, #0x10
    bne tint_inner
    b tint_loop
tail_copy:

    mov r3, #IO_BASE
    orr r3, #REG_DMA3SAD
    sub r10, r12, #0x05000000
    rsb r10, r10, #0x400
    mov sp, #0x84000000
    orr sp, sp, r10, lsr #2
    stmia r3, {r11-sp}

/*  size/offset in palette entries
    struct PreservedColorStruct {
        u32 offsetA : 8;
        u32 sizeA : 8;
        u32 offsetB : 8;
        u32 sizeB : 8;
    };
*/

color_preservation:
    adr r0, g_preservation_buffer

@ NOTE: Maybe restore these values from the previous iterations if possible to save one load
    mov r5, #0x80000000
    ldr r6, =s_pltt_buffer
    mov r7, #0x05000000

preservation_loop:
    ldmia r0!, {r1}

    ands r2, r1, #0xFF
    beq return
    and r7, r1, #0xFF00
    add r10, r6, r2, lsl #1
    add r11, r7, r2, lsl #1
    orr r12, r5, r7, lsr #8
    stmia r8, {r10-r12}
    ands r2, r1, #0xFF0000
    beq return
    and r7, r1, #0xFF000000
    add r10, r6, r2, lsr #15
    add r11, r7, r2, lsr #15
    orr r12, r5, r7, lsr #24
    
    stmia r3, {r10-r12}
    b preservation_loop
return:
    adr r2, sp_buffer
    ldr sp, [r2]
    pop {r4-r12, lr}
    bx lr

sp_buffer:
    .word 0

g_preservation_buffer:
    .space 32