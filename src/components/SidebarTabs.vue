<script setup lang="ts">
defineProps<{
  modelValue: string;
  tabs: Array<{ key: string; label: string; emoji: string }>;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: string): void;
}>();
</script>

<template>
  <aside class="sidebar">
    <button
      v-for="tab in tabs"
      :key="tab.key"
      class="tab"
      :class="{ active: modelValue === tab.key }"
      @click="emit('update:modelValue', tab.key)"
    >
      <span class="emoji">{{ tab.emoji }}</span>
      <span class="label">{{ tab.label }}</span>
    </button>
  </aside>
</template>

<style scoped>
.sidebar {
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.tab {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  border-radius: 8px;
  border: 1px solid transparent;
  background: #ffffff;
  color: #64748b;
  cursor: pointer;
  transition: all 0.2s ease;
  font-size: 14px;
  font-weight: 500;
}
.tab:hover,
.tab.active {
  background: #f1f5f9;
  border-color: #e2e8f0;
  color: #1e293b;
}
.emoji {
  width: 24px;
  text-align: center;
  font-weight: 600;
}
.label { font-size: 14px; }
</style>
