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
  padding: 16px;
  display: grid;
  grid-template-rows: auto 1fr;
  gap: 16px;
  min-height: 0;
}
.panel-header p,
.panel-header h2 { margin: 0; }
.panel-header p { color: #64748b; font-size: 14px; margin-bottom: 6px; }
.panel-header h2 { font-size: 20px; font-weight: 600; color: #1e293b; }
.list {
  display: flex;
  flex-direction: column;
  gap: 12px;
  overflow: auto;
}
.card {
  padding: 16px;
  border-radius: 12px;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  cursor: pointer;
  transition: border-color 0.2s ease, box-shadow 0.2s ease;
}
.card:hover {
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}
.card.active {
  border-color: #94a3b8;
  box-shadow: 0 0 0 3px rgba(148, 163, 184, 0.1);
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
  padding: 4px 8px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 500;
}
.kind {
  background: #f1f5f9;
  color: #475569;
}
.pin-badge {
  background: #fef3c7;
  color: #92400e;
}
.favorite {
  border: none;
  background: transparent;
  color: #64748b;
  font-size: 18px;
  cursor: pointer;
  transition: color 0.2s ease;
}
.favorite:hover {
  color: #1e293b;
}
.preview-box {
  margin: 12px 0;
  min-height: 100px;
  max-height: 140px;
  overflow: hidden;
  border-radius: 8px;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
}
.preview-box img {
  width: 100%;
  height: 140px;
  object-fit: cover;
  display: block;
}
.preview-box pre {
  margin: 0;
  padding: 12px;
  white-space: pre-wrap;
  word-break: break-word;
  font-family: 'SFMono-Regular', ui-monospace, monospace;
  color: #475569;
  font-size: 14px;
}
.meta strong {
  font-size: 14px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: #1e293b;
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
  color: #64748b;
  padding: 24px;
  font-size: 14px;
}
</style>
