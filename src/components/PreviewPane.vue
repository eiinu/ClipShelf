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
          <h2>{{ clip.title }}</h2>
        </div>
      </header>

      <CodeEditor
        v-if="clip.kind === 'text'"
        :model-value="clip.text ?? ''"
        language="text"
        language-label="Plain Text"
      />
      <CodeEditor
        v-else-if="clip.kind === 'html'"
        :model-value="clip.html ?? ''"
        language="html"
        language-label="HTML"
      />
      <div v-else class="image-viewer">
        <img :src="clip.image_data_url ?? ''" alt="clipboard image" />
      </div>
    </template>

    <div v-else class="empty-state">
未选中内容
    </div>
  </section>
</template>

<style scoped>
.preview-panel {
  padding: 16px;
  display: grid;
  grid-template-rows: auto 1fr;
  gap: 16px;
  min-height: 0;
}
.header h2 { margin: 0; font-size: 18px; font-weight: 600; color: #1e293b; }
.image-viewer,
.empty-state {
  min-height: 0;
  border-radius: 8px;
  border: 1px solid #e2e8f0;
  background: #f8fafc;
}
.image-viewer {
  display: grid;
  place-items: center;
  overflow: hidden;
  padding: 16px;
}
.image-viewer img {
  max-width: 100%;
  max-height: 100%;
  object-fit: contain;
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}
.empty-state {
  display: grid;
  place-items: center;
  color: #64748b;
  font-size: 14px;
  padding: 16px;
}
</style>
