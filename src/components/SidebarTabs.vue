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
  padding: 18px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.tab {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 16px;
  border-radius: 18px;
  border: 1px solid transparent;
  background: transparent;
  color: #cbd5e1;
  cursor: pointer;
  transition: 180ms ease;
}
.tab:hover,
.tab.active {
  background: linear-gradient(135deg, rgba(59, 130, 246, 0.18), rgba(167, 139, 250, 0.18));
  border-color: rgba(96, 165, 250, 0.35);
  color: #eff6ff;
}
.emoji {
  width: 28px;
  text-align: center;
  font-weight: 700;
}
.label { font-size: 15px; }
</style>
