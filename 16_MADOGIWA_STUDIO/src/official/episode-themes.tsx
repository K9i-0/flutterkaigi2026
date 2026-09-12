import { useState } from "react";
import * as Dialog from "@radix-ui/react-dialog";
import { Palette, X, Check, Sheet, Beer, Ticket, FileSpreadsheet, Save, EyeOff, Eye, ClipboardList, ArrowRight } from "lucide-react";
import { siteThemes, type AvailableTheme } from "./site-theme";
import "./episode-themes.css";

const themeIcons = { sakaba: Beer, excel: Sheet, underground: Ticket };
export function ThemeSwitcher({ theme, onChange, onOpen }: {
  theme: AvailableTheme; onChange: (theme: AvailableTheme) => void; onOpen: () => void;
}) {
  const [open, setOpen] = useState(false);
  return <Dialog.Root open={open} onOpenChange={(value) => { setOpen(value); if (value) onOpen(); }}>
    <Dialog.Trigger className="t-theme-trigger" aria-label="着せ替え"><Palette size={18} /><span>着せ替え</span></Dialog.Trigger>
    <Dialog.Portal>
      <Dialog.Overlay className="j-dialog-overlay" />
      <Dialog.Content className="t-theme-dialog" aria-describedby="theme-save-description">
        <div className="t-theme-dialog-title"><Dialog.Title>着せ替え</Dialog.Title><Dialog.Close aria-label="着せ替えを閉じる"><X size={21} /></Dialog.Close></div>
        <Dialog.Description id="theme-save-description" className="t-theme-save-description">選んだスタイルをこの端末に保存します。</Dialog.Description>
        <div className="t-theme-options">
          {Object.entries(siteThemes).map(([id, item]) => {
            const key = id as AvailableTheme;
            const Icon = themeIcons[key];
            return <button key={id} className={`t-theme-option t-option-${id}`} aria-pressed={theme === id}
              onClick={() => { onChange(key); setOpen(false); }}>
              <span className="t-theme-swatch"><Icon size={27} /></span>
              <span><b>{item.label}</b><small>{item.description}</small></span>
              {theme === id ? <Check size={18} /> : <ArrowRight size={16} />}
            </button>;
          })}
        </div>
      </Dialog.Content>
    </Dialog.Portal>
  </Dialog.Root>;
}

export function DesktopChrome({ theme, working, onToggleWork }: { theme: AvailableTheme; working: boolean; onToggleWork: () => void }) {
  if (theme === "excel") return <div className="e-chrome">
    <div className="e-titlebar"><FileSpreadsheet size={18} /><span>業務報告_最終_修正版.xlsx</span><small><Save size={13} />保存済み</small></div>
    <div className="e-ribbon"><div aria-hidden="true"><b>ホーム</b><span>挿入</span><span>ページ レイアウト</span><span>数式</span><span>データ</span></div>
      <button onClick={onToggleWork}>{working ? <Eye size={15} /> : <EyeOff size={15} />}{working ? "動画に戻る" : "仕事してるふり"}</button>
    </div>
  </div>;
  return null;
}

export function ExcelFormula({ title }: { title: string }) {
  return <div className="e-sheet-top"><div className="e-formula"><span>B2</span><i aria-hidden="true">ƒx</i><input aria-label="数式バー" readOnly value={`="${title}"`} /></div>
    <div className="e-columns" aria-hidden="true"><i />{["A", "B", "C", "D", "E", "F", "G", "H"].map((letter) => <span key={letter}>{letter}</span>)}</div>
  </div>;
}

export function WorkSheet({ onClose }: { onClose: () => void }) {
  const rows = [
    ["窓際環境の改善", "そば屋", "調整中", "継続検討"],
    ["ベランダの有効活用", "そば屋", "進行中", "椅子を設置"],
    ["配信環境の整備", "やめ太郎", "確認待ち", "上長に未確認"],
    ["社内BGMの選定", "とーくん", "進行中", "選曲中"],
    ["定例会議の準備", "福ちゃん", "調整中", "日程を再調整"],
    ["本日の業務報告", "窓際一同", "作成中", "本ファイルを参照"],
  ];
  return <section className="e-work-sheet" aria-label="仕事してるふりの業務表">
    <div className="e-work-heading"><span>業務進捗報告書</span><small>窓際部門</small></div>
    <div className="e-work-scroll"><table><thead><tr>{["No.", "業務内容", "担当", "状況", "備考"].map((title) => <th key={title}>{title}</th>)}</tr></thead>
      <tbody>{rows.map((row, index) => <tr key={row[0]}><td>{index + 1}</td>{row.map((cell, i) => <td key={i}>{cell}</td>)}</tr>)}</tbody>
    </table></div>
    <p>引き続き、各担当にて調整を進めております。</p>
    <button onClick={onClose}><Eye size={16} />動画に戻る</button>
  </section>;
}

export function PointLedger() {
  const [balance, setBalance] = useState(200);
  const [beers, setBeers] = useState(0);
  const [message, setMessage] = useState("本日分の200ポイントが支給されました。");
  return <section className="u-ledger" aria-label="地下労働編のゆめポイント体験">
    <div className="u-ledger-title"><Ticket size={17} /><b>地下売店</b><span>福利厚生・ゆめポイント</span></div>
    <div className="u-ledger-body">
      <div className="u-balance"><span>本日の支給票・残高</span><strong>{balance.toLocaleString()}<small>pt</small></strong></div>
      <div className="u-exit"><span>退室許可証</span><b>100,000 <small>pt</small></b><div className="u-meter" role="progressbar" aria-label="退室に必要なポイント" aria-valuemin={0} aria-valuemax={100000} aria-valuenow={balance}><i style={{ width: `${balance / 1000}%` }} /></div></div>
      <button className="u-beer" disabled={balance < 200} onClick={() => { setBalance((value) => value - 200); setBeers((value) => value + 1); setMessage("今日の労働が、泡になりました。"); }}><Beer size={19} /><span><em>ビール引換券</em>ビールと交換<small>200 pt</small></span></button>
      <button className="u-work" disabled={balance >= 100000} onClick={() => { setBalance((value) => Math.min(100000, value + 200)); setMessage("一日おつかれさま。200ポイント支給です。"); }}><ClipboardList size={15} /><span><em>翌日分の支給</em>もう一日働く<small>＋200 pt</small></span></button>
    </div>
    <div className="u-ledger-foot"><span role="status">{message}</span>{beers > 0 ? <small key={beers} className="u-paid-stamp">交換済 ×{beers}</small> : <small>地下労働編のミニ体験</small>}</div>
  </section>;
}
