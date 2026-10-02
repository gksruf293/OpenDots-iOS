import { useCallback, useEffect, useRef, useState } from 'react';
import { ArrowUp, Clock3, FilePlus, Square } from 'lucide-react';
type Message = { id: string; role: 'user' | 'assistant'; content: string };
import { api, authHeaders } from './api';
import { ChatTranscript } from './ChatTranscript';
import { Mascot } from './Mascot';
import type { Conversation, Dot } from '../shared/types';
import type { Page } from '../server/pages';

export function LocalChat({
  thread,
  dot,
  initialPrompt,
  onConsumed,
  paused,
  onSaved,
  onSchedule,
}: {
  thread: Conversation;
  dot: Dot;
  initialPrompt?: string;
  onConsumed: () => void;
  paused: boolean;
  onSaved: () => void;
  onSchedule: () => void;
}) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [draft, setDraft] = useState('');
  const [error, setError] = useState('');
  const [loaded, setLoaded] = useState(false);
  const [running, setRunning] = useState(false);
  const [activity, setActivity] = useState('');
  const controller = useRef<AbortController | null>(null);
  const sent = useRef(false);
  const bottom = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const abort = new AbortController();
    void api<Message[]>(
      `/conversations/${thread.id}/messages`,
      'GET',
      undefined,
      abort.signal,
    )
      .then((messages) => {
        setMessages(messages);
        setLoaded(true);
      })
      .catch((error: Error) => {
        if (!abort.signal.aborted) setError(error.message);
      });
    return () => {
      abort.abort();
      controller.current?.abort();
    };
  }, [thread.id]);
  useEffect(() => {
    bottom.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, activity]);
  const send = useCallback(
    async (prompt: string) => {
      if (!prompt.trim() || controller.current || paused) return;
      const abort = new AbortController();
      controller.current = abort;
      setRunning(true);
      setError('');
      setActivity('Connecting to Codex…');
      const assistantId = crypto.randomUUID();
      try {
        const response = await fetch(`/api/conversations/${thread.id}/turn`, {
          method: 'POST',
          headers: { ...authHeaders(), 'Content-Type': 'application/json' },
          body: JSON.stringify({ prompt }),
          signal: abort.signal,
        });
        if (!response.ok) {
          const data = (await response.json()) as { error?: string };
          throw new Error(data.error ?? 'Codex request failed.');
        }
        const reader = response.body!.getReader();
        const decoder = new TextDecoder();
        let buffer = '';
        let done = false;
        const processLine = (line: string) => {
          if (!line.trim()) return;
          const event = JSON.parse(line) as {
            type: string;
            text?: string;
            name?: string;
            message?: Message | string;
          };
          if (event.type === 'error') throw new Error(String(event.message));
          if (event.type === 'done') done = true;
          if (event.type === 'tool')
            setActivity(`Using ${event.name?.replaceAll('_', ' ')}…`);
          if (event.type === 'message' && typeof event.message === 'object') {
            const message = event.message;
            if (message.role === 'user') setDraft('');
            setMessages((messages) => [
              ...messages.filter(
                (item) =>
                  item.id !== message.id &&
                  !(message.role === 'assistant' && item.id === assistantId),
              ),
              message,
            ]);
          }
          if (event.type === 'delta') {
            setActivity('Responding…');
            setMessages((messages) => {
              const existing = messages.find((item) => item.id === assistantId);
              return existing
                ? messages.map((item) =>
                    item.id === assistantId
                      ? { ...item, content: String(item.content) + event.text }
                      : item,
                  )
                : [
                    ...messages,
                    {
                      id: assistantId,
                      role: 'assistant',
                      content: event.text ?? '',
                    },
                  ];
            });
          }
        };
        while (true) {
          const chunk = await reader.read();
          if (chunk.done) break;
          buffer += decoder.decode(chunk.value, { stream: true });
          let index;
          while ((index = buffer.indexOf('\n')) >= 0) {
            processLine(buffer.slice(0, index));
            buffer = buffer.slice(index + 1);
          }
        }
        buffer += decoder.decode();
        if (buffer.trim()) processLine(buffer);
        if (!done)
          throw new Error('Connection ended before the response completed.');
        onSaved();
      } catch (error) {
        setError(
          abort.signal.aborted
            ? 'Response stopped.'
            : error instanceof Error
              ? error.message
              : 'Codex request failed.',
        );
        // Recover the server's persisted history after an interrupted or failed stream.
        try {
          setMessages(
            await api<Message[]>(`/conversations/${thread.id}/messages`),
          );
        } catch {
          /* Keep the visible draft if recovery fails. */
        }
      } finally {
        controller.current = null;
        setRunning(false);
        setActivity('');
      }
    },
    [thread.id, paused, onSaved],
  );
  useEffect(() => {
    if (loaded && initialPrompt && !sent.current && !paused) {
      sent.current = true;
      onConsumed();
      void send(initialPrompt);
    }
  }, [loaded, initialPrompt, paused, onConsumed, send]);
  return (
    <div className="live-chat">
      <header className="chat-persona">
        <Mascot
          identity={dot.id}
          name={dot.name}
          small
          state={running ? 'working' : paused ? 'paused' : 'idle'}
        />
        <div>
          <strong>{dot.name}</strong>
          <span>
            {paused ? 'Paused' : running ? activity : 'Codex · saved locally'}
          </span>
        </div>
        <div className="chat-persona-actions">
          <button
            className="icon-button"
            aria-label="Save conversation as page"
            disabled={running || !messages.length}
            onClick={async () => {
              const title = window.prompt('Page title', thread.title);
              if (!title) return;
              try {
                const page = await api<Page>(
                  `/conversations/${thread.id}/page`,
                  'POST',
                  { title },
                );
                onSaved();
                location.hash = `/spaces/${page.spaceId}/pages/${page.id}`;
              } catch (error) {
                setError((error as Error).message);
              }
            }}
          >
            <FilePlus size={18} />
          </button>
          <button
            className="icon-button"
            aria-label="Schedule a task in this conversation"
            onClick={onSchedule}
          >
            <Clock3 size={18} />
          </button>
        </div>
      </header>
      <div className="chat-transcript">
        {!messages.length && (
          <div className="chat-welcome">
            <span className="eyebrow">CODEX IS READY</span>
            <h1>What’s on your mind?</h1>
            <p>{dot.instructions}</p>
          </div>
        )}
        <ChatTranscript messages={messages} calls={[]} />
        {running && <p className="thinking">{activity}</p>}
        <div ref={bottom} />
      </div>
      {error && (
        <div className="chat-error" role="alert">
          {error}
        </div>
      )}
      <form
        className="chat-compose"
        onSubmit={(event) => {
          event.preventDefault();
          void send(draft);
        }}
      >
        <div className="chat-compose-row">
          <textarea
            aria-label="Message your Dot"
            placeholder={`Message ${dot.name}…`}
            rows={1}
            maxLength={4000}
            value={draft}
            onChange={(event) => setDraft(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === 'Enter' && !event.shiftKey) {
                event.preventDefault();
                event.currentTarget.form?.requestSubmit();
              }
            }}
          />
          {running ? (
            <button
              type="button"
              className="send-button"
              aria-label="Stop response"
              onClick={() => {
                void api(`/conversations/${thread.id}/stop`, 'POST', {}).catch(
                  (error: Error) => setError(error.message),
                );
                controller.current?.abort();
              }}
            >
              <Square size={16} />
            </button>
          ) : (
            <button
              className="send-button"
              aria-label="Send message"
              disabled={!loaded || paused || !draft.trim()}
            >
              <ArrowUp size={19} />
            </button>
          )}
        </div>
        <div className="chat-compose-note">
          Codex with ChatGPT login · conversations saved on this PC
        </div>
      </form>
    </div>
  );
}
