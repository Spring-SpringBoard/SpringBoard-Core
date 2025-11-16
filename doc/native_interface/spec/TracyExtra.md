# TracyExtra API

## Function Details

### Common Data Types
```c
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef enum {
    TracyPlotFormat_Number,
    TracyPlotFormat_Percentage,
    TracyPlotFormat_Memory,
} TracyPlotFormat;

typedef struct {
    const char* plotName;
    TracyPlotFormat format;
    bool stepwise;
    bool fill;
    uint32_t colorBgr;
} TracyPlotConfigRequest;

typedef struct {
    const char* plotName;
    float value;
} TracyPlotSample;

typedef struct {
    const Error* error;
} TracyResult;
```

### tracy.LuaTracyPlotConfig
- **Lua:** `tracy.LuaTracyPlotConfig(plotName, format?, stepwise?, fill?, color?)`
- **Native:** `TracyResult (*PlotConfig)(const TracyPlotConfigRequest* request);`

### tracy.LuaTracyPlot
- **Lua:** `tracy.LuaTracyPlot(plotName, value)`
- **Native:** `TracyResult (*PlotSample)(const TracyPlotSample* sample);`

## API Table
```c
typedef struct TracyExtraApi {
    TracyResult (*PlotConfig)(const TracyPlotConfigRequest*);
    TracyResult (*PlotSample)(const TracyPlotSample*);
} TracyExtraApi;
```
`TracyExtraApi` is exposed on `NativeInterface` as `const TracyExtraApi* tracyExtra;`.

## Notes
- Plot names must reference UTF-8 strings owned by the caller for the duration of the call; the engine caches copies as needed.

