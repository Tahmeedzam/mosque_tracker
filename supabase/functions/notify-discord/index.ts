import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const DISCORD_WEBHOOK_URL = Deno.env.get("DISCORD_WEBHOOK_URL")!;

Deno.serve(async (req) => {
  const payload = await req.json();
  const record = payload.record;

  const typeEmoji: Record<string, string> = {
    bug: "🐛",
    feedback: "💡",
    mosque_issue: "🕌",
    other: "📩",
  };

  const emoji = typeEmoji[record.type] || "📩";

  let content = `${emoji} **New ${record.type.replace("_", " ")}**\n\n**Message:** ${record.message}\n**Email:** ${record.email || "Not provided"}`;

  if (record.mosque_id) {
    content += `\n**Mosque ID:** ${record.mosque_id}`;
  }

  content += `\n**Time:** ${new Date(record.created_at).toLocaleString()}`;

  const discordMessage = { content };

  const response = await fetch(DISCORD_WEBHOOK_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(discordMessage),
  });

  return new Response(JSON.stringify({ success: response.ok }), {
    headers: { "Content-Type": "application/json" },
  });
});