<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { invoke } from '@tauri-apps/api/core';
import { listen, type UnlistenFn } from '@tauri-apps/api/event';
import SidebarTabs from './components/SidebarTabs.vue';
import ClipList from './components/ClipList.vue';
import PreviewPane from './components/PreviewPane.vue';
import { OPENXML_REFERENCE, type OpenXmlEntry } from './data/openxmlReference';

type ClipKind = 'text' | 'html' | 'image';
type ClipTab = 'default' | 'favorites' | ClipKind;
type AppMode = 'home' | 'search' | 'workspace';

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
const appMode = ref<AppMode>('home');
const listenerError = ref('');
const storageError = ref('');
const searchQuery = ref('');
const homeQuery = ref('');
const pickedFileName = ref('');
const openxmlResults = ref<OpenXmlEntry[]>([]);
const storageReady = ref(false);
const uploadInput = ref<HTMLInputElement | null>(null);
let unlistenClipboard: UnlistenFn | null = null;
let unlistenError: UnlistenFn | null = null;
const CLIP_RETENTION_DAYS = 7;
const CLIP_RETENTION_MS = CLIP_RETENTION_DAYS * 24 * 60 * 60 * 1000;

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
const normalizedOpenXmlQuery = computed(() => homeQuery.value.trim().toLowerCase());

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

const removeClip = (id: string) => {
  clips.value = clips.value.filter((clip) => clip.id !== id);
  if (selectedId.value === id) {
    selectedId.value = null;
    ensureSelection();
  }
};

const runOpenXmlSearch = () => {
  if (!normalizedOpenXmlQuery.value) return;
  const keyword = normalizedOpenXmlQuery.value;
  openxmlResults.value = OPENXML_REFERENCE.filter((entry) =>
    [entry.label, entry.category, entry.path, entry.description, ...entry.attributes, ...entry.tags]
      .join(' ')
      .toLowerCase()
      .includes(keyword),
  );
  appMode.value = 'search';
};

const backToHome = () => {
  appMode.value = 'home';
};

const triggerUpload = () => {
  uploadInput.value?.click();
};

const onFilePicked = (event: Event) => {
  const target = event.target as HTMLInputElement;
  const file = target.files?.[0];
  if (!file) return;
  pickedFileName.value = file.name;
  appMode.value = 'workspace';
  target.value = '';
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
    <main v-if="appMode === 'home'" class="home-shell">
      <section class="home-card">
        <h1>ClipShelf + OpenXML</h1>
        <p class="home-subtitle">输入关键词查询 OpenXML 规范标签/属性，或上传文档进入预览工具。</p>
        <div class="hero-actions">
          <input
            v-model="homeQuery"
            type="search"
            placeholder="例如：w:p、Relationship、r:embed"
            @keydown.enter="runOpenXmlSearch"
          />
          <button class="btn-primary" @click="runOpenXmlSearch">查询规范</button>
          <button class="btn-secondary" @click="triggerUpload">上传文档</button>
          <input
            ref="uploadInput"
            class="hidden-upload"
            type="file"
            accept=".docx,.xlsx,.pptx"
            @change="onFilePicked"
          />
        </div>
      </section>
    </main>

    <main v-else-if="appMode === 'search'" class="search-shell">
      <header class="search-header">
        <button class="btn-link" @click="backToHome">← 返回主入口</button>
        <div class="search-meta">关键词：{{ homeQuery }}，共 {{ openxmlResults.length }} 条</div>
      </header>
      <section class="result-list">
        <article v-for="item in openxmlResults" :key="item.id" class="result-card">
          <h3>{{ item.label }} <span>{{ item.category }}</span></h3>
          <p>{{ item.description }}</p>
          <p><strong>常见属性：</strong>{{ item.attributes.join('、') }}</p>
          <p><strong>典型位置：</strong>{{ item.path }}</p>
        </article>
        <div v-if="!openxmlResults.length" class="empty-result">
          没有匹配项，可以尝试标签名（如 w:r）、语义词（如 table）或属性名（如 Target）。
        </div>
      </section>
    </main>

    <main v-else class="shell">
      <header class="topbar">
        <label class="search">
          <input v-model="searchQuery" type="search" placeholder="搜索内容" />
        </label>
        <div class="status">{{ filteredClips.length }} / {{ favoriteCount }}</div>
      </header>

      <section class="workspace-banner">
        当前文件：{{ pickedFileName || '未指定（可继续作为现有工具使用）' }}
        <button class="btn-link" @click="backToHome">返回主入口</button>
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
  background: radial-gradient(circle at top, #f8fafc, #eef2ff 46%, #e2e8f0);
}
.home-shell,
.search-shell {
  width: 100%;
  height: 100%;
  display: grid;
  place-items: center;
  padding: 24px;
}
.home-card {
  width: min(860px, 100%);
  background: #ffffffdd;
  border: 1px solid #dbeafe;
  border-radius: 16px;
  padding: 36px 28px;
  box-shadow: 0 20px 40px #0f172a1c;
}
.home-card h1 {
  margin: 0;
  font-size: 30px;
}
.home-subtitle {
  color: #475569;
  margin: 8px 0 20px;
}
.hero-actions {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto auto;
  gap: 10px;
}
.hero-actions input {
  border: 1px solid #cbd5e1;
  border-radius: 10px;
  padding: 11px 12px;
}
.btn-primary,
.btn-secondary {
  border-radius: 10px;
  padding: 0 14px;
  border: none;
  cursor: pointer;
}
.btn-primary {
  background: #2563eb;
  color: #fff;
}
.btn-secondary {
  background: #e2e8f0;
  color: #0f172a;
}
.hidden-upload {
  display: none;
}
.search-shell {
  grid-template-rows: auto minmax(0, 1fr);
  place-items: stretch;
}
.search-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 8px 2px;
}
.result-list {
  overflow: auto;
  display: grid;
  align-content: start;
  gap: 12px;
  padding-right: 2px;
}
.result-card {
  background: #ffffffeb;
  border: 1px solid #cbd5e1;
  border-radius: 12px;
  padding: 14px;
}
.result-card h3 {
  margin: 0 0 8px;
  display: flex;
  gap: 8px;
  align-items: center;
}
.result-card h3 span {
  font-size: 12px;
  color: #475569;
  font-weight: 500;
}
.result-card p {
  margin: 4px 0;
  color: #334155;
}
.empty-result {
  text-align: center;
  padding: 24px 12px;
  color: #64748b;
}
.btn-link {
  border: none;
  background: transparent;
  color: #2563eb;
  cursor: pointer;
  padding: 0;
}
.shell {
  width: 100%;
  height: 100%;
  display: grid;
  grid-template-rows: 38px 34px 1fr auto;
  overflow: hidden;
  background: #fff;
}
.topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 4px 8px;
  border-bottom: 1px solid #e2e8f0;
}
.workspace-banner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 6px 10px;
  font-size: 12px;
  color: #475569;
  border-bottom: 1px solid #e2e8f0;
  background: #f8fafc;
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
  .hero-actions {
    grid-template-columns: 1fr;
  }
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
