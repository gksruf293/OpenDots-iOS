import { spawn, type ChildProcessWithoutNullStreams } from 'node:child_process';
import { createInterface } from 'node:readline';

type Packet = {
  id?: number | string;
  method?: string;
  params?: Record<string, unknown>;
  result?: unknown;
  error?: { message: string };
};
export class CodexRpc {
  private child: ChildProcessWithoutNullStreams;
  private nextId = 0;
  private pending = new Map<
    number,
    {
      resolve: (value: unknown) => void;
      reject: (error: Error) => void;
      timer: ReturnType<typeof setTimeout>;
    }
  >();
  onEvent: (method: string, params: Record<string, unknown>) => void = () => {};
  onRequest: (
    method: string,
    params: Record<string, unknown>,
  ) => Promise<unknown> = async () => {
    throw new Error('This tool is unavailable in OpenDots.');
  };
  onFailure: (error: Error) => void = () => {};
  constructor(command: string, cwd: string) {
    this.child = spawn(command, ['app-server', '--listen', 'stdio://'], {
      cwd,
      windowsHide: true,
      stdio: 'pipe',
    });
    // Protocol packets only; never expose stderr, credentials, or account details to the browser.
    this.child.stderr.on('data', () => {});
    this.child.stdin.on('error', () =>
      this.fail(new Error('Codex CLI disconnected. Retry the message.')),
    );
    this.child.on('error', () =>
      this.fail(new Error('Codex CLI could not start. Check CODEX_COMMAND.')),
    );
    this.child.on('exit', () =>
      this.fail(new Error('Codex CLI disconnected. Retry the message.')),
    );
    createInterface({ input: this.child.stdout }).on('line', (line) => {
      let packet: Packet;
      try {
        packet = JSON.parse(line) as Packet;
      } catch {
        return;
      }
      if (packet.method && packet.id !== undefined) {
        void this.onRequest(packet.method, packet.params ?? {}).then(
          (result) => this.write({ id: packet.id, result }),
          () =>
            this.write({
              id: packet.id,
              error: {
                code: -32601,
                message: 'This tool or permission is unavailable in OpenDots.',
              },
            }),
        );
      } else if (packet.method)
        this.onEvent(packet.method, packet.params ?? {});
      else if (typeof packet.id === 'number') {
        const request = this.pending.get(packet.id);
        if (!request) return;
        this.pending.delete(packet.id);
        clearTimeout(request.timer);
        if (packet.error) request.reject(new Error(packet.error.message));
        else request.resolve(packet.result);
      }
    });
  }
  private write(packet: unknown) {
    if (!this.child.stdin.destroyed)
      this.child.stdin.write(JSON.stringify(packet) + '\n');
  }
  private fail(error: Error) {
    for (const request of this.pending.values()) {
      clearTimeout(request.timer);
      request.reject(error);
    }
    this.pending.clear();
    this.onFailure(error);
  }
  request<T>(method: string, params: unknown): Promise<T> {
    const id = ++this.nextId;
    return new Promise<T>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`Codex ${method} timed out.`));
      }, 30000);
      this.pending.set(id, {
        resolve: (value) => resolve(value as T),
        reject,
        timer,
      });
      this.write({ id, method, params });
    });
  }
  async initialize() {
    await this.request('initialize', {
      clientInfo: { name: 'opendots_local', version: '0.1.0' },
      capabilities: { experimentalApi: true },
    });
    this.write({ method: 'initialized' });
  }
  close() {
    this.onFailure = () => {};
    this.fail(new Error('Codex connection closed.'));
    this.child.stdin.end();
    this.child.kill();
  }
}
