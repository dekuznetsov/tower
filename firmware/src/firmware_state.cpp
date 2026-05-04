#include "firmware_state.h"

// =============================================================================
// Global FirmwareState instance — initialised to safe defaults.
//
// Safe defaults ensure the pump is off and in manual mode on every cold start,
// preventing unintended pump activation before the first Firebase sync.
//
// Requirements: 3.1, 3.2, 3.3, 3.4
// =============================================================================
FirmwareState firmwareState = {
    /* pump_mode        */ "manual",
    /* pump_speed       */ 0,
    /* pump_switch      */ false,
    /* interval_on_ms   */ 60000UL,   // 1 minute default
    /* interval_off_ms  */ 60000UL,   // 1 minute default
    /* pump_state       */ false,
    /* moisture         */ 0,
    /* water_level_low  */ false,
};
