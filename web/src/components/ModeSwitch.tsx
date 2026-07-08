import type { PumpMode } from '../data/towerState';

interface ModeSwitchProps {
  mode: PumpMode;
  onChange: (mode: PumpMode) => void;
}

export function ModeSwitch({ mode, onChange }: ModeSwitchProps) {
  return (
    <div className="card mode-switch">
      <h2>Режим помпи</h2>
      <label>
        <input
          type="radio"
          name="pump-mode"
          checked={mode === 'manual'}
          onChange={() => onChange('manual')}
        />
        Ручний
      </label>
      <label>
        <input
          type="radio"
          name="pump-mode"
          checked={mode === 'auto'}
          onChange={() => onChange('auto')}
        />
        Авто
      </label>
    </div>
  );
}
