# MathExtra API

## Function Details

### Common Data Types
```c
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct {
    const float* values;
    size_t length;
} MathFloatView;

typedef struct {
    const int32_t* values;
    size_t length;
} MathIntView;

typedef struct {
    float value;
    bool hasDecimals;
    int32_t decimals;
} MathRoundRequest;

typedef struct {
    const Error* error;
    float value;
} MathFloatResult;

typedef struct {
    const Error* error;
    int32_t value;
} MathIntResult;

typedef struct {
    const Error* error;
    bool value;
} MathBoolResult;

typedef struct {
    MathFloatView input;
    float* output;
    size_t outputLength;
} MathNormalizeRequest;

typedef struct {
    const Error* error;
    size_t valuesWritten;
} MathWriteResult;
```

### math.hypot
- **Lua:** `math.hypot(x, y)`
- **Native:** `MathFloatResult (*Hypot)(float x, float y);`

### math.diag
- **Lua:** `math.diag(x, ...)`
- **Native:** `MathFloatResult (*Diag)(MathFloatView values);`

### math.clamp
- **Lua:** `math.clamp(value, min, max)`
- **Native:** `MathFloatResult (*Clamp)(float value, float minValue, float maxValue);`

### math.sgn
- **Lua:** `math.sgn(x)`
- **Native:** `MathFloatResult (*Sgn)(float value);`

### math.mix
- **Lua:** `math.mix(x, y, a)`
- **Native:** `MathFloatResult (*Mix)(float x, float y, float a);`

### math.round
- **Lua:** `math.round(x, decimals?)`
- **Native:** `MathFloatResult (*RoundScalar)(MathRoundRequest request);`

### math.erf
- **Lua:** `math.erf(x)`
- **Native:** `MathFloatResult (*ErfScalar)(float value);`

### math.smoothstep
- **Lua:** `math.smoothstep(edge0, edge1, v)`
- **Native:** `MathFloatResult (*Smoothstep)(float edge0, float edge1, float value);`

### math.normalize
- **Lua:** `math.normalize(x, ...)`
- **Native:** `MathWriteResult (*Normalize)(MathNormalizeRequest request);`

### math.bit_or
- **Lua:** `math.bit_or(...)`
- **Native:** `MathIntResult (*BitOr)(MathIntView values);`

### math.bit_and
- **Lua:** `math.bit_and(...)`
- **Native:** `MathIntResult (*BitAnd)(MathIntView values);`

### math.bit_xor
- **Lua:** `math.bit_xor(...)`
- **Native:** `MathIntResult (*BitXor)(MathIntView values);`

### math.bit_inv
- **Lua:** `math.bit_inv(value)`
- **Native:** `MathIntResult (*BitInv)(int32_t value);`

### math.bit_bits
- **Lua:** `math.bit_bits(...)`
- **Native:** `MathIntResult (*BitBits)(MathIntView bitIndices);`

## API Table
```c
typedef struct MathExtraApi {
    MathFloatResult (*Hypot)(float, float);
    MathFloatResult (*Diag)(MathFloatView);
    MathFloatResult (*Clamp)(float, float, float);
    MathFloatResult (*Sgn)(float);
    MathFloatResult (*Mix)(float, float, float);
    MathFloatResult (*RoundScalar)(MathRoundRequest);
    MathFloatResult (*ErfScalar)(float);
    MathFloatResult (*Smoothstep)(float, float, float);
    MathWriteResult (*Normalize)(MathNormalizeRequest);

    MathIntResult  (*BitOr)(MathIntView);
    MathIntResult  (*BitAnd)(MathIntView);
    MathIntResult  (*BitXor)(MathIntView);
    MathIntResult  (*BitInv)(int32_t);
    MathIntResult  (*BitBits)(MathIntView);
} MathExtraApi;
```
`MathExtraApi` is exposed on `NativeInterface` as `const MathExtraApi* mathExtra;`.

## Notes
- `MathNormalizeRequest.output` must reference caller-provided storage sized for `input.length` floats.
- Integer operations should mask results to match Lua's 24-bit behaviour (0x00FFFFFF).
