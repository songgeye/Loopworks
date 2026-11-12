"use client";

import { useSyncExternalStore } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import {
  ClipboardList,
  House,
  Infinity as InfinityIcon,
  LogOut,
  PackageMinus,
  PackagePlus,
  Truck,
  Warehouse,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { getUser, logout } from "@/lib/auth";

type NavItem = { href: string; label: string; icon: LucideIcon; ready: boolean; adminOnly?: boolean };
const NAV_ITEMS: NavItem[] = [
  { href: "/", label: "ホーム", icon: House, ready: true },
  { href: "/inbounds/new", label: "入庫の登録", icon: PackagePlus, ready: true },
  { href: "/inbounds", label: "入庫の一覧", icon: ClipboardList, ready: true },
  { href: "/outbounds/new", label: "出庫の登録", icon: PackageMinus, ready: true, adminOnly: true },
  { href: "/outbounds", label: "出庫の一覧", icon: Truck, ready: true, adminOnly: true },
  { href: "/stock", label: "在庫", icon: Warehouse, ready: true },
];

function useRole() {
  return useSyncExternalStore(
    () => () => {},
    () => getUser()?.role ?? null,
    () => null,
  );
}

export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const role = useRole();

  async function handleLogout() {
    try {
      await logout();
    } finally {
      router.push("/login");
    }
  }

  const items = NAV_ITEMS.filter((item) => !item.adminOnly || role === "admin");

  return (
    <aside className="flex flex-col border-b border-sidebar-line bg-sidebar p-4 text-foreground lg:w-64 lg:shrink-0 lg:border-b-0 lg:border-r lg:p-6">
      <div className="flex items-center gap-3">
        <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-accent text-accent-ink">
          <InfinityIcon size={24} strokeWidth={2.5} />
        </div>
        <span className="text-2xl font-bold">Loopworks</span>
      </div>

      <nav className="mt-4 flex gap-2 overflow-x-auto lg:mt-10 lg:flex-col">
        {items.map((item) => {
          const Icon = item.icon;
          const active = pathname === item.href;
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
                  : "text-foreground/70 hover:bg-foreground/5"
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
        className="mt-4 flex items-center gap-3 rounded-2xl px-4 py-3 text-lg text-foreground/60 hover:bg-foreground/5 lg:mt-auto"
      >
        <LogOut size={22} />
        ログアウト
      </button>
    </aside>
  );
}