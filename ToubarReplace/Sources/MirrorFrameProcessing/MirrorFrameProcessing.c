#include "MirrorFrameProcessing.h"
#include <stdlib.h>
#include <string.h>

struct TBRMirrorFrameProcessor {
    uint8_t *storage;
    size_t capacity;
    uint8_t *background;
    uint8_t *preserved;
    uint8_t *visited;
    uint8_t *source;
    uint32_t *flood;
};

static inline int maximum(int a, int b) { return a > b ? a : b; }
static inline int minimum(int a, int b) { return a < b ? a : b; }

static inline int luminance(const uint8_t *pixel) {
    return (pixel[0] + pixel[1] + pixel[2]) / 3;
}

static inline int chroma(const uint8_t *pixel) {
    return maximum(pixel[0], maximum(pixel[1], pixel[2]))
        - minimum(pixel[0], minimum(pixel[1], pixel[2]));
}

static inline bool isColored(const uint8_t *pixel) {
    return pixel[3] > 0 && chroma(pixel) > 16
        && maximum(pixel[0], maximum(pixel[1], pixel[2])) >= 40;
}

static inline bool isBackground(const uint8_t *pixel, int base) {
    return pixel[3] == 255 && abs(pixel[0] - base) <= 8
        && abs(pixel[1] - base) <= 8 && abs(pixel[2] - base) <= 8;
}

TBRMirrorFrameProcessor *TBRMirrorFrameProcessorCreate(void) {
    return calloc(1, sizeof(TBRMirrorFrameProcessor));
}

void TBRMirrorFrameProcessorDestroy(TBRMirrorFrameProcessor *processor) {
    if (processor == NULL) { return; }
    free(processor->storage);
    free(processor);
}

static bool reserve(TBRMirrorFrameProcessor *processor, size_t count) {
    if (processor->capacity == count) { return true; }
    size_t maskBytes = (count * 3 + 3) & ~(size_t)3;
    uint8_t *storage = malloc(maskBytes + count * (sizeof(uint32_t) + 4));
    if (storage == NULL) { return false; }
    free(processor->storage);
    processor->storage = storage;
    processor->capacity = count;
    processor->background = storage;
    processor->preserved = storage + count;
    processor->visited = storage + count * 2;
    processor->flood = (uint32_t *)(storage + maskBytes);
    processor->source = storage + maskBytes + count * sizeof(uint32_t);
    return true;
}

static void inferBackground(TBRMirrorFrameProcessor *processor, const uint8_t *rgba,
                            size_t width, size_t height) {
    uint8_t *background = processor->background;
    memset(background, 255, width * height);
    size_t minimumRun = (size_t)maximum(8, (int)height / 3);
    for (size_t y = 0; y < height; y++) {
        size_t row = y * width;
        size_t x = 0;
        while (x < width) {
            const uint8_t *pixel = rgba + (row + x) * 4;
            int base = luminance(pixel);
            if (pixel[3] != 255 || base > 96 || chroma(pixel) > 8) { x++; continue; }
            size_t end = x + 1;
            while (end < width) {
                const uint8_t *next = rgba + (row + end) * 4;
                if (next[3] != 255 || chroma(next) > 8 || abs(luminance(next) - base) > 6) { break; }
                end++;
            }
            if (end - x >= minimumRun) { memset(background + row + x, base, end - x); }
            x = end;
        }
    }
    for (size_t x = 0; x < width; x++) {
        size_t y = 0;
        while (y < height) {
            if (background[y * width + x] != 255) { y++; continue; }
            size_t end = y + 1;
            while (end < height && background[end * width + x] == 255) { end++; }
            int top = y > 0 ? background[(y - 1) * width + x] : -1;
            int bottom = end < height ? background[end * width + x] : -1;
            if (top >= 0 || bottom >= 0) {
                for (size_t position = y; position < end; position++) {
                    int base = top < 0 ? bottom : bottom < 0 ? top
                        : top + (bottom - top) * (int)(position - y + 1) / (int)(end - y + 1);
                    background[position * width + x] = (uint8_t)base;
                }
            }
            y = end;
        }
    }
    for (size_t y = 0; y < height; y++) {
        size_t row = y * width;
        size_t x = 0;
        while (x < width) {
            if (background[row + x] != 255) { x++; continue; }
            size_t end = x + 1;
            while (end < width && background[row + end] == 255) { end++; }
            int left = x > 0 ? background[row + x - 1] : -1;
            int right = end < width ? background[row + end] : -1;
            for (size_t position = x; position < end; position++) {
                int base = left < 0 ? maximum(right, 0) : right < 0 ? left
                    : position - x < end - position ? left : right;
                background[row + position] = (uint8_t)base;
            }
            x = end;
        }
    }
}

