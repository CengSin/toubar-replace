#ifndef MirrorFrameProcessing_h
#define MirrorFrameProcessing_h

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct TBRMirrorFrameProcessor TBRMirrorFrameProcessor;

TBRMirrorFrameProcessor * _Nullable TBRMirrorFrameProcessorCreate(void);
void TBRMirrorFrameProcessorDestroy(TBRMirrorFrameProcessor * _Nullable processor);
bool TBRMirrorFrameProcess(
    TBRMirrorFrameProcessor * _Nonnull processor,
    uint8_t * _Nonnull rgba,
    size_t width,
    size_t height,
    uint8_t foreground
);

#endif
