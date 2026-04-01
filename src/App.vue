<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { invoke } from '@tauri-apps/api/core';
import { listen, type UnlistenFn } from '@tauri-apps/api/event';
import SidebarTabs from './components/SidebarTabs.vue';
import ClipList from './components/ClipList.vue';
import PreviewPane from './components/PreviewPane.vue';

type ClipKind = 'text' | 'html' | 'image';
type ClipTab = 'default' | 'favorites' | ClipKind | `tag:${string}`;

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
  groupId?: string | null;
  tags?: string[];
}

const baseTabs: Array<{ key: ClipTab; label: string }> = [
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
const tagInput = ref('');
let unlistenClipboard: UnlistenFn | null = null;
let unlistenError: UnlistenFn | null = null;
const CLIP_RETENTION_DAYS = 7;
const CLIP_RETENTION_MS = CLIP_RETENTION_DAYS * 24 * 60 * 60 * 1000;

const compareClips = (left: ClipItem, right: ClipItem) => {
  if (left.pinned !== right.pinned) return Number(right.pinned) - Number(left.pinned);
  return new Date(right.createdAt).getTime() - new Date(left.createdAt).getTime();
};

const normalizedQuery = computed(() => searchQuery.value.trim().toLowerCase());

const normalizeTag = (tag: string) => tag.trim().replace(/\s+/g, ' ');

const allTags = computed(() => {
  const tags = new Set<string>();
  clips.value.forEach((clip) => {
    (clip.tags ?? []).forEach((tag) => {
      if (tag) tags.add(tag);
    });
  });
  return [...tags].sort((left, right) => left.localeCompare(right, 'zh-Hans-CN'));
});

const tabs = computed<Array<{ key: ClipTab; label: string }>>(() => [
  ...baseTabs,
  ...allTags.value.map((tag) => ({ key: `tag:${tag}` as ClipTab, label: tag })),
]);

const filteredClips = computed(() => {
  const byTab =
    activeTab.value === 'default'
      ? clips.value
      : activeTab.value === 'favorites'
        ? clips.value.filter((clip) => clip.favorite)
        : activeTab.value.startsWith('tag:')
          ? clips.value.filter((clip) => (clip.tags ?? []).includes(activeTab.value.slice(4)))
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
const selectedClipTags = computed(() => selectedClip.value?.tags ?? []);

const fingerprint = (payload: ClipboardPayload) =>
  [payload.kind, payload.text ?? '', payload.html ?? '', payload.image_data_url ?? ''].join('::');

const createClipId = (payload: ClipboardPayload) => {
  const entropy = crypto.randomUUID();
  return `${Date.now()}::${entropy}::${fingerprint(payload)}`;
};

const pruneExpiredClips = (items: ClipItem[], now = Date.now()) => {
  const cutoff = now - CLIP_RETENTION_MS;
  return items.filter((clip) => {
    const createdAt = new Date(clip.createdAt).getTime();
    return Number.isNaN(createdAt) || createdAt >= cutoff;
  });
};

const firstLine = (content: string, fallback: string) =>
  content
    .split('\n')
    .map((line) => line.trim())
    .find((line) => line.length > 0)
    ?.slice(0, 48) ?? fallback;

const ensureSelection = () => {
  if (!selectedClip.value && filteredClips.value[0]) {
    selectedId.value = filteredClips.value[0].id;
  }
};

const pushClip = (payload: ClipboardPayload) => {
  const nextItems: ClipItem[] = [];
  const baseTimestamp = Date.now();
  const groupId = payload.kind === 'html' && payload.text ? crypto.randomUUID() : null;

  if (payload.kind === 'html' && payload.text) {
    const plainText = payload.text;
    const textPayload: ClipboardPayload = {
      kind: 'text',
      title: firstLine(plainText, 'Text clip'),
      preview: plainText.replace(/\s+/g, ' ').slice(0, 180),
      text: plainText,
      html: null,
      image_data_url: null,
      source: 'NSPasteboardTypeString',
    };
    nextItems.push({
      ...textPayload,
      id: createClipId(textPayload),
      favorite: false,
      pinned: false,
      groupId,
      tags: [],
      createdAt: new Date(baseTimestamp).toISOString(),
    });
  }

  const mainId = createClipId(payload);
  nextItems.push({
    ...payload,
    id: mainId,
    favorite: false,
    pinned: false,
    groupId,
    tags: [],
    createdAt: new Date(baseTimestamp + 1).toISOString(),
  });

  clips.value = [...nextItems, ...clips.value].sort(compareClips);

  selectedId.value = mainId;
  ensureSelection();
};

const loadSavedClips = async () => {
  try {
    const saved = await invoke<ClipItem[]>('load_saved_clips');
    const pruned = pruneExpiredClips(saved);
    clips.value = [...pruned].sort(compareClips);
    selectedId.value = clips.value[0]?.id ?? null;
    storageError.value = '';
    if (pruned.length !== saved.length) {
      await saveClips(clips.value);
    }
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

const addTagToClip = (id: string, rawTag: string) => {
  const tag = normalizeTag(rawTag);
  if (!tag) return;

  clips.value = clips.value.map((clip) => {
    if (clip.id !== id) return clip;
    const existing = new Set(clip.tags ?? []);
    existing.add(tag);
    return { ...clip, tags: [...existing] };
  });
  tagInput.value = '';
};

const removeTagFromClip = (id: string, tag: string) => {
  clips.value = clips.value.map((clip) =>
    clip.id === id ? { ...clip, tags: (clip.tags ?? []).filter((item) => item !== tag) } : clip,
  );
  if (activeTab.value === `tag:${tag}` && !clips.value.some((clip) => (clip.tags ?? []).includes(tag))) {
    activeTab.value = 'default';
  }
};

const submitTagInput = () => {
  if (!selectedClip.value) return;
  addTagToClip(selectedClip.value.id, tagInput.value);
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
  tabs,
  (nextTabs) => {
    if (!nextTabs.some((tab) => tab.key === activeTab.value)) {
      activeTab.value = 'default';
    }
  },
  { immediate: true },
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

      <section class="tag-editor">
        <template v-if="selectedClip">
          <div class="tag-input-wrap">
            <input
              v-model="tagInput"
              list="tag-suggestions"
              type="text"
              placeholder="添加标签，例如：密码"
              @keydown.enter.prevent="submitTagInput"
            />
            <button type="button" @click="submitTagInput">添加</button>
            <datalist id="tag-suggestions">
              <option v-for="tag in allTags" :key="tag" :value="tag" />
            </datalist>
          </div>
          <div class="tag-list">
            <button
              v-for="tag in selectedClipTags"
              :key="tag"
              class="tag-chip"
              type="button"
              @click="removeTagFromClip(selectedClip.id, tag)"
            >
              {{ tag }} ×
            </button>
            <span v-if="!selectedClipTags.length" class="tag-empty">未添加标签</span>
          </div>
        </template>
      </section>

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
  grid-template-rows: 38px auto 1fr auto;
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
.tag-editor {
  padding: 6px 8px;
  border-bottom: 1px solid #e2e8f0;
  display: grid;
  gap: 6px;
}
.tag-input-wrap {
  display: flex;
  align-items: center;
  gap: 6px;
}
.tag-input-wrap input {
  width: 240px;
  max-width: 100%;
  border: 1px solid #cbd5e1;
  border-radius: 4px;
  padding: 4px 8px;
  font-size: 12px;
}
.tag-input-wrap button {
  border: 1px solid #cbd5e1;
  background: #fff;
  border-radius: 4px;
  padding: 4px 10px;
  font-size: 12px;
  cursor: pointer;
}
.tag-list {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 6px;
}
.tag-chip {
  border: none;
  background: #e2e8f0;
  color: #334155;
  border-radius: 999px;
  padding: 2px 8px;
  font-size: 11px;
  cursor: pointer;
}
.tag-empty {
  font-size: 12px;
  color: #94a3b8;
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
