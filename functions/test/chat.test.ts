import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { sendChatMessage } from '../src/chat';

const WEBHOOK = 'https://chat.googleapis.com/v1/spaces/AAA/messages?key=k&token=t';

beforeEach(() => {
  vi.restoreAllMocks();
});
afterEach(() => {
  vi.unstubAllGlobals();
});

// Feature: google-chat-monitoring-alerts, Property N5: webhook sender contract
describe('sendChatMessage', () => {
  it('POSTs the text as JSON to the webhook', async () => {
    const fetchMock = vi.fn<(url: string, init: RequestInit) => Promise<Response>>(
      async () => new Response('', { status: 200 }),
    );
    vi.stubGlobal('fetch', fetchMock);

    await sendChatMessage(WEBHOOK, 'привіт');

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe(WEBHOOK);
    expect(init.method).toBe('POST');
    expect(JSON.parse(init.body as string)).toEqual({ text: 'привіт' });
  });

  it('throws on a non-OK response', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => new Response('bad', { status: 400 })),
    );
    await expect(sendChatMessage(WEBHOOK, 'x')).rejects.toThrow(/400/);
  });
});
