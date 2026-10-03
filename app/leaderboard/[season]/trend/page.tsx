import { redirect } from "next/navigation";
import LeaderboardPageClient from "@/components/LeaderboardPageClient";
import { resolveCompetitionIdForSeason } from "@/lib/competition-resolver";
import { getLeaderboardSnapshot } from "@/lib/leaderboard-snapshot";
import { createClient, createServiceClient } from "@/lib/supabase-server";

type LeaderboardTrendPageProps = {
  params: Promise<{
    season: string;
  }>;
};

export default async function LeaderboardTrendPage(props: LeaderboardTrendPageProps) {
  const { season: seasonParam } = await props.params;
  const season = Number(seasonParam);

  if (!Number.isFinite(season)) {
    return (
      <LeaderboardPageClient
        season={season}
        initialLeaderboard={null}
        initialMessage="Invalid season."
        initialViewMode="overall"
        pageMode="trend"
      />
    );
  }

  const authClient = await createClient();
  const {
    data: { user },
  } = await authClient.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const supabase = createServiceClient();
  let initialLeaderboard = null as Awaited<ReturnType<typeof getLeaderboardSnapshot>> | null;
  let initialMessage: string | null = null;

  try {
    const competitionId = await resolveCompetitionIdForSeason({
      season,
      userId: user.id,
      supabase,
    });

    if (!competitionId) {
      initialMessage = "No competition found.";
    } else {
      initialLeaderboard = await getLeaderboardSnapshot({
        season,
        competitionId,
        supabase,
        includeTrends: true,
        // Use the saved ladder (cleared whenever results sync, rebuilt on admin
        // recalcs and late tips) instead of rebuilding it from every tip on
        // each visit. Home and Stats already read it this way.
        preferCached: true,
      });
    }
  } catch (error) {
    initialMessage =
      error instanceof Error ? error.message : "Could not load leaderboard trend.";
  }

  return (
    <LeaderboardPageClient
      season={season}
      initialLeaderboard={initialLeaderboard}
      initialMessage={initialMessage}
      initialViewMode="overall"
      pageMode="trend"
      initialTrendsIncluded={initialLeaderboard !== null}
    />
  );
}
