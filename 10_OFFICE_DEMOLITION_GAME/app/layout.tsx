import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "そば屋のオフィス更地クラッシュ ～全部壊して快適です！～",
  description:
    "机、壁、床、柱、鉄骨まで。壊して解体レベルを上げ、広大な3Dオフィスを本当に何もない更地へ戻す全破壊アクションゲーム。",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ja">
      <body>{children}</body>
    </html>
  );
}
