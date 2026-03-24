<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { EditorState } from '@codemirror/state';
import { EditorView } from '@codemirror/view';
import { basicSetup } from 'codemirror';
import { html } from '@codemirror/lang-html';

type EditorLanguage = 'plain' | 'html' | 'md' | 'json' | 'js' | 'ts' | 'xml';

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
        padding: '14px',
      },
      '.cm-gutters': {
        backgroundColor: '#f1f5f9',
        color: '#94a3b8',
        border: 'none',
      },
    }),
  ];

  return props.language === 'html' || props.language === 'xml' ? [...base, html()] : base;
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
    <div class="toolbar">{{ languageLabel }}</div>
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
  padding: 8px 12px;
  background: #f1f5f9;
  color: #64748b;
  font-size: 13px;
  border-bottom: 1px solid #e2e8f0;
}
.editor-host {
  min-height: 0;
  height: 100%;
}
:deep(.cm-editor) {
  height: 100%;
}
</style>
