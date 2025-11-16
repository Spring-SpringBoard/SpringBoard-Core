# UICommand API

## Function Details

### Common Data Types
```c
#include <stdbool.h>
#include <stddef.h>

typedef struct {
    const char* command;
    const char* description;
    bool synced;
    bool cheat;
} UiCommandEntry;

typedef struct {
    const Error* error;
    const UiCommandEntry* entries;
    size_t entryCount;
} UiCommandListResult;
```

### Spring.GetUICommands
- **Lua:** `Spring.GetUICommands()`
- **Native:** `UiCommandListResult (*GetUiCommands)(void);`

## API Table
```c
typedef struct UiCommandApi {
    UiCommandListResult (*GetUiCommands)(void);
} UiCommandApi;
```
`UiCommandApi` is exposed on `NativeInterface` as `const UiCommandApi* uiCommand;`.

## Notes
- Each `UiCommandEntry` references engine-managed strings; consumers copy data if ownership is required.
- The returned pointer array remains valid until the next call to `GetUiCommands`.
