<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { Compartment, EditorState, Extension } from '@codemirror/state';
import { Decoration, EditorView, MatchDecorator, ViewPlugin } from '@codemirror/view';
import { basicSetup } from 'codemirror';
import { html } from '@codemirror/lang-html';
import { javascript } from '@codemirror/lang-javascript';

type EditorLanguage = 'plain' | 'html' | 'md' | 'json' | 'js' | 'ts' | 'xml';

const props = defineProps<{
  modelValue: string;
  language: EditorLanguage;
  languageLabel: string;
}>();

const host = ref<HTMLDivElement | null>(null);
let editorView: EditorView | null = null;
const languageCompartment = new Compartment();

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
  json: [],
  js: [],
  ts: [],
};

const languageExtension = computed<Extension[]>(() => {
  if (props.language === 'html' || props.language === 'xml') {
    return [html()];
  }

  if (props.language === 'js') {
    return [javascript()];
  }

  if (props.language === 'ts') {
    return [javascript({ typescript: true })];
  }

  if (props.language === 'json') {
    return [javascript()];
  }

  return regexHighlightExtensions[props.language] ?? [];
});

const extensions = computed(() => [
  basicSetup,
  languageCompartment.of(languageExtension.value),
  EditorState.readOnly.of(true),
  EditorView.editable.of(false),
  EditorView.lineWrapping,
]);

const mountEditor = () => {
  if (!host.value || editorView) return;

  editorView = new EditorView({
    parent: host.value,
    state: EditorState.create({
      doc: props.modelValue,
      extensions: extensions.value,
    }),
  });
};

watch(
  () => props.modelValue,
  (nextValue) => {
    if (!editorView) return;
    const currentValue = editorView.state.doc.toString();
    if (currentValue === nextValue) return;
    editorView.dispatch({
      changes: {
        from: 0,
        to: editorView.state.doc.length,
        insert: nextValue,
      },
    });
  },
);

watch(
  () => props.language,
  () => {
    if (!editorView) return;
    editorView.dispatch({
      effects: languageCompartment.reconfigure(languageExtension.value),
    });
  },
);

onMounted(mountEditor);

onBeforeUnmount(() => {
  editorView?.destroy();
  editorView = null;
});
</script>

<template>
  <section class="editor-shell">
    <div class="toolbar">
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
  justify-content: space-between;
  align-items: center;
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

:deep(.cm-token-keyword) {
  color: #7c3aed;
  font-weight: 600;
}

:deep(.cm-token-string) {
  color: #0f766e;
}

:deep(.cm-token-number) {
  color: #b45309;
}

:deep(.cm-token-comment) {
  color: #64748b;
  font-style: italic;
}

:deep(.cm-token-property) {
  color: #0369a1;
}

:deep(.cm-token-type) {
  color: #0d9488;
}

:deep(.cm-token-heading) {
  color: #1d4ed8;
  font-weight: 700;
}

:deep(.cm-token-link) {
  color: #2563eb;
  text-decoration: underline;
}
</style>
