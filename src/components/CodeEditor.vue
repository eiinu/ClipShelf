<script setup lang="ts">
defineProps<{
  modelValue: string;
  languageLabel: string;
}>();
</script>

<template>
  <section class="editor-shell">
    <div class="toolbar">
      <span class="traffic">
        <i />
        <i />
        <i />
      </span>
      <span>{{ languageLabel }}</span>
    </div>
    <textarea class="editor" :value="modelValue" readonly spellcheck="false" />
  </section>
</template>

<style scoped>
.editor-shell {
  display: grid;
  grid-template-rows: auto 1fr;
  min-height: 0;
  border-radius: 22px;
  overflow: hidden;
  border: 1px solid rgba(148, 163, 184, 0.16);
  background: rgba(15, 23, 42, 0.92);
}
.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 16px;
  background: rgba(30, 41, 59, 0.92);
  color: #94a3b8;
  font-size: 13px;
}
.traffic { display: inline-flex; gap: 8px; }
.traffic i {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  display: block;
}
.traffic i:nth-child(1) { background: #fb7185; }
.traffic i:nth-child(2) { background: #fbbf24; }
.traffic i:nth-child(3) { background: #4ade80; }
.editor {
  min-height: 0;
  height: 100%;
  width: 100%;
  border: none;
  outline: none;
  resize: none;
  padding: 18px;
  color: #e2e8f0;
  background: transparent;
  font-family: 'SFMono-Regular', ui-monospace, monospace;
  font-size: 14px;
  line-height: 1.6;
}
</style>
