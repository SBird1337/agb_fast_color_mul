
#include <gba_console.h>
#include <gba_video.h>
#include <gba_interrupt.h>
#include <gba_systemcalls.h>
#include <gba_input.h>
#include <stdio.h>
#include <stdlib.h>
#include <gba_dma.h>

#include "data.h"

extern void MutateAndColorMultiply(u32 tintColor, u32 mask);

extern u16 g_color_lut[1440];

u32 s_lut_index = 0;
u32 s_cnt = 0;

struct PreservedColorStruct {
    u32 offsetA : 8;
    u32 sizeA : 8;
    u32 offsetB : 8;
    u32 sizeB : 8;
};

struct PreservedColorStruct g_preservation_buffer[8] EWRAM_BSS;

uint16_t s_pltt_buffer[512] EWRAM_BSS;

static inline void CallTintPalettesFast(u32 tintColor, u32 mask)
{
    register int _color asm("r0") = tintColor;
    register int _mask asm("r1") = mask;
    asm ("mov\tlr, %2\n\t.2byte\t0xF800" :: "l" (_color), "l" (_mask), "l" (MutateAndColorMultiply) : "lr");
}

//---------------------------------------------------------------------------------
// Program entry point
//---------------------------------------------------------------------------------
int main(void) {
//---------------------------------------------------------------------------------
        irqInit();
        irqEnable(IRQ_VBLANK);
        SetMode(MODE_0);
        REG_DISPCNT |= BG0_ENABLE;
        REG_BG0CNT = BG_256_COLOR | BG_SIZE_0 | SCREEN_BASE(20);
        dmaCopy(g_tile_data, CHAR_BASE_ADR(0) + 64, 10240);
        dmaCopy(g_map_data, MAP_BASE_ADR(20), 1280);
        dmaCopy(g_pal_data, s_pltt_buffer, 512);
        while(true) {
            
            // VDraw

            VBlankIntrWait();
            
            // VBlank

            CallTintPalettesFast(g_color_lut[s_lut_index], 0x00FF1FFF);
            s_lut_index++;
            if (s_lut_index == 1440) {
                s_lut_index = 0;
            }
        }
}


