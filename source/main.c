
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

#define RGB_NIGHT RGB5(15, 15, 24)
#define RGB_MORNING RGB5(23, 21, 28)
#define RGB_DAY RGB5(31, 31, 31)
#define RGB_EVENING RGB5(28, 22, 22)

#define GET_R(color) ((color) & 0x1F)
#define GET_G(color) (((color) >> 5) & 0x1F)
#define GET_B(color) (((color) >> 10) & 0x1F)

struct Time {
    uint32_t hours;
    uint32_t minutes;
};

static uint16_t s_dn_cycle_hours_lut[] = {
    [0] = RGB_NIGHT,
    [1] = RGB_NIGHT,
    [2] = RGB_NIGHT,
    [3] = RGB_NIGHT,
    [4] = RGB_NIGHT,
    [5] = RGB_NIGHT,

    [6] = RGB_MORNING,
    [7] = RGB_MORNING,
    [8] = RGB_MORNING,
    [9] = RGB_MORNING,
    [10] = RGB_MORNING,
    [11] = RGB_MORNING,

    [12] = RGB_DAY,
    [13] = RGB_DAY,
    [14] = RGB_DAY,
    [15] = RGB_DAY,
    [16] = RGB_DAY,

    [17] = RGB_EVENING,
    [18] = RGB_EVENING,
    [19] = RGB_EVENING,
    [20] = RGB_NIGHT,
    [21] = RGB_NIGHT,
    [22] = RGB_NIGHT,
    [23] = RGB_NIGHT,
};

struct Time s_time = { 0, 0 };

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

uint16_t lerpRgbOverHour (uint16_t a, uint16_t b, uint32_t minute) {
    const uint32_t divorg = 1092;
    uint32_t ra = GET_R(a);
    uint32_t ga = GET_G(a);
    uint32_t ba = GET_B(a);
    uint32_t rb = GET_R(b);
    uint32_t gb = GET_G(b);
    uint32_t bb = GET_B(b);
    ra = (divorg * (ra * (60 - minute) + (rb * minute))) >> 16;
    ga = (divorg * (ga * (60 - minute) + (gb * minute))) >> 16;
    ba = (divorg * (ba * (60 - minute) + (bb * minute))) >> 16;
    return (ra | (ga << 5) | (ba << 10));
}

uint16_t getMulColor (struct Time *time) {
    uint32_t hour = time->hours;
    uint32_t nextHour = (hour + 1) % 24;
    return lerpRgbOverHour(s_dn_cycle_hours_lut[hour], s_dn_cycle_hours_lut[nextHour], time->minutes);
}

void AdvanceMinute (struct Time *time) {
    time->minutes++;
    if (time->minutes == 60) {
        time->minutes = 0;
        time->hours++;
        if (time->hours == 24) {
            time->hours = 0;
        }
    }
}

//---------------------------------------------------------------------------------
// Program entry point
//---------------------------------------------------------------------------------
int main(void) {
//---------------------------------------------------------------------------------
        irqInit();
        irqEnable(IRQ_VBLANK);
        consoleInit(1, 24, 1, NULL, 0, 15);
        SetMode(MODE_0);
        REG_DISPCNT |= (BG0_ENABLE | BG1_ENABLE);
        REG_BG0CNT = BG_256_COLOR | BG_SIZE_0 | SCREEN_BASE(20) | BG_PRIORITY(1);
        REG_BG1CNT |= BG_PRIORITY(0);
        dmaCopy(g_tile_data, CHAR_BASE_ADR(0) + 64, 10240);
        dmaCopy(g_map_data, MAP_BASE_ADR(20), 1280);
        dmaCopy(g_pal_data, s_pltt_buffer, 512);
        s_pltt_buffer[241] = RGB5(31,31,31);
        uint32_t frames = 0;
        while(true) {
            
            // VDraw

            AdvanceMinute(&s_time);

            iprintf("\x1b[2J%02ld:%02ld", s_time.hours, s_time.minutes);
            VBlankIntrWait();
            
            // VBlank

            CallTintPalettesFast(getMulColor(&s_time), 0x00FF1FFF);
        }
}


