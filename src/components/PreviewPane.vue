<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import CodeEditor from './CodeEditor.vue';
import { NSelect } from 'naive-ui';

type PreviewLanguage = 'plain' | 'html' | 'md' | 'json' | 'js' | 'ts' | 'xml';

interface ClipItem {
  id: string;
  title: string;
  preview: string;
  kind: 'text' | 'html' | 'image';
  text?: string | null;
  html?: string | null;
  image_data_url?: string | null;
}

const languageOptions: Array<{ value: PreviewLanguage; label: string }> = [
  { value: 'plain', label: 'Plain' },
  { value: 'html', label: 'HTML' },
  { value: 'md', label: 'Markdown' },
  { value: 'json', label: 'JSON' },
  { value: 'js', label: 'JavaScript' },
  { value: 'ts', label: 'TypeScript' },
  { value: 'xml', label: 'XML' },
];

const props = defineProps<{
  clip: ClipItem | null;
  allTags: string[];
  clipTags: string[];
}>();

const emit = defineEmits<{
  (e: 'add-tag', tag: string): void;
  (e: 'remove-tag', tag: string): void;
}>();

const selectedLanguage = ref<PreviewLanguage>('plain');
const formattedCode = ref('');
const toastMessage = ref('');
const showToast = ref(false);
const tagInput = ref('');

const showToastMessage = (message: string) => {
  toastMessage.value = message;
  showToast.value = true;
  setTimeout(() => {
    showToast.value = false;
    setTimeout(() => {
      toastMessage.value = '';
    }, 300);
  }, 2000);
};

const sourceCode = computed(() => {
  if (!props.clip) return '';
  if (props.clip.kind === 'html') return props.clip.html ?? '';
  if (props.clip.kind === 'text') return props.clip.text ?? '';
  return '';
});

const languageLabel = computed(() => languageOptions.find((item) => item.value === selectedLanguage.value)?.label ?? 'Plain');
const displayCode = computed(() => formattedCode.value || sourceCode.value);
const canOperateCode = computed(() => !!props.clip && props.clip.kind !== 'image');

watch(
  () => props.clip?.id,
  () => {
    toastMessage.value = '';
    showToast.value = false;
    formattedCode.value = '';
    selectedLanguage.value = 'plain';
    tagInput.value = '';
  },
  { immediate: true },
);

const submitTagInput = () => {
  const nextTag = tagInput.value.trim();
  if (!nextTag) return;
  emit('add-tag', nextTag);
  tagInput.value = '';
};

const formatCode = async () => {
  if (!canOperateCode.value) return;

  const code = sourceCode.value;
  if (!code.trim()) {
    formattedCode.value = '';
    showToastMessage('当前内容为空');
    return;
  }

  try {
    let result: string;
    
    if (selectedLanguage.value === 'plain') {
      result = code;
    } else {
      // 动态导入 Prettier 及其解析器
      const [prettier, parserBabel, parserEstree, parserHtml, parserMarkdown] = await Promise.all([
        import('prettier'),
        import('prettier/parser-babel'),
        import('prettier/plugins/estree'),
        import('prettier/parser-html'),
        import('prettier/parser-markdown')
      ]);
      
      switch (selectedLanguage.value) {
        case 'md':
          result = await prettier.default.format(code, {
            parser: 'markdown',
            plugins: [parserMarkdown.default],
            semi: true,
            singleQuote: true,
            tabWidth: 2,
            printWidth: 80
          });
          break;
        case 'json':
          result = await prettier.default.format(code, {
            parser: 'json',
            plugins: [parserBabel.default, parserEstree.default],
            semi: false,
            tabWidth: 2,
            printWidth: 80
          });
          break;
        case 'html':
          result = await prettier.default.format(code, {
            parser: 'html',
            plugins: [parserHtml.default],
            semi: true,
            singleQuote: true,
            tabWidth: 2,
            printWidth: 80
          });
          break;
        case 'xml':
          result = await prettier.default.format(code, {
            parser: 'html',
            plugins: [parserHtml.default],
            semi: true,
            singleQuote: true,
            tabWidth: 2,
            printWidth: 80
          });
          break;
        case 'js':
          result = await prettier.default.format(code, {
            parser: 'babel',
            plugins: [parserBabel.default, parserEstree.default],
            semi: true,
            singleQuote: true,
            tabWidth: 2,
            printWidth: 80
          });
          break;
        case 'ts':
          result = await prettier.default.format(code, {
            parser: 'typescript',
            plugins: [parserBabel.default, parserEstree.default],
            semi: true,
            singleQuote: true,
            tabWidth: 2,
            printWidth: 80
          });
          break;
        default:
          result = code;
      }
    }

    formattedCode.value = result;
    showToastMessage('格式化完成');
  } catch (error) {
    showToastMessage(error instanceof Error ? `格式化失败：${error.message}` : '格式化失败');
  }
};

const copyContent = async () => {
  if (!canOperateCode.value) return;

  try {
    await navigator.clipboard.writeText(displayCode.value);
    showToastMessage('已复制到剪贴板');
  } catch (error) {
    showToastMessage(error instanceof Error ? `复制失败：${error.message}` : '复制失败');
  }
};
</script>

