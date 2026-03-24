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
  padding: 12px 8px;
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-height: 0;
}
.tab {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 6px;
  width: 100%;
  min-height: 66px;
  padding: 10px 6px;
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
  width: 100%;
  text-align: center;
  font-weight: 600;
}
.label {
  font-size: 12px;
  line-height: 1.2;
  text-align: center;
  white-space: nowrap;
}

@media (max-width: 980px) {
  .sidebar {
    flex-direction: row;
    flex-wrap: wrap;
    padding: 12px;
    gap: 6px;
  }
  .tab {
    padding: 8px 10px;
    gap: 8px;
  }
  .emoji {
    width: auto;
  }
}
</style>
