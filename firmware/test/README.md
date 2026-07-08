# Native-тести прошивки

Юніт-тести та property-based тести логіки прошивки ESP32 містяться в цій теці.
Вони компілюються та виконуються на хост-машині (обладнання не потрібне) за
допомогою середовища `native` PlatformIO, визначеного у `platformio.ini`.

## Запуск тестів

```bash
pio test -e native
```

PlatformIO скомпілює вихідні файли тестів разом із кодом бібліотеки прошивки,
використовуючи фреймворк GoogleTest, і запустить отриманий бінарник локально.

## Домовленості

- Один файл тестів на кожен модуль прошивки (наприклад, `test_auto_timer.cpp`,
  `test_apply_pump_state.cpp`).
- Property-based тести використовують [rapidcheck](https://github.com/emil-e/rapidcheck)
  та позначаються назвою функції й номером властивості:

  ```cpp
  // Feature: hydroponics-farm-management, Property 10: Safety interlock overrides all pump activation
  ```

- Кожен property-тест виконує щонайменше 100 ітерацій із випадково згенерованими
  вхідними даними.
