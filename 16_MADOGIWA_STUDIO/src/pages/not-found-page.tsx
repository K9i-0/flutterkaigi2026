import { Link } from "react-router-dom";
import { Button } from "@/components/ui/button";

export function NotFoundPage() {
  return <div className="py-24 text-center"><div className="font-mono text-xs text-stone-600">404</div><h1 className="mt-3 text-3xl font-semibold">ページが見つかりません</h1><Button asChild className="mt-8"><Link to="/">Archiveへ戻る</Link></Button></div>;
}
