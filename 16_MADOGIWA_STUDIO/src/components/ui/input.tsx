import * as React from "react";
import { cn } from "@/lib/utils";

export function Input({ className, ...props }: React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      className={cn(
        "h-11 w-full rounded-xl border border-white/10 bg-black/20 px-3 text-sm text-stone-100 outline-none transition placeholder:text-stone-600 focus:border-amber-400/60 focus:ring-2 focus:ring-amber-400/10",
        className,
      )}
      {...props}
    />
  );
}
