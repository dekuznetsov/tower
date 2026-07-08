import { useState } from 'react';
import { validateInterval } from '../utils/validateInterval';

interface AutoModePanelProps {
  intervalOnMin: number;
  intervalOffMin: number;
  onSave: (onMin: number, offMin: number) => void;
}

export function AutoModePanel({ intervalOnMin, intervalOffMin, onSave }: AutoModePanelProps) {
  const [on, setOn] = useState(String(intervalOnMin));
  const [off, setOff] = useState(String(intervalOffMin));

  const onError = validateInterval(on);
  const offError = validateInterval(off);
  const valid = onError === null && offError === null;

  return (
    <div className="card">
      <h2>Авто-режим</h2>
      <label className="field">
        Хвилин увімкнено
        <input
          value={on}
          inputMode="numeric"
          aria-label="interval_on_min"
          onChange={(e) => setOn(e.target.value)}
        />
      </label>
      {onError && <span className="error">{onError}</span>}

      <label className="field">
        Хвилин вимкнено
        <input
          value={off}
          inputMode="numeric"
          aria-label="interval_off_min"
          onChange={(e) => setOff(e.target.value)}
        />
      </label>
      {offError && <span className="error">{offError}</span>}

      <button
        type="button"
        disabled={!valid}
        onClick={() => {
          if (valid) onSave(Number(on), Number(off));
        }}
      >
        Зберегти
      </button>
    </div>
  );
}
