import { waterLevelLabel } from '../data/towerState';

interface SensorCardProps {
  moisture: number;
  waterLevelLow: boolean;
}

export function SensorCard({ moisture, waterLevelLow }: SensorCardProps) {
  return (
    <div className="card">
      <h2>Датчики</h2>
      <p>
        Вологість ґрунту: <strong>{moisture}</strong>
      </p>
      <p>
        Рівень води:{' '}
        <span className={waterLevelLow ? 'status-low' : 'status-good'}>
          {waterLevelLabel(waterLevelLow) === 'Low' ? 'Низький' : 'Достатній'}
        </span>
      </p>
    </div>
  );
}
