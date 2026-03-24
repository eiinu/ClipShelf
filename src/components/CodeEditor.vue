<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { EditorState, Extension } from '@codemirror/state';
import { Decoration, EditorView, MatchDecorator, ViewPlugin } from '@codemirror/view';
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

const buildTokenDecorator = (regexp: RegExp, className: string): Extension => {
  const matcher = new MatchDecorator({
    regexp,
    decoration: () => Decoration.mark({ class: className }),
  });

  const plugin = ViewPlugin.fromClass(
    class {
      decorations;

      constructor(view: EditorView) {
        this.decorations = matcher.createDeco(view);
      }

      update(update: Parameters<(typeof matcher)['updateDeco']>[0]) {
        this.decorations = matcher.updateDeco(update, this.decorations);
      }
    },
    {
      decorations: (view) => view.decorations,
    },
  );

  return [plugin];
};

const regexHighlightExtensions: Record<EditorLanguage, Extension[]> = {
  plain: [],
  html: [],
  xml: [],
  md: [
    buildTokenDecorator(/^#{1,6}.+$/gm, 'cm-token-heading'),
    buildTokenDecorator(/`[^`]+`/g, 'cm-token-string'),
    buildTokenDecorator(/\*\*[^*]+\*\*/g, 'cm-token-keyword'),
    buildTokenDecorator(/\[[^\]]+\]\([^\)]+\)/g, 'cm-token-link'),
  ],
  json: [
    buildTokenDecorator(/"(?:\\.|[^"\\])*"(?=\s*:)/g, 'cm-token-property'),
    buildTokenDecorator(/"(?:\\.|[^"\\])*"/g, 'cm-token-string'),
    buildTokenDecorator(/\b(?:true|false|null)\b/g, 'cm-token-keyword'),
    buildTokenDecorator(/-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b/g, 'cm-token-number'),
  ],
  js: [
    buildTokenDecorator(/\b(?:const|let|var|function|return|if|else|for|while|switch|case|break|class|new|import|from|export|default|await|async|try|catch|throw)\b/g, 'cm-token-keyword'),
    buildTokenDecorator(/"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`/g, 'cm-token-string'),
    buildTokenDecorator(/\b\d+(?:\.\d+)?\b/g, 'cm-token-number'),
    buildTokenDecorator(/\/[/*][\s\S]*?(?:\*\/|$)|\/\/.*$/gm, 'cm-token-comment'),
  ],
  ts: [
    buildTokenDecorator(/\b(?:const|let|var|function|return|if|else|for|while|switch|case|break|class|new|import|from|export|default|await|async|try|catch|throw|interface|type|implements|enum|readonly|public|private|protected)\b/g, 'cm-token-keyword'),
    buildTokenDecorator(/\b(?:string|number|boolean|unknown|never|void|any)\b/g, 'cm-token-type'),
    buildTokenDecorator(/"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`/g, 'cm-token-string'),
    buildTokenDecorator(/\b\d+(?:\.\d+)?\b/g, 'cm-token-number'),
    buildTokenDecorator(/\/[/*][\s\S]*?(?:\*\/|$)|\/\/.*$/gm, 'cm-token-comment'),
  ],
};

const languageExtension = computed<Extension[]>(() => {
  if (props.language === 'html' || props.language === 'xml') {
    return [html()];
  }

  return regexHighlightExtensions[props.language] ?? [];
});

const extensions = computed(() => [
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
    '.cm-token-keyword': { color: '#7c3aed', fontWeight: '600' },
    '.cm-token-string': { color: '#0f766e' },
    '.cm-token-number': { color: '#b45309' },
    '.cm-token-comment': { color: '#64748b', fontStyle: 'italic' },
    '.cm-token-property': { color: '#0369a1' },
    '.cm-token-type': { color: '#0d9488' },
    '.cm-token-heading': { color: '#1d4ed8', fontWeight: '700' },
    '.cm-token-link': { color: '#2563eb', textDecoration: 'underline' },
  }),
  ...languageExtension.value,
]);

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
