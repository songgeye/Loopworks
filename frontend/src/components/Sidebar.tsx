"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { House, Infinity as InfinityIcon, LogOut, PackagePlus, Warehouse } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { logout } from "@/lib/auth";

type NavItem = { href: string; label: string; icon: LucideIcon; ready: boolean };
const NAV_ITEMS: NavItem[] = [
  { href: "/", label: "ホーム", icon: House, ready: true },
  { href: "/inbounds/new", label: "入庫の登録", icon: PackagePlus, ready: true },
  { href: "/stock", label: "在庫", icon: Warehouse, ready: false },
];

export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();

  async function handleLogout() {
    try {
      await logout();
    } finally {
      router.push("/login");
    }
  }

  return (
    <aside className="flex flex-col border-b border-sidebar-line bg-sidebar p-4 text-foreground lg:w-64 lg:shrink-0 lg:border-b-0 lg:border-r lg:p-6">
      <div className="flex items-center gap-3">
        <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-accent text-accent-ink">
          <InfinityIcon size={24} strokeWidth={2.5} />
        </div>
        <span className="text-2xl font-bold">Loopworks</span>
      </div>

      <nav className="mt-4 flex gap-2 overflow-x-auto lg:mt-10 lg:flex-col">
        {NAV_ITEMS.map((item) => {
          const Icon = item.icon;
          const active = item.href === "/" ? pathname === "/" : pathname.startsWith(item.href);
          const base = "flex items-center gap-3 whitespace-nowrap rounded-2xl px-4 py-3 text-lg";

          if (!item.ready) {
            return (
              <span key={item.href} aria-disabled="true" className={`${base} text-foreground/30`}>
                <Icon size={22} />
                {item.label}
                <span className="text-xs">準備中</span>
              </span>
            );
          }
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`${base} ${
                active
                  ? "bg-accent font-bold text-accent-ink shadow-[0_0_24px_rgba(134,239,172,0.25)]"
                  : "text-foreground/70 hover:bg-white/5"
              }`}
            >
              <Icon size={22} />
              {item.label}
            </Link>
          );
        })}
      </nav>

      <button
        type="button"
        onClick={handleLogout}
        className="mt-4 flex items-center gap-3 rounded-2xl px-4 py-3 text-lg text-foreground/60 hover:bg-white/5 lg:mt-auto"
      >
        <LogOut size={22} />
        ログアウト
      </button>
    </aside>
  );
}