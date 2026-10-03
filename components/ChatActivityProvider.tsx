"use client";

import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { usePathname } from "next/navigation";
import { supabaseBrowser } from "@/lib/supabase-browser";

type ChatActivityContextValue = {
  unreadChat: number;
  unreadMentions: number;
  unreadAnnouncements: number;
  unreadLeaderboardInvites: number;
};

const ChatActivityContext = createContext<ChatActivityContextValue | null>(null);

function getLastChatSeenMs() {
  if (typeof window === "undefined") return 0;
  const v = window.localStorage.getItem("chat_last_seen_ms");
  return v ? Number(v) || 0 : 0;
}

function markChatSeenNow() {
  if (typeof window === "undefined") return;
  window.localStorage.setItem("chat_last_seen_ms", String(Date.now()));
}

function getLastAnnouncementsSeenMs() {
  if (typeof window === "undefined") return 0;
  const v = window.localStorage.getItem("announcements_last_seen_ms");
  return v ? Number(v) || 0 : 0;
}

function markAnnouncementsSeenNow() {
  if (typeof window === "undefined") return;
  window.localStorage.setItem("announcements_last_seen_ms", String(Date.now()));
}

// Chat counts are cheap and drive the chat badge, so they keep the 30s cadence.
// Notices and group invites change rarely and their API calls are heavier,
// so they refresh at most every 5 minutes, plus on login, when you come back
// to the tab, and when you open the chat or notices page. Any refresh within
// 30s of the last one is skipped, so a page load or quick navigation no
// longer fires every call several times.
const CHAT_POLL_MS = 30_000;
const MIN_REFRESH_GAP_MS = 30_000;
const SLOW_POLL_MS = 5 * 60_000;

function isMissingRelationError(message: string, relationName: string) {
  const m = String(message || "").toLowerCase();
  const rel = relationName.toLowerCase();
  return m.includes(rel) && m.includes("relation") && m.includes("does not exist");
}

