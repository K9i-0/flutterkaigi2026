import * as React from "react";
import { cn } from "@/lib/utils";

export function Card({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return <div data-slot="card" className={cn("rounded-3xl border border-white/8 bg-stone-900/70 shadow-2xl shadow-black/20 backdrop-blur", className)} {...props} />;
}

export function CardHeader({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return <div data-slot="card-header" className={cn("flex flex-col gap-2 p-6", className)} {...props} />;
}

export function CardContent({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return <div data-slot="card-content" className={cn("p-6 pt-0", className)} {...props} />;
}
