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
}>();

const selectedLanguage = ref<PreviewLanguage>('plain');
const formattedCode = ref('');
const toastMessage = ref('');
const showToast = ref(false);

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
    selectedLanguage.value = props.clip?.kind === 'html' ? 'html' : 'plain';
  },
  { immediate: true },
);

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
      const [prettier, parserBabel, parserHtml, parserMarkdown] = await Promise.all([
        import('prettier'),
        import('prettier/parser-babel'),
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
            plugins: [parserBabel.default],
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
            plugins: [parserBabel.default],
            semi: true,
            singleQuote: true,
            tabWidth: 2,
            printWidth: 80
          });
          break;
        case 'ts':
          result = await prettier.default.format(code, {
            parser: 'typescript',
            plugins: [parserBabel.default],
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
    <template v-if="clip">
      <div v-if="clip.kind !== 'image'" class="code-container">
        <div class="code-controls">
          <label>
            <span>语言</span>
            <NSelect v-model:value="selectedLanguage" :options="languageOptions" />
          </label>
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
  padding: 14px;
  display: grid;
  grid-template-rows: 1fr;
  min-height: 0;
  position: relative;
}

.code-container {
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-height: 0;
}

.code-controls {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
  padding: 8px 0;
}

.code-controls label {
  display: flex;
  align-items: center;
  gap: 6px;
  color: #64748b;
  font-size: 13px;
}

.code-controls select,
.code-controls button {
  border: 1px solid #cbd5e1;
  border-radius: 8px;
  background: #fff;
  color: #334155;
  padding: 6px 10px;
}

.code-controls button {
  cursor: pointer;
}

.code-controls button:hover {
  background: #f8fafc;
}

.action-buttons {
  display: flex;
  align-items: center;
  gap: 8px;
}
.image-viewer,
.empty-state {
  min-height: 0;
  border-radius: 8px;
  border: 1px solid #e2e8f0;
  background: #f8fafc;
}
.image-viewer {
  display: grid;
  place-items: center;
  overflow: hidden;
  padding: 16px;
}
.image-viewer img {
  max-width: 100%;
  max-height: 100%;
  object-fit: contain;
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}
.empty-state {
  display: grid;
  place-items: center;
  color: #64748b;
  font-size: 14px;
  padding: 16px;
}

/* Toast提示样式 */
.toast {
  position: absolute;
  bottom: 14px;
  right: 14px;
  background: rgba(15, 23, 42, 0.8);
  color: white;
  padding: 8px 16px;
  border-radius: 8px;
  font-size: 13px;
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
