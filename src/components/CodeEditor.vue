<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { EditorState } from '@codemirror/state';
import { EditorView } from '@codemirror/view';
import { basicSetup } from 'codemirror';
import { html } from '@codemirror/lang-html';

type EditorLanguage = 'text' | 'html';

const props = defineProps<{
  modelValue: string;
  language: EditorLanguage;
  languageLabel: string;
}>();

const host = ref<HTMLDivElement | null>(null);
let editorView: EditorView | null = null;

const extensions = computed(() => {
  const base = [
    basicSetup,
    EditorState.readOnly.of(true),
    EditorView.editable.of(false),
    EditorView.lineWrapping,
    EditorView.theme({
      '&': {
        height: '100%',
        backgroundColor: 'transparent',
        color: '#475569',
        fontSize: '14px',
      },
      '.cm-scroller': {
        overflow: 'auto',
        fontFamily: "'SFMono-Regular', ui-monospace, monospace",
        lineHeight: '1.6',
      },
      '.cm-content': {
        padding: '16px',
      },
      '.cm-gutters': {
        backgroundColor: '#f1f5f9',
        color: '#94a3b8',
        border: 'none',
      },
      '.cm-activeLine': {
        backgroundColor: 'rgba(148, 163, 184, 0.1)',
      },
      '.cm-activeLineGutter': {
        backgroundColor: '#f1f5f9',
      },
      '.cm-selectionBackground, &.cm-focused .cm-selectionBackground': {
        backgroundColor: 'rgba(148, 163, 184, 0.2)',
      },
      '.cm-cursor, .cm-dropCursor': {
        borderLeftColor: '#64748b',
      },
      '.cm-panels': {
        backgroundColor: '#f8fafc',
        color: '#475569',
      },
    }),
  ];

  return props.language === 'html' ? [...base, html()] : base;
});

const mountEditor = () => {
  if (!host.value) return;

  editorView?.destroy();
  editorView = new EditorView({
    parent: host.value,
    state: EditorState.create({
      doc: props.modelValue,
      extensions: extensions.value,
    }),
  });
};

watch(() => [props.modelValue, props.language] as const, mountEditor);

onMounted(mountEditor);

onBeforeUnmount(() => {
  editorView?.destroy();
  editorView = null;
});
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
    <div ref="host" class="editor-host" />
  </section>
</template>

<style scoped>
.editor-shell {
  display: grid;
  grid-template-rows: auto 1fr;
  min-height: 0;
  border-radius: 8px;
  overflow: hidden;
  border: 1px solid #e2e8f0;
  background: #f8fafc;
}
.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 16px;
  background: #f1f5f9;
  color: #64748b;
  font-size: 13px;
  border-bottom: 1px solid #e2e8f0;
}
.traffic { display: inline-flex; gap: 6px; }
.traffic i {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  display: block;
}
.traffic i:nth-child(1) { background: #ef4444; }
.traffic i:nth-child(2) { background: #f59e0b; }
.traffic i:nth-child(3) { background: #10b981; }
.editor-host {
  min-height: 0;
  height: 100%;
}
:deep(.cm-editor) {
  height: 100%;
}
</style>
