# MetalMap API

## Function Details

### Common Data Types
```c
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct {
    uint32_t x;
    uint32_t z;
} MetalMapQuery;

typedef struct {
    MetalMapQuery query;
    float amount;
} MetalMapSample;

typedef struct {
    MetalMapQuery query;
    float amount;
} MetalMapWriteRequest;
```

### Spring.GetMetalMapSize
- **Lua:** `Spring.GetMetalMapSize()`
- **Native:** `MetalMapSizeResult (*getMetalMapSize)(void);`
```c
typedef struct {
    const Error* error;
    uint32_t mapWidth;
    uint32_t mapHeight;
} MetalMapSizeResult;
```

### Spring.GetMetalAmount
- **Lua:** `Spring.GetMetalAmount(x, z)`
- **Native:** `MetalMapSampleResult (*getMetalAmount)(MetalMapQuery query);`
```c
typedef struct {
    const Error* error;
    MetalMapSample sample;
} MetalMapSampleResult;
```

### Spring.SetMetalAmount
- **Lua:** `Spring.SetMetalAmount(x, z, amount)`
- **Native:** `MetalMapWriteResult (*setMetalAmount)(MetalMapWriteRequest request);`
```c
typedef struct {
    const Error* error;
    MetalMapSample sample;
} MetalMapWriteResult;
```

### Spring.GetMetalExtraction
- **Lua:** `Spring.GetMetalExtraction(x, z)`
- **Native:** `MetalMapSampleResult (*getMetalExtraction)(MetalMapQuery query);`

## API Table
```c
typedef struct MetalMapApi {
    MetalMapSizeResult  (*getMetalMapSize)(void);
    MetalMapSampleResult (*getMetalAmount)(MetalMapQuery query);
    MetalMapSampleResult (*getMetalExtraction)(MetalMapQuery query);
    MetalMapWriteResult  (*setMetalAmount)(MetalMapWriteRequest request);
} MetalMapApi;
```
Exposed on `NativeInterface` as `const MetalMapApi* metalMap;`.

## Engine Integration Notes
- If `result->error` is non-null the call failed; otherwise the payload is valid.
- All structs are POD; no dynamic allocation is required.
