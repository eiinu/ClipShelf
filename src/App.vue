<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { invoke } from '@tauri-apps/api/core';
import { listen, type UnlistenFn } from '@tauri-apps/api/event';
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
  { key: 'default', label: '全部', emoji: '⌘' },
  { key: 'favorites', label: '收藏', emoji: '★' },
  { key: 'text', label: '文本', emoji: 'T' },
  { key: 'html', label: 'HTML', emoji: '</>' },
  { key: 'image', label: '图片', emoji: '🖼' },
];

const activeTab = ref<ClipTab>('default');
const clips = ref<ClipItem[]>([]);
const selectedId = ref<string | null>(null);
const listenerError = ref('');
const storageError = ref('');
const searchQuery = ref('');
const storageReady = ref(false);
let unlistenClipboard: UnlistenFn | null = null;
let unlistenError: UnlistenFn | null = null;

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

const pushClip = (payload: ClipboardPayload) => {
  // 处理同时包含 text 和 html 的情况
  if (payload.kind === 'html' && payload.text) {
    // 创建纯文本版本
    const textId = fingerprint({ ...payload, kind: 'text', html: null });
    if (!clips.value.some((clip) => clip.id === textId)) {
      clips.value = [
        {
          ...payload,
          id: textId,
          kind: 'text',
          html: null,
          favorite: false,
          pinned: false,
          createdAt: new Date().toISOString(),
        },
        ...clips.value,
      ];
    }
  }

  // 创建原始版本
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
  ensureSelection();
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

const setupClipboardListener = async () => {
  unlistenClipboard = await listen<ClipboardPayload>('clipboard-updated', (event) => {
    listenerError.value = '';
    if (event.payload) pushClip(event.payload);
  });

  unlistenError = await listen<string>('clipboard-listener-error', (event) => {
    listenerError.value = event.payload;
  });

  try {
    await invoke('start_clipboard_listener');
  } catch (error) {
    listenerError.value = error instanceof Error ? error.message : String(error);
  }
};

const teardownClipboardListener = async () => {
  if (unlistenClipboard) {
    unlistenClipboard();
    unlistenClipboard = null;
  }

  if (unlistenError) {
    unlistenError();
    unlistenError = null;
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
  await setupClipboardListener();
});

onBeforeUnmount(() => {
  void teardownClipboardListener();
});
</script>

<template>
  <div class="app-frame">
    <main class="shell">
      <header class="topbar">
        <h1>ClipShelf</h1>
        <div class="toolbar-group">
          <label class="search">
            <input v-model="searchQuery" type="search" placeholder="搜索…" />
          </label>
          <div class="status">{{ clips.length }} / {{ pinnedCount }}</div>
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

      <footer v-if="storageError || listenerError" class="footer error">{{ storageError || listenerError }}</footer>
    </main>
  </div>
</template>

<style scoped>
:global(*) { box-sizing: border-box; }
:global(html),
:global(body),
:global(#app) {
  margin: 0;
  width: 100%;
  height: 100%;
  overflow: hidden;
}
:global(body) {
  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  background: #f8fafc;
  color: #1e293b;
}
:global(button), :global(input), :global(textarea), :global(select) { font: inherit; }

.app-frame {
  width: 100%;
  height: 100%;
  overflow: hidden;
  display: flex;
  justify-content: stretch;
}
.shell {
  flex: 1;
  width: 100%;
  min-width: 0;
  min-height: 0;
  height: 100%;
  padding: 14px;
  display: grid;
  grid-template-rows: auto 1fr auto;
  gap: 14px;
  overflow: hidden;
}
.topbar,
.footer,
.layout > * {
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
}
.topbar {
  padding: 14px 16px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 16px;
  flex-wrap: wrap;
}
.topbar h1 {
  margin: 0;
  font-size: 22px;
  font-weight: 700;
  color: #0f172a;
}
.toolbar-group {
  display: flex;
  align-items: center;
  gap: 12px;
}
.search input {
  width: clamp(180px, 22vw, 320px);
  border: 1px solid #cbd5e1;
  border-radius: 8px;
  padding: 8px 10px;
  outline: none;
  background: #f8fafc;
}
.search input:focus {
  border-color: #64748b;
  box-shadow: 0 0 0 3px rgba(100, 116, 139, 0.15);
}
.status {
  font-size: 13px;
  font-weight: 600;
  color: #64748b;
}
.layout {
  min-height: 0;
  display: grid;
  grid-template-columns: 76px minmax(240px, 320px) minmax(0, 1fr);
  gap: 14px;
}

@media (max-width: 1180px) {
  .layout {
    grid-template-columns: 70px minmax(220px, 280px) minmax(0, 1fr);
  }
}

@media (max-width: 980px) {
  .shell {
    padding: 10px;
    gap: 10px;
  }
  .layout {
    gap: 10px;
    grid-template-columns: 1fr;
    grid-template-rows: auto minmax(220px, 38vh) 1fr;
  }
}
.footer {
  padding: 10px 14px;
  font-size: 13px;
}
.error {
  color: #b91c1c;
  border-color: #fecaca;
  background: #fef2f2;
}
</style>
