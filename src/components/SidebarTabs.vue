<script setup lang="ts">
defineProps<{
  modelValue: string;
  tabs: Array<{ key: string; label: string }>;
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
      {{ tab.label }}
    </button>
  </aside>
</template>

<style scoped>
.sidebar {
  display: flex;
  flex-direction: column;
  min-height: 0;
}
.tab {
  width: 100%;
  height: 34px;
  padding: 0;
  border: none;
  border-bottom: 1px solid #e2e8f0;
  background: #fff;
  color: #64748b;
  cursor: pointer;
  font-size: 12px;
  text-align: center;
}
.tab.active {
  color: #0f172a;
  font-weight: 600;
  background: #f8fafc;
}

@media (max-width: 980px) {
  .sidebar {
    flex-direction: row;
    overflow-x: auto;
  }
  .tab {
    min-width: 68px;
    border-bottom: none;
    border-right: 1px solid #e2e8f0;
  }
}
</style>
