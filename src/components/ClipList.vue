<script setup lang="ts">
import { reactive, watch } from 'vue';

interface ClipItem {
  id: string;
  preview: string;
  kind: 'text' | 'html' | 'image';
  favorite: boolean;
  createdAt: string;
  groupId?: string | null;
  image_data_url?: string | null;
}

const props = defineProps<{
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

const kindStyle: Record<ClipItem['kind'], { color: string; background: string }> = {
  text: { color: '#1d4ed8', background: '#dbeafe' },
  html: { color: '#b45309', background: '#fef3c7' },
  image: { color: '#7c3aed', background: '#ede9fe' },
};

const imageSizeMap = reactive<Record<string, { width: number; height: number }>>({});

const formatDateTime = (isoDate: string) => {
  const date = new Date(isoDate);
  const yy = String(date.getFullYear()).slice(-2);
  const mm = String(date.getMonth() + 1).padStart(2, '0');
  const dd = String(date.getDate()).padStart(2, '0');
  const hh = String(date.getHours()).padStart(2, '0');
  const min = String(date.getMinutes()).padStart(2, '0');
  return `${yy}.${mm}.${dd} ${hh}:${min}`;
};

const preloadImageSize = (item: ClipItem) => {
  if (item.kind !== 'image' || !item.image_data_url || imageSizeMap[item.id]) return;

  const img = new Image();
  img.onload = () => {
    imageSizeMap[item.id] = {
      width: img.naturalWidth,
      height: img.naturalHeight,
    };
  };
  img.src = item.image_data_url;
};

const isGroupedWithPrev = (index: number) =>
  index > 0 &&
  !!props.items[index].groupId &&
  props.items[index - 1].groupId === props.items[index].groupId;

const isGroupedWithNext = (index: number) =>
  index < props.items.length - 1 &&
  !!props.items[index].groupId &&
  props.items[index + 1].groupId === props.items[index].groupId;

watch(
  () => props.items,
  (items) => {
    items.forEach((item) => preloadImageSize(item));
  },
  { immediate: true },
);
</script>

<template>
  <section class="panel">
    <div v-if="items.length" class="list">
      <article
        v-for="(item, index) in items"
        :key="item.id"
        class="row"
        :class="{
          active: selectedId === item.id,
          'linked-prev': isGroupedWithPrev(index),
          'linked-next': isGroupedWithNext(index),
        }"
        @click="emit('select', item.id)"
      >
        <div class="content">
          <div class="head">
            <span class="kind" :style="{ color: kindStyle[item.kind].color, backgroundColor: kindStyle[item.kind].background }">
              {{ kindLabel[item.kind] }}
            </span>
            <span class="time">{{ formatDateTime(item.createdAt) }}</span>
          </div>
          <div class="preview-line">
            <template v-if="item.kind === 'image'">
              <img class="thumb" :src="item.image_data_url ?? ''" alt="image thumbnail" />
              <span class="meta">
                图片
                {{ imageSizeMap[item.id] ? `${imageSizeMap[item.id].width} × ${imageSizeMap[item.id].height}` : '加载中...' }}
              </span>
            </template>
            <span v-else class="preview">{{ item.preview }}</span>
          </div>
        </div>

        <div class="actions">
          <button
            class="icon-btn"
            :title="item.favorite ? '取消收藏' : '加入收藏'"
            @click.stop="emit('toggle-favorite', item.id)"
          >
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path
                :d="item.favorite
                  ? 'M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z'
                  : 'M22 9.24l-7.19-.62L12 2 9.19 8.62 2 9.24l5.46 4.73L5.82 21 12 17.27 18.18 21l-1.63-7.03zM12 15.4l-3.76 2.27 1-4.28-3.32-2.88 4.38-.38L12 6.1l1.7 4.03 4.38.38-3.32 2.88 1 4.28z'"
              />
            </svg>
          </button>
          <button class="icon-btn delete" title="删除" @click.stop="emit('remove', item.id)">
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M6 7h12v2H6zm2 3h2v8H8zm6 0h2v8h-2zM9 4h6l1 1h4v2H4V5h4z" />
            </svg>
          </button>
        </div>
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
  position: relative;
  min-height: 68px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: 10px;
  border-bottom: 1px solid #e2e8f0;
  cursor: pointer;
}
.row::before {
  content: '';
  position: absolute;
  left: 4px;
  width: 2px;
  background: transparent;
  border-radius: 999px;
}
.row.linked-prev::before {
  top: -8px;
  bottom: 50%;
  background: #94a3b8;
}
.row.linked-next::before {
  top: 50%;
  bottom: -8px;
  background: #94a3b8;
}
.row.linked-prev.linked-next::before {
  top: -8px;
  bottom: -8px;
}
.row:hover,
.row.active {
  background: #f8fafc;
}
.content {
  min-width: 0;
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}
.kind {
  display: inline-flex;
  align-items: center;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 600;
  padding: 2px 8px;
}
.time {
  font-size: 11px;
  color: #64748b;
  white-space: nowrap;
}
.preview-line {
  min-height: 22px;
  display: flex;
  align-items: center;
  gap: 8px;
}
.preview {
  font-size: 12px;
  color: #0f172a;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.thumb {
  width: 28px;
  height: 28px;
  border-radius: 6px;
  object-fit: cover;
  border: 1px solid #cbd5e1;
  background: #fff;
}
.meta {
  font-size: 12px;
  color: #334155;
  white-space: nowrap;
}
.actions {
  display: flex;
  align-items: center;
  gap: 4px;
}
.icon-btn {
  width: 24px;
  height: 24px;
  border: none;
  background: transparent;
  color: #64748b;
  border-radius: 6px;
  cursor: pointer;
  padding: 3px;
  line-height: 1;
  transition: background-color 0.16s ease, color 0.16s ease;
}
.icon-btn svg {
  width: 100%;
  height: 100%;
  fill: currentColor;
}
.icon-btn:hover {
  background: #e2e8f0;
  color: #0f172a;
}
.icon-btn.delete:hover {
  color: #dc2626;
  background: #fee2e2;
}
.empty {
  height: 100%;
  display: grid;
  place-items: center;
  font-size: 12px;
  color: #64748b;
}
</style>