static void visitColor(TBRMirrorFrameProcessor *processor, const uint8_t *rgba,
                       uint32_t index, size_t *tail) {
    if (processor->visited[index] == 0 && isColored(rgba + (size_t)index * 4)) {
        processor->visited[index] = 1;
        processor->flood[(*tail)++] = index;
    }
}

static void preserveArtwork(TBRMirrorFrameProcessor *processor, const uint8_t *rgba,
                            size_t width, size_t height) {
    size_t count = width * height;
    memset(processor->preserved, 0, count * 2);
    for (size_t index = 0; index < count; index++) {
        if (processor->visited[index] != 0 || !isColored(rgba + index * 4)) { continue; }
        size_t head = 0, tail = 0;
        visitColor(processor, rgba, (uint32_t)index, &tail);
        int minX = (int)(index % width), maxX = minX;
        int minY = (int)(index / width), maxY = minY;
        while (head < tail) {
            uint32_t current = processor->flood[head++];
            int x = (int)(current % width), y = (int)(current / width);
            minX = minimum(minX, x); maxX = maximum(maxX, x);
            minY = minimum(minY, y); maxY = maximum(maxY, y);
            if (x > 0) { visitColor(processor, rgba, current - 1, &tail); }
            if ((size_t)x + 1 < width) { visitColor(processor, rgba, current + 1, &tail); }
            if (y > 0) { visitColor(processor, rgba, current - (uint32_t)width, &tail); }
            if ((size_t)y + 1 < height) { visitColor(processor, rgba, current + (uint32_t)width, &tail); }
        }
        if (tail < 4) { continue; }
        minX = maximum(0, minX - 2); maxX = minimum((int)width - 1, maxX + 2);
        minY = maximum(0, minY - 2); maxY = minimum((int)height - 1, maxY + 2);
        for (int y = minY; y <= maxY; y++) {
            memset(processor->preserved + (size_t)y * width + minX, 1, (size_t)(maxX - minX + 1));
        }
    }
    size_t head = 0, tail = 0;
    for (size_t index = 0; index < count; index++) {
        if (processor->preserved[index] == 0
            || !isBackground(rgba + index * 4, processor->background[index])) { continue; }
        size_t x = index % width, y = index / width;
        if (x == 0 || x + 1 == width || y == 0 || y + 1 == height
            || processor->preserved[index - 1] == 0 || processor->preserved[index + 1] == 0
            || processor->preserved[index - width] == 0 || processor->preserved[index + width] == 0) {
            processor->preserved[index] = 0;
            processor->flood[tail++] = (uint32_t)index;
        }
    }
    while (head < tail) {
        uint32_t index = processor->flood[head++];
        size_t x = index % width, y = index / width;
        uint32_t neighbors[4] = {
            x > 0 ? index - 1 : index, x + 1 < width ? index + 1 : index,
            y > 0 ? index - (uint32_t)width : index,
            y + 1 < height ? index + (uint32_t)width : index
        };
        for (int n = 0; n < 4; n++) {
            uint32_t neighbor = neighbors[n];
            if (processor->preserved[neighbor] != 0
                && isBackground(rgba + (size_t)neighbor * 4, processor->background[neighbor])) {
                processor->preserved[neighbor] = 0;
                processor->flood[tail++] = neighbor;
            }
        }
    }
}

