// Thin Google Chat incoming-webhook sender. Uses the Node 20 global `fetch`.

export async function sendChatMessage(webhookUrl: string, text: string): Promise<void> {
  const response = await fetch(webhookUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify({ text }),
  });
  if (!response.ok) {
    const body = await response.text().catch(() => '');
    throw new Error(`Google Chat webhook failed: ${response.status} ${body}`);
  }
}
