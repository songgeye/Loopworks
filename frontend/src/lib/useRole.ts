import { useSyncExternalStore } from "react";
import { getUser } from "@/lib/auth";

export function useRole() {
  return useSyncExternalStore(
    () => () => {},
    () => getUser()?.role ?? null,
    () => null,
  );
}