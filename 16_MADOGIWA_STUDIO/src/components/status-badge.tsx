import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";

const tones: Record<string, string> = {
  published: "border-emerald-400/20 bg-emerald-400/10 text-emerald-300",
  generated: "border-sky-400/20 bg-sky-400/10 text-sky-300",
  ready: "border-sky-400/20 bg-sky-400/10 text-sky-300",
  draft: "border-amber-400/20 bg-amber-400/10 text-amber-300",
  upload_pending: "border-violet-400/20 bg-violet-400/10 text-violet-300",
  archived: "text-stone-500",
};

export function StatusBadge({ status }: { status: string }) {
  return <Badge className={cn(tones[status])}>{status.replaceAll("_", " ")}</Badge>;
}
