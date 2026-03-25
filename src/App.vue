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

const tabs: Array<{ key: ClipTab; label: string }> = [
  { key: 'default', label: '全部' },
  { key: 'favorites', label: '收藏' },
  { key: 'text', label: '文本' },
  { key: 'html', label: 'HTML' },
  { key: 'image', label: '图片' },
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

  return !normalizedQuery.value
    ? byTab
    : byTab.filter((clip) => {
        const haystacks = [clip.title, clip.preview, clip.text ?? '', clip.html ?? '', clip.source];
        return haystacks.some((value) => value.toLowerCase().includes(normalizedQuery.value));
      });
});

const selectedClip = computed(
  () => filteredClips.value.find((clip) => clip.id === selectedId.value) ?? filteredClips.value[0] ?? null,
);

const favoriteCount = computed(() => clips.value.filter((clip) => clip.favorite).length);

const fingerprint = (payload: ClipboardPayload) =>
  [payload.kind, payload.text ?? '', payload.html ?? '', payload.image_data_url ?? ''].join('::');

const createClipId = (payload: ClipboardPayload) => {
  const entropy = crypto.randomUUID();
  return `${Date.now()}::${entropy}::${fingerprint(payload)}`;
};

const ensureSelection = () => {
  if (!selectedClip.value && filteredClips.value[0]) {
    selectedId.value = filteredClips.value[0].id;
  }
};

const pushClip = (payload: ClipboardPayload) => {
  const nextItems: ClipItem[] = [];
  const baseTimestamp = Date.now();

  if (payload.kind === 'html' && payload.text) {
    nextItems.push({
      ...payload,
      id: createClipId({ ...payload, kind: 'text', html: null }),
      kind: 'text',
      html: null,
      favorite: false,
      pinned: false,
      createdAt: new Date(baseTimestamp).toISOString(),
    });
  }

  const mainId = createClipId(payload);
  nextItems.push({
    ...payload,
    id: mainId,
    favorite: false,
    pinned: false,
    createdAt: new Date(baseTimestamp + 1).toISOString(),
  });

  clips.value = [...nextItems, ...clips.value]
    .slice(0, 100)
    .sort(compareClips);

  selectedId.value = mainId;
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

const removeClip = (id: string) => {
  clips.value = clips.value.filter((clip) => clip.id !== id);
  if (selectedId.value === id) {
    selectedId.value = null;
    ensureSelection();
  }
};

watch(
  () => filteredClips.value.map((clip) => clip.id),
  (next) => {
    if (!next.includes(selectedId.value ?? '')) {
      selectedId.value = next[0] ?? null;
    }
  },
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
        <label class="search">
          <input v-model="searchQuery" type="search" placeholder="搜索内容" />
        </label>
        <div class="status">{{ filteredClips.length }} / {{ favoriteCount }}</div>
      </header>

      <section class="layout">
        <SidebarTabs v-model="activeTab" :tabs="tabs" />
        <ClipList
          :items="filteredClips"
          :selected-id="selectedClip?.id ?? null"
          @select="selectedId = $event"
          @toggle-favorite="toggleFavorite"
          @remove="removeClip"
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
  background: #fff;
  color: #0f172a;
}
:global(button), :global(input), :global(textarea), :global(select) { font: inherit; }

.app-frame {
  width: 100%;
  height: 100%;
  overflow: hidden;
}
.shell {
  width: 100%;
  height: 100%;
  display: grid;
  grid-template-rows: 38px 1fr auto;
  overflow: hidden;
}
.topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 4px 8px;
  border-bottom: 1px solid #e2e8f0;
}
.search input {
  width: 190px;
  border: 1px solid #cbd5e1;
  border-radius: 4px;
  padding: 4px 8px;
  outline: none;
  background: #fff;
  font-size: 13px;
}
.search input:focus {
  border-color: #64748b;
}
.status {
  font-size: 12px;
  color: #64748b;
}
.layout {
  min-height: 0;
  display: grid;
  grid-template-columns: 64px minmax(220px, 300px) minmax(0, 1fr);
}
.layout > * {
  min-height: 0;
  border-right: 1px solid #e2e8f0;
}
.layout > *:last-child {
  border-right: none;
}

@media (max-width: 980px) {
  .layout {
    grid-template-columns: 1fr;
    grid-template-rows: auto minmax(180px, 36vh) 1fr;
  }
  .layout > * {
    border-right: none;
    border-bottom: 1px solid #e2e8f0;
  }
  .layout > *:last-child {
    border-bottom: none;
  }
}
.footer {
  padding: 6px 10px;
  font-size: 12px;
  border-top: 1px solid #fecaca;
}
.error {
  color: #b91c1c;
  background: #fef2f2;
}
</style>
