import { afterEach, expect, it, vi } from 'vitest';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { WorkspaceStore } from '../src/server/workspace.js';
import { PageService } from '../src/server/page-service.js';
import { Store } from '../src/server/store.js';
import { LocalCodex } from '../src/server/local-codex.js';

const rpcState = vi.hoisted(() => ({
  account: 'chatgpt',
  instances: [] as unknown[],
}));
vi.mock('../src/server/codex-rpc.js', () => ({
  CodexRpc: class {
    onEvent: (method: string, params: unknown) => void = () => {};
    onRequest!: (method: string, params: unknown) => Promise<unknown>;
    onFailure = () => {};
    request = vi.fn(async (method: string) => {
      if (method === 'account/read')
        return { account: { type: rpcState.account } };
      if (method === 'model/list')
        return { data: [{ model: 'test-model', isDefault: true }] };
      if (method === 'thread/start') return { thread: { id: 'codex-thread' } };
      if (method === 'turn/start') {
        queueMicrotask(() => {
          this.onEvent('item/agentMessage/delta', {
            delta: 'Hello from Codex',
          });
          this.onEvent('turn/completed', { turn: { status: 'completed' } });
        });
        return { turn: { id: 'turn' } };
      }
    });
    initialize = vi.fn(async () => {});
    close = vi.fn();
    constructor() {
      rpcState.instances.push(this);
    }
  },
}));
afterEach(() => {
  rpcState.account = 'chatgpt';
  rpcState.instances = [];
});

it('persists local conversation text across restart and saves it as a page without Intelligence', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'dots-local-'));
  const path = join(dir, 'workspace.sqlite');
  let workspace = new WorkspaceStore(path, 'owner');
  const thread = workspace.bindThread(
    'local-thread',
    workspace.dots()[0].id,
    'Local chat',
  );
  workspace.appendMessage(thread.id, 'user', 'Question');
  workspace.appendMessage(thread.id, 'assistant', 'Answer');
  workspace.close();
  workspace = new WorkspaceStore(path, 'owner');
  const pages = new PageService(workspace, () => ({
    getOrCreateThread: async () => ({}),
    getThreadMessages: async ({ threadId }) => ({
      messages: workspace.messages(threadId),
    }),
  }));
  const page = await pages.saveConversation(thread.id, 'Saved chat', null);
  expect(page.content).toContain('## You\n\nQuestion');
  expect(page.content).toContain('## Dot\n\nAnswer');
  expect(() => workspace.messages('unknown-thread')).toThrow();
  workspace.close();
  rmSync(dir, { recursive: true });
});

it('requires ChatGPT login and keeps the API-key-free backend unavailable on other authentication modes', async () => {
  rpcState.account = 'apiKey';
  const workspace = new WorkspaceStore(':memory:', 'owner');
  const store = new Store(':memory:');
  const local = new LocalCodex(store, workspace, {
    baseUrl: '',
    voiceName: '',
    runtimeUrl: '',
    slackUsers: [],
  });
  await local.start();
  expect(local.setup().missing).toEqual(['Codex CLI ChatGPT login']);
  expect(local.ready).toBe(false);
  store.close();
  workspace.close();
});

it('streams and persists a real protocol turn while rejecting cross-Space page tool calls', async () => {
  const workspace = new WorkspaceStore(':memory:', 'owner');
  const store = new Store(':memory:');
  const local = new LocalCodex(store, workspace, {
    baseUrl: '',
    voiceName: '',
    runtimeUrl: '',
    slackUsers: [],
  });
  await local.start();
  const dot = workspace.dots()[0];
  const thread = workspace.bindThread('test-local-turn', dot.id, 'Test');
  const forbidden = workspace.createSpace('Private', '');
  const text = await local.turn(
    thread.id,
    'Hello',
    new AbortController().signal,
  );
  expect(text).toBe('Hello from Codex');
  expect(
    workspace.messages(thread.id).map((message) => message.content),
  ).toEqual(['Hello', 'Hello from Codex']);
  const rpc = rpcState.instances[1] as {
    onRequest: (
      method: string,
      params: unknown,
    ) => Promise<{ success: boolean }>;
    request: ReturnType<typeof vi.fn>;
  };
  const start = rpc.request.mock.calls.find(
    ([method]) => method === 'thread/start',
  );
  expect(start).toBeDefined();
  const result = await rpc.onRequest('item/tool/call', {
    tool: 'create_space_page',
    arguments: { spaceId: forbidden.id, title: 'Denied', content: 'Denied' },
  });
  expect(result.success).toBe(false);
  expect(workspace.pages.list(forbidden.id)).toHaveLength(0);
  await expect(
    rpc.onRequest('item/permissions/requestApproval', {}),
  ).rejects.toThrow();
  store.close();
  workspace.close();
});