export function ChatActivityProvider({
  children,
  initialAuthenticated = false,
}: {
  children: React.ReactNode;
  initialAuthenticated?: boolean;
}) {
  const pathname = usePathname();
  const viewingChat = pathname?.startsWith("/chat") ?? false;
  const viewingAnnouncements = pathname?.startsWith("/announcements") ?? false;
  const [unreadChat, setUnreadChat] = useState(0);
  const [unreadMentions, setUnreadMentions] = useState(0);
  const [unreadAnnouncements, setUnreadAnnouncements] = useState(0);
  const [unreadLeaderboardInvites, setUnreadLeaderboardInvites] = useState(0);
  // Only the user id drives the effects below. The access token changes on
  // every token refresh and used to restart the checks (three times on each
  // page load), so it lives in a ref instead.
  const [sessionUserId, setSessionUserId] = useState<string | null>(null);
  const accessTokenRef = useRef<string | null>(null);
  const lastChatRefreshMsRef = useRef(0);
  const lastSlowRefreshMsRef = useRef(0);
  const [isPageVisible, setIsPageVisible] = useState(() => {
    if (typeof document === "undefined") return true;
    return document.visibilityState === "visible";
  });

  useEffect(() => {
    let mounted = true;

    function clearAll() {
      accessTokenRef.current = null;
      setSessionUserId(null);
      setUnreadChat(0);
      setUnreadMentions(0);
      setUnreadAnnouncements(0);
      setUnreadLeaderboardInvites(0);
    }

    async function syncSession() {
      if (!initialAuthenticated) {
        if (mounted) clearAll();
        return;
      }

      const { data } = await supabaseBrowser.auth.getSession();
      if (!mounted) return;
      if (!data.session) {
        clearAll();
        return;
      }

      accessTokenRef.current = data.session.access_token;
      setSessionUserId(data.session.user.id);
    }

    void syncSession();

    const { data: sub } = supabaseBrowser.auth.onAuthStateChange((_event, session) => {
      if (!mounted) return;
      if (!session) {
        clearAll();
        return;
      }
      accessTokenRef.current = session.access_token;
      // Same user id → React skips the re-render, so no extra refresh.
      setSessionUserId(session.user.id);
    });

    return () => {
      mounted = false;
      sub.subscription.unsubscribe();
    };
  }, [initialAuthenticated]);

  useEffect(() => {
    if (typeof document === "undefined") return;

    const onVisibilityChange = () => {
      setIsPageVisible(document.visibilityState === "visible");
    };

    onVisibilityChange();
    document.addEventListener("visibilitychange", onVisibilityChange);
    return () => document.removeEventListener("visibilitychange", onVisibilityChange);
  }, []);

  useEffect(() => {
    const userId = sessionUserId;

    async function refreshChatCounts(uid: string) {
      const sinceIso = new Date(getLastChatSeenMs()).toISOString();

      const [chatResult, mentionResult] = await Promise.all([
        supabaseBrowser
          .from("chat_messages")
          .select("id", { count: "exact", head: true })
          .gt("created_at", sinceIso),
        supabaseBrowser
          .from("chat_message_mentions")
          .select("id", { count: "exact", head: true })
          .eq("mentioned_user_id", uid)
          .gt("created_at", sinceIso),
      ]);

      if (!chatResult.error) {
        setUnreadChat(chatResult.count ?? 0);
      }

      if (mentionResult.error) {
        if (isMissingRelationError(mentionResult.error.message, "chat_message_mentions")) {
          setUnreadMentions(0);
        }
      } else {
        setUnreadMentions(mentionResult.count ?? 0);
      }
    }

    async function refreshAnnouncements(token: string) {
      const lastAnnouncementsSeenMs = getLastAnnouncementsSeenMs();
      try {
        const announcementsRes = await fetch("/api/announcements", {
          cache: "no-store",
          headers: { Authorization: `Bearer ${token}` },
        });
        const announcementsJson = (await announcementsRes
          .json()
          .catch(() => null)) as {
          ok?: boolean;
          rows?: Array<{ published_at_utc?: string | null; created_at?: string | null }>;
        } | null;

        if (!announcementsRes.ok || !announcementsJson?.ok || !Array.isArray(announcementsJson.rows)) {
          setUnreadAnnouncements(0);
        } else {
          let unread = 0;
          announcementsJson.rows.forEach((row) => {
            const ts = new Date(String(row.published_at_utc ?? row.created_at ?? "")).getTime();
            if (Number.isFinite(ts) && ts > lastAnnouncementsSeenMs) unread += 1;
          });
          setUnreadAnnouncements(unread);
        }
      } catch {
        setUnreadAnnouncements(0);
      }
    }

    async function refreshInvites(token: string) {
      try {
        const invitesRes = await fetch("/api/leaderboard-group-invites", {
          cache: "no-store",
          headers: { Authorization: `Bearer ${token}` },
        });
        const invitesJson = (await invitesRes.json().catch(() => null)) as
          | { ok?: boolean; pending_count?: number }
          | null;
        if (!invitesRes.ok || !invitesJson?.ok) {
          setUnreadLeaderboardInvites(0);
        } else {
          setUnreadLeaderboardInvites(Number(invitesJson.pending_count ?? 0));
        }
      } catch {
        setUnreadLeaderboardInvites(0);
      }
    }

    // Runs whatever is due. `force` skips the gap check (used when the
    // chat or notices page is opened, so its badge clears straight away).
    function refreshDue(force = false) {
      if (!userId) return;
      const token = accessTokenRef.current;
      const now = Date.now();
      const jobs: Promise<void>[] = [];

      if (force || now - lastChatRefreshMsRef.current >= MIN_REFRESH_GAP_MS) {
        lastChatRefreshMsRef.current = now;
        jobs.push(refreshChatCounts(userId));
      }

      if (token && (force || now - lastSlowRefreshMsRef.current >= SLOW_POLL_MS)) {
        lastSlowRefreshMsRef.current = now;
        jobs.push(refreshAnnouncements(token), refreshInvites(token));
      }

      void Promise.all(jobs);
    }

    if (!pathname) return;

    if (viewingChat) {
      const previousSeen = getLastChatSeenMs();
      if (typeof window !== "undefined") {
        window.localStorage.setItem("chat_last_seen_snapshot_ms", String(previousSeen));
      }
      markChatSeenNow();
    }

    if (viewingAnnouncements) {
      markAnnouncementsSeenNow();
    }

    if (!userId) {
      // Counts are already zeroed where the session is cleared.
      lastChatRefreshMsRef.current = 0;
      lastSlowRefreshMsRef.current = 0;
      return;
    }

    if (!isPageVisible) return;

    refreshDue(viewingChat || viewingAnnouncements);

    const t = setInterval(() => {
      refreshDue();
    }, CHAT_POLL_MS);
    return () => clearInterval(t);
  }, [isPageVisible, pathname, sessionUserId, viewingChat, viewingAnnouncements]);

  const value = useMemo(
    () => ({
      unreadChat: viewingChat ? 0 : unreadChat,
      unreadMentions: viewingChat ? 0 : unreadMentions,
      unreadAnnouncements: viewingAnnouncements ? 0 : unreadAnnouncements,
      unreadLeaderboardInvites,
    }),
    [
      unreadChat,
      unreadMentions,
      unreadAnnouncements,
      unreadLeaderboardInvites,
      viewingChat,
      viewingAnnouncements,
    ]
  );

  return <ChatActivityContext.Provider value={value}>{children}</ChatActivityContext.Provider>;
}

export function useChatActivity() {
  const value = useContext(ChatActivityContext);
  if (!value) {
    throw new Error("useChatActivity must be used within ChatActivityProvider");
  }
  return value;
}
