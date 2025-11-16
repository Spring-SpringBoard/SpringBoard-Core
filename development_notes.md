# Development Notes

This document outlines the architecture and development process for integrating native Rust code with the C++ engine.

## Architecture

The system consists of two main parts:

1.  **C++ Engine (`spring-bar`):** The core engine written in C++.
2.  **Native Rust Module (`SBC.sdd/native`):** A Rust library that extends the engine's functionality.

Communication between these two parts is achieved through a native interface.

### Native Interface

The bridge between C++ and Rust is defined by the following key files:

-   **C++ Side:**
    -   `rts/Game/Rust/NativeInterface.h`: Defines the interface structs (`NativeInterfaceBridge` and `NativeInterface`) that Rust will interact with.
    -   `rts/Game/Rust/RustSystem.h` / `rts/Game/Rust/RustSystem.cpp`: Implements the C++ side of the bridge, providing the actual functionality that the interface exposes.

-   **Rust Side:**
    -   `native/src/native_interface.rs`: Defines the Rust representation of the native interface, allowing Rust code to call the C++ functions.

## Development Process

To add a new function to the native interface (e.g., `MyNewFunction`):

1.  **`NativeInterface.h`:**
    -   Add the virtual function declaration to the `NativeInterfaceBridge` struct:
        ```cpp
        virtual void MyNewFunction(int arg1, float arg2) = 0;
        ```
    -   Add the corresponding function pointer type and member to the `NativeInterface` struct:
        ```cpp
        using MyNewFunction = void(*)(NativeInterface* ptr, int arg1, float arg2);
        MyNewFunction f_MyNewFunction;
        ```

2.  **`RustSystem.h`:**
    -   Add the public override declaration for the new function in the `RustSystem` class:
        ```cpp
        void MyNewFunction(int arg1, float arg2) override;
        ```

3.  **`RustSystem.cpp`:**
    -   Implement the function:
        ```cpp
        void RustSystem::MyNewFunction(int arg1, float arg2) {
            // Implementation here
        }
        ```
    -   Add the function to the `m_NativeInterface` struct initialization:
        ```cpp
        .f_MyNewFunction = [](NativeInterface* ptr, int arg1, float arg2) {
            return ptr->bridge->MyNewFunction(arg1, arg2);
        },
        ```

4.  **`native_interface.rs`:**
    -   Add the function signature to the `NativeInterfaceImpl` struct:
        ```rust
        f_MyNewFunction: extern "C" fn(ptr: *const NativeInterfaceImpl, arg1: i32, arg2: f32),
        ```
    -   Add the function to the `NativeInterface` trait:
        ```rust
        fn MyNewFunction(&self, arg1: i32, arg2: f32);
        ```
    -   Implement the function for the trait:
        ```rust
        fn MyNewFunction(&self, arg1: i32, arg2: f32) {
            (self.f_MyNewFunction)(self as *const NativeInterfaceImpl, arg1, arg2)
        }
        ```

5.  **Usage in Rust:**
    -   You can now call `Spring.MyNewFunction(arg1, arg2)` from anywhere in the Rust code.

## Build Process

-   **C++ (`spring-bar`):** Build using the provided docker script: `./docker-build-v2/build.sh linux`.
-   **Rust (`SBC.sdd/native`):** Build using `cargo build` in the `native` directory.

## Porting from Lua

Existing Lua implementations in `rts/Lua` serve as a reference when porting functionality to the native Rust module. The goal is to replicate the logic from the Lua files in Rust, using the newly created native interface functions.
