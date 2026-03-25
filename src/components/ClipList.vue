<script setup lang="ts">
interface ClipItem {
  id: string;
  preview: string;
  kind: 'text' | 'html' | 'image';
  favorite: boolean;
  createdAt: string;
}

defineProps<{
  items: ClipItem[];
  selectedId: string | null;
}>();

const emit = defineEmits<{
  (e: 'select', id: string): void;
  (e: 'toggle-favorite', id: string): void;
  (e: 'remove', id: string): void;
}>();

const kindLabel: Record<ClipItem['kind'], string> = {
  text: '文本',
  html: 'HTML',
  image: '图片',
};
</script>

<template>
  <section class="panel">
    <div v-if="items.length" class="list">
      <article
        v-for="item in items"
        :key="item.id"
        class="row"
        :class="{ active: selectedId === item.id }"
        @click="emit('select', item.id)"
      >
        <span class="kind">{{ kindLabel[item.kind] }}</span>
        <span class="time">{{ new Date(item.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) }}</span>
        <button
          class="icon-btn"
          :title="item.favorite ? '取消收藏' : '加入收藏'"
          @click.stop="emit('toggle-favorite', item.id)"
        >
          {{ item.favorite ? '★' : '☆' }}
        </button>
        <button class="icon-btn delete" title="删除" @click.stop="emit('remove', item.id)">🗑</button>
        <span class="preview">{{ item.preview }}</span>
      </article>
    </div>

    <div v-else class="empty">无结果</div>
  </section>
</template>

<style scoped>
.panel {
  min-height: 0;
}
.list {
  height: 100%;
  overflow: auto;
}
.row {
  height: 50px;
  display: grid;
  grid-template-columns: 42px 52px 28px 28px minmax(0, 1fr);
  align-items: center;
  gap: 6px;
  padding: 0 8px;
  border-bottom: 1px solid #e2e8f0;
  cursor: pointer;
}
.row:hover,
.row.active {
  background: #f8fafc;
}
.kind,
.time {
  font-size: 11px;
  color: #64748b;
}
.icon-btn {
  width: 24px;
  height: 24px;
  border: none;
  background: transparent;
  color: #334155;
  cursor: pointer;
  padding: 0;
  line-height: 1;
}
.icon-btn.delete {
  font-size: 12px;
}
.preview {
  font-size: 12px;
  color: #0f172a;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.empty {
  height: 100%;
  display: grid;
  place-items: center;
  font-size: 12px;
  color: #64748b;
}
</style>
