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
  pinned: boolean;
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
const pollingError = ref('');
const storageError = ref('');
const searchQuery = ref('');
const storageReady = ref(false);
let timer: number | undefined;

const compareClips = (left: ClipItem, right: ClipItem) => {
  if (left.pinned !== right.pinned) return Number(right.pinned) - Number(left.pinned);
  return new Date(right.createdAt).getTime() - new Date(left.createdAt).getTime();
};

const normalizedQuery = computed(() => searchQuery.value.trim().toLowerCase());

const filteredClips = computed(() => {
  const byTab =
    activeTab.value === 'default'
      ? clips.value
      : activeTab.value === 'favorites'
        ? clips.value.filter((clip) => clip.favorite)
        : clips.value.filter((clip) => clip.kind === activeTab.value);

  const byQuery = !normalizedQuery.value
    ? byTab
    : byTab.filter((clip) => {
        const haystacks = [clip.title, clip.preview, clip.text ?? '', clip.html ?? '', clip.source];
        return haystacks.some((value) => value.toLowerCase().includes(normalizedQuery.value));
      });

  return [...byQuery].sort(compareClips);
});

const selectedClip = computed(
  () => filteredClips.value.find((clip) => clip.id === selectedId.value) ?? filteredClips.value[0] ?? null,
);

const pinnedCount = computed(() => clips.value.filter((clip) => clip.pinned).length);

const fingerprint = (payload: ClipboardPayload) =>
  [payload.kind, payload.text ?? '', payload.html ?? '', payload.image_data_url ?? ''].join('::');

const ensureSelection = () => {
  if (!selectedClip.value && filteredClips.value[0]) {
    selectedId.value = filteredClips.value[0].id;
  }
};

const loadSavedClips = async () => {
  try {
    const saved = await invoke<ClipItem[]>('load_saved_clips');
    clips.value = [...saved].sort(compareClips);
    selectedId.value = clips.value[0]?.id ?? null;
    storageError.value = '';
  } catch (error) {
    storageError.value = error instanceof Error ? error.message : String(error);
  } finally {
    storageReady.value = true;
    ensureSelection();
  }
};

const saveClips = async (nextClips: ClipItem[]) => {
  try {
    await invoke('save_clips', { clips: nextClips });
    storageError.value = '';
  } catch (error) {
    storageError.value = error instanceof Error ? error.message : String(error);
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
        pinned: false,
        createdAt: new Date().toISOString(),
      },
      ...clips.value,
    ]
      .slice(0, 100)
      .sort(compareClips);

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

const togglePinned = (id: string) => {
  clips.value = clips.value
    .map((clip) => (clip.id === id ? { ...clip, pinned: !clip.pinned } : clip))
    .sort(compareClips);
};

watch(
  filteredClips,
  (next) => {
    if (!next.some((clip) => clip.id === selectedId.value)) {
      selectedId.value = next[0]?.id ?? null;
    }
  },
  { deep: true },
);

watch(
  clips,
  (nextClips) => {
    if (!storageReady.value) return;
    void saveClips(nextClips);
  },
  { deep: true },
);

onMounted(async () => {
  await loadSavedClips();
  await pollClipboard();
  timer = window.setInterval(() => {
    void pollClipboard();
  }, 1200);
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
      <div class="toolbar-group">
        <label class="search">
          <span>搜索</span>
          <input v-model="searchQuery" type="search" placeholder="标题、内容、来源…" />
        </label>
        <div class="status">
          <span class="dot" />
          监听中 · {{ clips.length }} 条记录 · {{ pinnedCount }} 条置顶
        </div>
      </div>
    </header>

    <section class="layout">
      <SidebarTabs v-model="activeTab" :tabs="tabs" />
      <ClipList
        :items="filteredClips"
        :selected-id="selectedClip?.id ?? null"
        @select="selectedId = $event"
        @toggle-favorite="toggleFavorite"
        @toggle-pinned="togglePinned"
      />
      <PreviewPane :clip="selectedClip" />
    </section>

    <footer class="footer">
      <span>文本 / HTML 详情现已基于 CodeMirror 预览，并自动持久化到本地存储。</span>
      <span v-if="storageError || pollingError" class="error">{{ storageError || pollingError }}</span>
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
  gap: 16px;
}
.eyebrow {
  margin: 0 0 8px;
  text-transform: uppercase;
  letter-spacing: 0.16em;
  color: #94a3b8;
  font-size: 12px;
}
h1 { margin: 0; font-size: 32px; }
.toolbar-group {
  display: flex;
  align-items: center;
  gap: 14px;
  flex-wrap: wrap;
  justify-content: flex-end;
}
.search {
  display: grid;
  gap: 6px;
  color: #94a3b8;
  font-size: 12px;
}
.search input {
  width: min(320px, 48vw);
  padding: 12px 14px;
  border-radius: 14px;
  border: 1px solid rgba(148, 163, 184, 0.18);
  background: rgba(15, 23, 42, 0.92);
  color: #e2e8f0;
  outline: none;
}
.search input::placeholder { color: #64748b; }
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

@media (max-width: 860px) {
  .topbar {
    align-items: flex-start;
    flex-direction: column;
  }

  .toolbar-group,
  .search input {
    width: 100%;
  }
}
</style>
