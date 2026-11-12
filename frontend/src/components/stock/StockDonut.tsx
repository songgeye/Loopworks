export const SLICE_COLORS = ["#3b82f6", "#f97316", "#10b981", "#eab308", "#ec4899", "#22c55e"];

type Slice = { name: string; value: number; color: string };
type Props = { slices: Slice[]; total: number; centerLabel: string };

export default function StockDonut({ slices, total, centerLabel }: Props) {
  const size = 200;
  const stroke = 34;
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;

  const arcs = slices.map((s, i) => ({
    ...s,
    length: (s.value / total) * c,
    start: slices.slice(0, i).reduce((sum, x) => sum + (x.value / total) * c, 0),
  }));

  return (
    <div className="relative h-52 w-52 shrink-0">
      <svg viewBox={`0 0 ${size} ${size}`} className="h-full w-full -rotate-90" role="img" aria-label="在庫全体の構成比">
        {arcs.map((a) => (
          <circle
            key={a.name}
            cx={size / 2}
            cy={size / 2}
            r={r}
            fill="none"
            stroke={a.color}
            strokeWidth={stroke}
            strokeDasharray={`${a.length} ${c - a.length}`}
            strokeDashoffset={-a.start}
          />
        ))}
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <span className="text-2xl font-bold">{centerLabel}</span>
        <span className="text-base text-foreground/60">kg</span>
      </div>
    </div>
  );
}