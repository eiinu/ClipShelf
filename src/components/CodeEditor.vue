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
        color: '#e2e8f0',
        fontSize: '14px',
      },
      '.cm-scroller': {
        overflow: 'auto',
        fontFamily: "'SFMono-Regular', ui-monospace, monospace",
        lineHeight: '1.6',
      },
      '.cm-content': {
        padding: '18px',
      },
      '.cm-gutters': {
        backgroundColor: 'rgba(15, 23, 42, 0.78)',
        color: '#64748b',
        border: 'none',
      },
      '.cm-activeLine': {
        backgroundColor: 'rgba(59, 130, 246, 0.08)',
      },
      '.cm-activeLineGutter': {
        backgroundColor: 'transparent',
      },
      '.cm-selectionBackground, &.cm-focused .cm-selectionBackground': {
        backgroundColor: 'rgba(96, 165, 250, 0.24)',
      },
      '.cm-cursor, .cm-dropCursor': {
        borderLeftColor: '#93c5fd',
      },
      '.cm-panels': {
        backgroundColor: 'rgba(15, 23, 42, 0.94)',
        color: '#cbd5e1',
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
.editor-host {
  min-height: 0;
  height: 100%;
}
:deep(.cm-editor) {
  height: 100%;
}
</style>
