.arm
.global MutateAndColorMultiply
.extern s_pltt_buffer
.extern g_preservation_buffer
.align 2

.equ IO_BASE, 0x04000000
.equ REG_DMA3SAD, 0xD4
.equ PRAM, 0x05000000


@ Uses a MUL instruction to ColorMultiply 2 components
@ Needs a mul_tmp_reg to store the result in order to not corrupt the result register
.macro tint_single_word word_reg:req, mask_reg:req, red_reg:req, green_reg:req, blue_reg:req, tmp_reg:req, tmp_out_reg:req, mul_tmp_reg:req

@ Red Component
    and \tmp_reg, \mask_reg, \word_reg
    mul \mul_tmp_reg, \tmp_reg, \red_reg
    and \tmp_out_reg, \mask_reg, \mul_tmp_reg, lsr #5

@ Blue Component
    and \tmp_reg, \mask_reg, \word_reg, lsr #5
    mul \mul_tmp_reg, \tmp_reg, \green_reg
    and \tmp_reg, \mask_reg, \mul_tmp_reg, lsr #5
    orr \tmp_out_reg, \tmp_out_reg, \tmp_reg, lsl #5

@ Green Component
    and \tmp_reg, \mask_reg, \word_reg, lsr #10
    mul \mul_tmp_reg, \tmp_reg, \blue_reg
    and \tmp_reg, \mask_reg, \mul_tmp_reg, lsr #5

@ Writeback
    orr \word_reg, \tmp_out_reg, \tmp_reg, lsl #10
.endm

@ void MutateAndColorMultiply (u16 color, u32 mask)
MutateAndColorMultiply:

@ Valid ARM instruction (tst)
@ Valid THUMB instruction (bx pc)
@ Switches the CPU to ARM mode for interworking
    .word 0xe3104778
    push { r4-r12, lr }

@ Calculate Bitmask 0x001F001F
    mov r2, #0x1F
    orr r2, r2, r2, lsl #16

@ Green Parameter
    and r3, r2, r0, lsr #5

@ Blue Parameter
    and r4, r2, r0, lsr #10

@ Red Parameter
    and r0, r0, #0x1F

@ Base Addresses
    ldr r5, =s_pltt_buffer
    mov r6, #PRAM

tint_loop:

@ If the mask parameter has no more bits we can `tail_copy` the remaining colors
    lsrs r1, #1
    bcs tint_inner
    beq tail_copy

@ Palette is masked (C == 1), issue blank copy operation
    ldmia r5!, { r7-r10 }
    stmia r6!, { r7-r10 }
    ldmia r5!, { r7-r10 }
    stmia r6!, { r7-r10 }
    b tint_loop
tint_inner:

@ Tint half of a palette using r7-r10
    ldmia r5!, { r7-r10 }
    tint_single_word r7, r2, r0, r3, r4, r11, r12, lr
    tint_single_word r8, r2, r0, r3, r4, r11, r12, lr
    tint_single_word r9, r2, r0, r3, r4, r11, r12, lr
    tint_single_word r10, r2, r0, r3, r4, r11, r12, lr
    stmia r6!, { r7-r10 }

@ Check if we are in the middle of a palette and tint the other half if necessary
    tst r6, #0x10
    bne tint_inner
    b tint_loop
tail_copy:

@ Copy The rest of the colors using DMA 3
    mov r3, #IO_BASE
    orr r3, #REG_DMA3SAD
    sub r10, r6, #PRAM
    rsb r10, r10, #0x400
    mov r7, #0x84000000
    orr r7, r7, r10, lsr #2
    stmia r3, {r5-r7}

@ Re-Copy "preserved" color slots (set `struct PreservedColorStruct`)
color_preservation:
    ldr r0, =g_preservation_buffer
    mov r5, #0x80000000
    ldr r6, =s_pltt_buffer
    mov r7, #PRAM

preservation_loop:
    ldmia r0!, {r1}

    ands r2, r1, #0xFF
    beq return
    and r7, r1, #0xFF00
    add r10, r6, r2, lsl #1
    add r11, r7, r2, lsl #1
    orr r12, r5, r7, lsr #8
    stmia r8, { r10-r12 }
    ands r2, r1, #0xFF0000
    beq return
    and r7, r1, #0xFF000000
    add r10, r6, r2, lsr #15
    add r11, r7, r2, lsr #15
    orr r12, r5, r7, lsr #24
    
    stmia r3, { r10-r12 }
    b preservation_loop
return:
    pop { r4-r12, lr }
    bx lr
