<script setup lang="ts">
interface ClipItem {
  id: string;
  title: string;
  preview: string;
  kind: 'text' | 'html' | 'image';
  favorite: boolean;
  pinned: boolean;
  image_data_url?: string | null;
  createdAt: string;
}

defineProps<{
  items: ClipItem[];
  selectedId: string | null;
}>();

const emit = defineEmits<{
  (e: 'select', id: string): void;
  (e: 'toggle-favorite', id: string): void;
  (e: 'toggle-pinned', id: string): void;
}>();

const kindLabel: Record<ClipItem['kind'], string> = {
  text: '文本',
  html: 'HTML',
  image: '图片',
};
</script>

<template>
  <section class="panel">
    <div class="panel-header">
      <div>
        <p>剪贴板历史</p>
        <h2>{{ items.length }} 个条目</h2>
      </div>
    </div>

    <div v-if="items.length" class="list">
      <article
        v-for="item in items"
        :key="item.id"
        class="card"
        :class="{ active: selectedId === item.id }"
        @click="emit('select', item.id)"
      >
        <div class="card-top">
          <div class="badges">
            <span class="kind">{{ kindLabel[item.kind] }}</span>
            <span v-if="item.pinned" class="pin-badge">置顶</span>
          </div>
          <div class="actions">
            <button class="favorite" :title="item.pinned ? '取消置顶' : '置顶到顶部'" @click.stop="emit('toggle-pinned', item.id)">
              {{ item.pinned ? '📌' : '📍' }}
            </button>
            <button class="favorite" :title="item.favorite ? '取消收藏' : '加入收藏'" @click.stop="emit('toggle-favorite', item.id)">
              {{ item.favorite ? '★' : '☆' }}
            </button>
          </div>
        </div>

        <div class="preview-box">
          <img v-if="item.kind === 'image' && item.image_data_url" :src="item.image_data_url" alt="preview" />
          <pre v-else>{{ item.preview }}</pre>
        </div>

        <div class="meta">
          <strong>{{ item.title }}</strong>
          <span>{{ new Date(item.createdAt).toLocaleTimeString() }}</span>
        </div>
      </article>
    </div>

    <div v-else class="empty">
      当前筛选条件下没有结果。你可以复制任意文本、HTML 或图片，或者调整搜索词试试。
    </div>
  </section>
</template>

<style scoped>
.panel {
  padding: 18px;
  display: grid;
  grid-template-rows: auto 1fr;
  gap: 16px;
  min-height: 0;
}
.panel-header p,
.panel-header h2 { margin: 0; }
.panel-header p { color: #94a3b8; font-size: 14px; margin-bottom: 6px; }
.panel-header h2 { font-size: 24px; }
.list {
  display: flex;
  flex-direction: column;
  gap: 14px;
  overflow: auto;
}
.card {
  padding: 14px;
  border-radius: 20px;
  background: rgba(30, 41, 59, 0.78);
  border: 1px solid transparent;
  cursor: pointer;
}
.card.active {
  border-color: rgba(96, 165, 250, 0.5);
  box-shadow: inset 0 0 0 1px rgba(96, 165, 250, 0.18);
}
.card-top,
.meta {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
}
.badges,
.actions {
  display: flex;
  align-items: center;
  gap: 8px;
}
.kind,
.pin-badge {
  padding: 6px 10px;
  border-radius: 999px;
  font-size: 12px;
}
.kind {
  background: rgba(59, 130, 246, 0.18);
  color: #bfdbfe;
}
.pin-badge {
  background: rgba(244, 114, 182, 0.18);
  color: #fbcfe8;
}
.favorite {
  border: none;
  background: transparent;
  color: #f8fafc;
  font-size: 20px;
  cursor: pointer;
}
.preview-box {
  margin: 14px 0;
  min-height: 120px;
  max-height: 160px;
  overflow: hidden;
  border-radius: 16px;
  background: rgba(15, 23, 42, 0.92);
  border: 1px solid rgba(148, 163, 184, 0.12);
}
.preview-box img {
  width: 100%;
  height: 160px;
  object-fit: cover;
  display: block;
}
.preview-box pre {
  margin: 0;
  padding: 14px;
  white-space: pre-wrap;
  word-break: break-word;
  font-family: 'SFMono-Regular', ui-monospace, monospace;
  color: #dbeafe;
}
.meta strong {
  font-size: 14px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.meta span {
  color: #94a3b8;
  font-size: 12px;
  flex-shrink: 0;
}
.empty {
  display: grid;
  place-items: center;
  text-align: center;
  color: #94a3b8;
  padding: 24px;
}
</style>
