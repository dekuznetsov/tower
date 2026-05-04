# Firmware Native Tests

Unit tests and property-based tests for the ESP32 firmware logic live in this
directory. They are compiled and executed on the host machine (no hardware
required) using the `native` PlatformIO environment defined in `platformio.ini`.

## Running the tests

```bash
pio test -e native
```

PlatformIO will compile the test sources together with the firmware library
code using the GoogleTest framework and run the resulting binary locally.

## Conventions

- One test file per firmware module (e.g. `test_auto_timer.cpp`,
  `test_apply_pump_state.cpp`).
- Property-based tests use [rapidcheck](https://github.com/emil-e/rapidcheck)
  and are tagged with the feature and property number:

  ```cpp
  // Feature: hydroponics-farm-management, Property 10: Safety interlock overrides all pump activation
  ```

- Each property test runs a minimum of 100 iterations with randomly generated
  inputs.