static void unmatteColorEdge(const TBRMirrorFrameProcessor *processor, const uint8_t *rgba,
                             size_t width, size_t height, size_t index, uint8_t *output) {
    const uint8_t *pixel = rgba + index * 4;
    if (processor->visited[index] > 3 || isBackground(pixel, processor->background[index])) { return; }
    int x = (int)(index % width), y = (int)(index / width);
    int peak = maximum(pixel[0], maximum(pixel[1], pixel[2]));
    int closest = 100, base = 0;
    for (int row = maximum(0, y - 3); row <= minimum((int)height - 1, y + 3); row++) {
        for (int column = maximum(0, x - 3); column <= minimum((int)width - 1, x + 3); column++) {
            size_t neighbor = (size_t)row * width + column;
            const uint8_t *sample = rgba + neighbor * 4;
            if (processor->preserved[neighbor]) {
                peak = maximum(peak, maximum(sample[0], maximum(sample[1], sample[2])));
            } else if (processor->preserved[neighbor] == 0
                       && isBackground(sample, processor->background[neighbor])) {
                int distance = abs(column - x) + abs(row - y);
                if (distance < closest) { closest = distance; base = processor->background[neighbor]; }
            }
        }
    }
    if (closest > 3 || peak <= base) { return; }
    int maximumValue = maximum(pixel[0], maximum(pixel[1], pixel[2]));
    int alpha = minimum(255, maximum(0, (maximumValue - base) * 255 / (peak - base)));
    int matte = (base * (255 - alpha) + 127) / 255;
    for (int channel = 0; channel < 3; channel++) {
        output[channel] = (uint8_t)minimum(alpha, maximum(0, pixel[channel] - matte));
    }
    output[3] = (uint8_t)alpha;
}

static void measureEdgeDistance(TBRMirrorFrameProcessor *processor, const uint8_t *rgba,
                                size_t width, size_t height) {
    size_t count = width * height;
    for (size_t index = 0; index < count; index++) {
        int distance = processor->preserved[index] == 0
            && isBackground(rgba + index * 4, processor->background[index]) ? 0 : 4;
        if (index % width > 0) { distance = minimum(distance, processor->visited[index - 1] + 1); }
        if (index >= width) { distance = minimum(distance, processor->visited[index - width] + 1); }
        processor->visited[index] = (uint8_t)distance;
    }
    for (size_t position = count; position > 0; position--) {
        size_t index = position - 1;
        int distance = processor->visited[index];
        if (index % width + 1 < width) { distance = minimum(distance, processor->visited[index + 1] + 1); }
        if (index + width < count) { distance = minimum(distance, processor->visited[index + width] + 1); }
        processor->visited[index] = (uint8_t)distance;
    }
}

bool TBRMirrorFrameProcess(TBRMirrorFrameProcessor *processor, uint8_t *rgba,
                          size_t width, size_t height, uint8_t foreground) {
    if (width == 0 || height == 0 || width > 16384 || height > 4096
        || width * height > UINT32_MAX || !reserve(processor, width * height)) { return false; }
    inferBackground(processor, rgba, width, height);
    preserveArtwork(processor, rgba, width, height);
    measureEdgeDistance(processor, rgba, width, height);
    memcpy(processor->source, rgba, width * height * 4);
    for (size_t index = 0; index < width * height; index++) {
        uint8_t *pixel = rgba + index * 4;
        if (pixel[3] != 255) { continue; }
        if (processor->preserved[index] != 0) {
            uint8_t edge[4] = {pixel[0], pixel[1], pixel[2], pixel[3]};
            unmatteColorEdge(processor, processor->source, width, height, index, edge);
            memcpy(pixel, edge, 4);
        } else if (chroma(pixel) <= 16) {
            int base = processor->background[index];
            int alpha = minimum(255, maximum(0, (luminance(pixel) - base) * 255 / (255 - base)));
            uint8_t value = (uint8_t)((foreground * alpha + 127) / 255);
            pixel[0] = value; pixel[1] = value; pixel[2] = value; pixel[3] = (uint8_t)alpha;
        }
    }
    return true;
}