<template>
  <section class="preview-panel">
    <div class="preview-toolbar">
      <div class="tag-input-wrap">
        <input
          v-model="tagInput"
          list="preview-tag-suggestions"
          type="text"
          placeholder="添加标签，例如：密码"
          :disabled="!clip"
          @keydown.enter.prevent="submitTagInput"
        />
        <button type="button" :disabled="!clip" @click="submitTagInput">添加</button>
        <datalist id="preview-tag-suggestions">
          <option v-for="tag in allTags" :key="tag" :value="tag" />
        </datalist>
      </div>
      <div class="tag-list">
        <button
          v-for="tag in clipTags"
          :key="tag"
          class="tag-chip"
          type="button"
          @click="emit('remove-tag', tag)"
        >
          {{ tag }} ×
        </button>
        <span v-if="clip && !clipTags.length" class="tag-empty">未添加标签</span>
      </div>
    </div>

    <template v-if="clip">
      <div v-if="clip.kind !== 'image'" class="code-container">
        <div class="code-controls">
          <div class="language-controls">
            <label>
              <span>语言</span>
              <NSelect
                v-model:value="selectedLanguage"
                class="language-select"
                :options="languageOptions"
              />
            </label>
          </div>
          <div class="action-buttons">
            <button type="button" @click="formatCode">格式化</button>
            <button type="button" @click="copyContent">复制</button>
          </div>
        </div>
        <CodeEditor
          :model-value="displayCode"
          :language="selectedLanguage"
          :language-label="languageLabel"
        />
      </div>
      <div v-else class="image-viewer">
        <img :src="clip.image_data_url ?? ''" alt="clipboard image" />
      </div>
    </template>

    <div v-else class="empty-state">
      未选中内容
    </div>

    <!-- 简单提示 -->
    <div v-if="toastMessage" class="toast" :class="{ 'show': showToast }">
      {{ toastMessage }}
    </div>
  </section>
</template>

<style scoped>
.preview-panel {
  padding: 8px;
  min-height: 0;
  position: relative;
  display: grid;
  grid-template-rows: auto 1fr;
  gap: 8px;
}

.preview-toolbar {
  display: grid;
  gap: 6px;
  border-bottom: 1px solid #e2e8f0;
  padding-bottom: 8px;
}

.tag-input-wrap {
  display: flex;
  align-items: center;
  gap: 6px;
}

.tag-input-wrap input {
  width: 240px;
  max-width: 100%;
  border: 1px solid #cbd5e1;
  border-radius: 4px;
  padding: 4px 8px;
  font-size: 12px;
}

.tag-input-wrap button {
  border: 1px solid #cbd5e1;
  background: #fff;
  border-radius: 4px;
  padding: 4px 10px;
  font-size: 12px;
  cursor: pointer;
}

.tag-input-wrap button:disabled,
.tag-input-wrap input:disabled {
  cursor: not-allowed;
  opacity: 0.6;
}

.tag-list {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 6px;
}

.tag-chip {
  border: none;
  background: #e2e8f0;
  color: #334155;
  border-radius: 999px;
  padding: 2px 8px;
  font-size: 11px;
  cursor: pointer;
}

.tag-empty {
  font-size: 12px;
  color: #94a3b8;
}

.code-container {
  display: flex;
  flex-direction: column;
  gap: 6px;
  min-height: 0;
  height: 100%;
}

.code-controls {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
  padding-bottom: 6px;
  border-bottom: 1px solid #e2e8f0;
}

.language-controls,
.action-buttons {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}

.code-controls label {
  display: flex;
  align-items: center;
  gap: 6px;
  color: #64748b;
  font-size: 12px;
}


.code-controls label span {
  white-space: nowrap;
}

:deep(.language-select) {
  width: 180px;
  min-width: 180px;
}

:deep(.language-select .n-base-selection-label__render-label) {
  max-width: none;
}

.code-controls select,
.code-controls button {
  border: 1px solid #cbd5e1;
  border-radius: 4px;
  background: #fff;
  color: #334155;
  padding: 4px 8px;
  font-size: 12px;
}

.code-controls button {
  cursor: pointer;
}

.image-viewer,
.empty-state {
  min-height: 0;
  height: 100%;
  border: 1px solid #e2e8f0;
  background: #fff;
}
.image-viewer {
  display: grid;
  place-items: center;
  overflow: hidden;
  padding: 8px;
}
.image-viewer img {
  max-width: 100%;
  max-height: 100%;
  object-fit: contain;
}
.empty-state {
  display: grid;
  place-items: center;
  color: #64748b;
  font-size: 12px;
}

.toast {
  position: absolute;
  bottom: 8px;
  right: 8px;
  background: rgba(15, 23, 42, 0.8);
  color: white;
  padding: 6px 12px;
  border-radius: 4px;
  font-size: 12px;
  opacity: 0;
  transform: translateY(20px);
  transition: all 0.3s ease;
  z-index: 1000;
}

.toast.show {
  opacity: 1;
  transform: translateY(0);
}
</style>
