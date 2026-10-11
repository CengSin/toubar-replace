#include "MirrorFrameProcessing.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

static uint32_t randomState = 0x544252;

static uint8_t nextByte(void) {
    randomState = randomState * 1664525 + 1013904223;
    return (uint8_t)(randomState >> 24);
}

int main(void) {
    TBRMirrorFrameProcessor *processor = TBRMirrorFrameProcessorCreate();
    assert(processor != NULL);
    size_t dimensions[][2] = {{1, 1}, {1, 60}, {160, 1}, {9, 7}, {160, 30},
                             {2008, 60}, {2300, 70}, {48, 35}, {8, 8}};
    for (size_t iteration = 0; iteration < 200; iteration++) {
        size_t width = iteration < 9 ? dimensions[iteration][0] : 1 + nextByte();
        size_t height = iteration < 9 ? dimensions[iteration][1] : 1 + nextByte() / 2;
        size_t count = width * height;
        uint8_t *pixels = malloc(count * 4);
        assert(pixels != NULL);
        for (size_t index = 0; index < count; index++) {
            uint8_t alpha = iteration % 3 == 0 ? nextByte() : 255;
            for (size_t channel = 0; channel < 3; channel++) {
                pixels[index * 4 + channel] = (uint8_t)(nextByte() * alpha / 255);
            }
            pixels[index * 4 + 3] = alpha;
        }
        assert(TBRMirrorFrameProcess(processor, pixels, width, height, iteration % 2 ? 24 : 242));
        for (size_t index = 0; index < count; index++) {
            for (size_t channel = 0; channel < 3; channel++) {
                assert(pixels[index * 4 + channel] <= pixels[index * 4 + 3]);
            }
        }
        assert(!TBRMirrorFrameProcess(processor, pixels, 0, height, 24));
        assert(!TBRMirrorFrameProcess(processor, pixels, width, 4097, 24));
        free(pixels);
    }
    TBRMirrorFrameProcessorDestroy(processor);
    TBRMirrorFrameProcessorDestroy(NULL);
    puts("Mirror native safety checks passed: 200 changing dimensions and premultiplied RGBA cases.");
    return 0;
}
