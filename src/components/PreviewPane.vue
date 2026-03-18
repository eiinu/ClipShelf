<script setup lang="ts">
import CodeEditor from './CodeEditor.vue';

interface ClipItem {
  id: string;
  title: string;
  preview: string;
  kind: 'text' | 'html' | 'image';
  text?: string | null;
  html?: string | null;
  image_data_url?: string | null;
}

defineProps<{
  clip: ClipItem | null;
}>();
</script>

<template>
  <section class="preview-panel">
    <template v-if="clip">
      <header class="header">
        <div>
          <p>详情预览</p>
          <h2>{{ clip.title }}</h2>
        </div>
      </header>

      <CodeEditor
        v-if="clip.kind === 'text'"
        :model-value="clip.text ?? ''"
        language-label="Plain Text"
      />
      <CodeEditor
        v-else-if="clip.kind === 'html'"
        :model-value="clip.html ?? ''"
        language-label="HTML"
      />
      <div v-else class="image-viewer">
        <img :src="clip.image_data_url ?? ''" alt="clipboard image" />
      </div>
    </template>

    <div v-else class="empty-state">
      还没有选中的条目。先在系统中复制一点内容试试。
    </div>
  </section>
</template>

<style scoped>
.preview-panel {
  padding: 22px;
  display: grid;
  grid-template-rows: auto 1fr;
  gap: 18px;
  min-height: 0;
}
.header p,
.header h2 { margin: 0; }
.header p { color: #94a3b8; margin-bottom: 6px; font-size: 14px; }
.header h2 { font-size: 24px; }
.image-viewer,
.empty-state {
  min-height: 0;
  border-radius: 24px;
  border: 1px solid rgba(148, 163, 184, 0.16);
  background: rgba(15, 23, 42, 0.92);
}
.image-viewer {
  display: grid;
  place-items: center;
  overflow: hidden;
  padding: 24px;
}
.image-viewer img {
  max-width: 100%;
  max-height: 100%;
  object-fit: contain;
  border-radius: 18px;
  box-shadow: 0 24px 60px rgba(15, 23, 42, 0.5);
}
.empty-state {
  display: grid;
  place-items: center;
  color: #94a3b8;
}
</style>
