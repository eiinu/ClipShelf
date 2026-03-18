<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { invoke } from '@tauri-apps/api/core';
import SidebarTabs from './components/SidebarTabs.vue';
import ClipList from './components/ClipList.vue';
import PreviewPane from './components/PreviewPane.vue';

type ClipKind = 'text' | 'html' | 'image';
type ClipTab = 'default' | 'favorites' | ClipKind;

interface ClipboardPayload {
  kind: ClipKind;
  title: string;
  preview: string;
  text?: string | null;
  html?: string | null;
  image_data_url?: string | null;
  source: string;
}

interface ClipItem extends ClipboardPayload {
  id: string;
  createdAt: string;
  favorite: boolean;
}

const tabs: Array<{ key: ClipTab; label: string; emoji: string }> = [
  { key: 'default', label: '默认', emoji: '⌘' },
  { key: 'favorites', label: '收藏', emoji: '★' },
  { key: 'text', label: '文本', emoji: 'T' },
  { key: 'html', label: 'HTML', emoji: '</>' },
  { key: 'image', label: '图片', emoji: '🖼' },
];

const activeTab = ref<ClipTab>('default');
const clips = ref<ClipItem[]>([]);
const selectedId = ref<string | null>(null);
const pollingError = ref<string>('');
let timer: number | undefined;

const filteredClips = computed(() => {
  if (activeTab.value === 'default') return clips.value;
  if (activeTab.value === 'favorites') return clips.value.filter((clip) => clip.favorite);
  return clips.value.filter((clip) => clip.kind === activeTab.value);
});

const selectedClip = computed(
  () => filteredClips.value.find((clip) => clip.id === selectedId.value) ?? filteredClips.value[0] ?? null,
);

const fingerprint = (payload: ClipboardPayload) =>
  [payload.kind, payload.text ?? '', payload.html ?? '', payload.image_data_url ?? ''].join('::');

const ensureSelection = () => {
  if (!selectedClip.value && filteredClips.value[0]) {
    selectedId.value = filteredClips.value[0].id;
  }
};

const pollClipboard = async () => {
  try {
    const payload = await invoke<ClipboardPayload | null>('read_clipboard_snapshot');
    pollingError.value = '';

    if (!payload) return;

    const id = fingerprint(payload);
    if (clips.value.some((clip) => clip.id === id)) return;

    clips.value = [
      {
        ...payload,
        id,
        favorite: false,
        createdAt: new Date().toISOString(),
      },
      ...clips.value,
    ].slice(0, 100);

    selectedId.value = id;
  } catch (error) {
    pollingError.value = error instanceof Error ? error.message : String(error);
  } finally {
    ensureSelection();
  }
};

const toggleFavorite = (id: string) => {
  clips.value = clips.value.map((clip) =>
    clip.id === id ? { ...clip, favorite: !clip.favorite } : clip,
  );
};

watch(filteredClips, (next) => {
  if (!next.some((clip) => clip.id === selectedId.value)) {
    selectedId.value = next[0]?.id ?? null;
  }
});

onMounted(async () => {
  await pollClipboard();
  timer = window.setInterval(pollClipboard, 1200);
});

onBeforeUnmount(() => {
  if (timer) window.clearInterval(timer);
});
</script>

<template>
  <main class="shell">
    <header class="topbar">
      <div>
        <p class="eyebrow">macOS clipboard desk</p>
        <h1>ClipShelf</h1>
      </div>
      <div class="status">
        <span class="dot" />
        轮询中 · {{ clips.length }} 条记录
      </div>
    </header>

    <section class="layout">
      <SidebarTabs v-model="activeTab" :tabs="tabs" />
      <ClipList
        :items="filteredClips"
        :selected-id="selectedClip?.id ?? null"
        @select="selectedId = $event"
        @toggle-favorite="toggleFavorite"
      />
      <PreviewPane :clip="selectedClip" />
    </section>

    <footer class="footer">
      <span>当前仅实现 macOS demo：通过系统命令读取文本 / HTML / PNG 剪贴板内容。</span>
      <span v-if="pollingError" class="error">{{ pollingError }}</span>
    </footer>
  </main>
</template>

<style scoped>
:global(*) { box-sizing: border-box; }
:global(body) {
  margin: 0;
  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  background: linear-gradient(180deg, #0f172a 0%, #111827 100%);
  color: #e5eefb;
}
:global(button), :global(input), :global(textarea) { font: inherit; }

.shell {
  min-height: 100vh;
  padding: 24px;
  display: grid;
  grid-template-rows: auto 1fr auto;
  gap: 20px;
}
.topbar,
.footer,
.layout > * {
  backdrop-filter: blur(24px);
  background: rgba(15, 23, 42, 0.72);
  border: 1px solid rgba(148, 163, 184, 0.18);
  box-shadow: 0 20px 45px rgba(15, 23, 42, 0.35);
}
.topbar {
  border-radius: 24px;
  padding: 20px 24px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.eyebrow {
  margin: 0 0 8px;
  text-transform: uppercase;
  letter-spacing: 0.16em;
  color: #94a3b8;
  font-size: 12px;
}
h1 { margin: 0; font-size: 32px; }
.status {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  padding: 12px 16px;
  border-radius: 999px;
  background: rgba(30, 41, 59, 0.8);
  color: #cbd5e1;
}
.dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: #34d399;
  box-shadow: 0 0 16px #34d399;
}
.layout {
  display: grid;
  grid-template-columns: 220px minmax(280px, 360px) 1fr;
  gap: 18px;
  min-height: 0;
}
.layout > * {
  min-height: 68vh;
  border-radius: 28px;
}
.footer {
  border-radius: 20px;
  padding: 14px 18px;
  display: flex;
  justify-content: space-between;
  gap: 16px;
  color: #94a3b8;
  font-size: 14px;
}
.error { color: #fca5a5; }

@media (max-width: 1180px) {
  .layout {
    grid-template-columns: 88px minmax(260px, 320px) 1fr;
  }
}
</style>
