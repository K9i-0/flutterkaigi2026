import { describe, expect, it } from "vitest";
import { chooseThemeFeature } from "../src/official/theme-features";
import type { EpisodeSummary } from "../src/lib/api";
function episode(slug: string, overrides: Partial<EpisodeSummary> = {}): EpisodeSummary {
  return { id: slug, studio_id: slug, slug, episode_number: null, title: slug, summary: "", status: "published", created_at: "", updated_at: "", published_at: null, generation_count: 1, video_count: 1, input_count: 0, primary_video_id: slug, primary_video_poster_url: null, has_featured_video: 0, featured_video_created_at: null, prompt_label: null, members: [], ...overrides };
}
describe("theme recommendations", () => {
  it("opens a different relevant episode for each of the three styles", () => {
    const episodes = [episode("professional-window-side-sobaya"), episode("madogiwa-super-try-underground"), episode("tako-game-dormitory")];
    expect(chooseThemeFeature(episodes, "sakaba")?.slug).toBe("tako-game-dormitory");
    expect(chooseThemeFeature(episodes, "excel")?.slug).toBe("professional-window-side-sobaya");
    expect(chooseThemeFeature(episodes, "underground")?.slug).toBe("madogiwa-super-try-underground");
  });
  it("never surfaces an archived or unplayable recommendation and prefers a public pickup", () => {
    const episodes = [episode("tako-game-dormitory", { status: "archived" }), episode("first"), episode("pickup", { has_featured_video: 1 }), episode("professional-window-side-sobaya", { primary_video_id: null })];
    expect(chooseThemeFeature(episodes, "sakaba")?.slug).toBe("pickup");
    expect(chooseThemeFeature(episodes, "excel")?.slug).toBe("pickup");
    expect(chooseThemeFeature([], "underground")).toBeUndefined();
  });
});
