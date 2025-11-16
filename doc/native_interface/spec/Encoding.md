# Encoding API

## Function Details

### Common Data Types
```c
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct {
    const uint8_t* data;
    size_t length;
} EncodingBufferView;

typedef struct {
    uint8_t* data;
    size_t capacity;
} EncodingBufferWrite;

typedef struct {
    const Error* error;
    size_t bytesWritten;
} EncodingWriteResult;

typedef struct {
    const Error* error;
    bool value;
} EncodingBoolResult;
```

### Encoding.EncodeBase64
- **Lua:** `Encoding.EncodeBase64(text, stripPadding?)`
- **Native:** `EncodingWriteResult (*EncodeBase64)(EncodingBufferView input, EncodingBufferWrite output, bool stripPadding);`

### Encoding.DecodeBase64
- **Lua:** `Encoding.DecodeBase64(text)`
- **Native:** `EncodingWriteResult (*DecodeBase64)(EncodingBufferView input, EncodingBufferWrite output);`

### Encoding.IsValidBase64
- **Lua:** `Encoding.IsValidBase64(text)`
- **Native:** `EncodingBoolResult (*IsValidBase64)(EncodingBufferView input);`

### Encoding.EncodeBase64Url
- **Lua:** `Encoding.EncodeBase64Url(text)`
- **Native:** `EncodingWriteResult (*EncodeBase64Url)(EncodingBufferView input, EncodingBufferWrite output);`

### Encoding.DecodeBase64Url
- **Lua:** `Encoding.DecodeBase64Url(text)`
- **Native:** `EncodingWriteResult (*DecodeBase64Url)(EncodingBufferView input, EncodingBufferWrite output);`

### Encoding.IsValidBase64Url
- **Lua:** `Encoding.IsValidBase64Url(text)`
- **Native:** `EncodingBoolResult (*IsValidBase64Url)(EncodingBufferView input);`

## API Table
```c
typedef struct EncodingApi {
    EncodingWriteResult (*EncodeBase64)(EncodingBufferView, EncodingBufferWrite, bool stripPadding);
    EncodingWriteResult (*DecodeBase64)(EncodingBufferView, EncodingBufferWrite);
    EncodingBoolResult  (*IsValidBase64)(EncodingBufferView);

    EncodingWriteResult (*EncodeBase64Url)(EncodingBufferView, EncodingBufferWrite);
    EncodingWriteResult (*DecodeBase64Url)(EncodingBufferView, EncodingBufferWrite);
    EncodingBoolResult  (*IsValidBase64Url)(EncodingBufferView);
} EncodingApi;
```
`EncodingApi` is exposed on `NativeInterface` as `const EncodingApi* encoding;`.

## Notes
- `EncodingBufferWrite` must reference caller-provided storage; `bytesWritten` reports the number of bytes emitted.

