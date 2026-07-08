import { sliderToSpeed } from '../data/towerState';

interface ManualModePanelProps {
  pumpSwitch: boolean;
  pumpState: boolean;
  pumpSpeed: number;
  onToggle: (on: boolean) => void;
  onSpeedChange: (speed: number) => void;
}

export function ManualModePanel({
  pumpSwitch,
  pumpState,
  pumpSpeed,
  onToggle,
  onSpeedChange,
}: ManualModePanelProps) {
  const percent = Math.round((pumpSpeed / 255) * 100);

  return (
    <div className="card">
      <h2>Ручний режим</h2>
      <label className="switch-row">
        <input
          type="checkbox"
          checked={pumpSwitch}
          onChange={(e) => onToggle(e.target.checked)}
        />
        Помпа: {pumpState ? 'працює' : 'вимкнена'}
      </label>

      <label className="field">
        Швидкість: {percent}%
        <input
          type="range"
          min={0}
          max={100}
          value={percent}
          aria-label="pump_speed"
          onChange={(e) => onSpeedChange(sliderToSpeed(Number(e.target.value) / 100))}
        />
      </label>
    </div>
  );
}
