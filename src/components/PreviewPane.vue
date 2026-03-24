<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import CodeEditor from './CodeEditor.vue';

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
const formatStatus = ref('');

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
    formatStatus.value = '';
    formattedCode.value = '';
    selectedLanguage.value = props.clip?.kind === 'html' ? 'html' : 'plain';
  },
  { immediate: true },
);

const formatMarkup = (code: string) => {
  const normalized = code
    .replace(/>\s+</g, '><')
    .replace(/\n+/g, '')
    .trim();

  let indent = 0;
  const lines: string[] = [];
  
  // 按标签分割，保留标签和内容
  const parts = normalized.split(/(<[^>]+>)/g).filter(Boolean);
  
  for (const part of parts) {
    if (part.startsWith('<')) {
      // 处理标签
      if (part.startsWith('</')) {
        // 结束标签，先减少缩进
        indent = Math.max(indent - 1, 0);
        lines.push(`${'  '.repeat(indent)}${part}`);
      } else if (part.endsWith('/>')) {
        // 自闭合标签，保持缩进
        lines.push(`${'  '.repeat(indent)}${part}`);
      } else {
        // 开始标签，先添加，再增加缩进
        lines.push(`${'  '.repeat(indent)}${part}`);
        indent += 1;
      }
    } else {
      // 处理内容，保持当前缩进
      const content = part.trim();
      if (content) {
        lines.push(`${'  '.repeat(indent)}${content}`);
      }
    }
  }
  
  return lines.join('\n');
};

const formatJsLike = (code: string) => {
  let indent = 0;
  return code
    .split('\n')
    .map((rawLine) => rawLine.trim())
    .filter((line) => line.length > 0)
    .map((line) => {
      if (/^[}\])]/.test(line)) indent = Math.max(indent - 1, 0);
      const formatted = `${'  '.repeat(indent)}${line}`;
      const opens = (line.match(/[\[{(]/g) ?? []).length;
      const closes = (line.match(/[\]})]/g) ?? []).length;
      indent = Math.max(indent + opens - closes, 0);
      return formatted;
    })
    .join('\n');
};

const formatCode = async () => {
  if (!canOperateCode.value) return;

  const code = sourceCode.value;
  if (!code.trim()) {
    formattedCode.value = '';
    formatStatus.value = '当前内容为空';
    return;
  }

  try {
    switch (selectedLanguage.value) {
      case 'plain':
      case 'md':
        formattedCode.value = code;
        break;
      case 'json':
        formattedCode.value = JSON.stringify(JSON.parse(code), null, 2);
        break;
      case 'html':
      case 'xml':
        formattedCode.value = formatMarkup(code);
        break;
      case 'js':
      case 'ts':
        formattedCode.value = formatJsLike(code);
        break;
    }

    formatStatus.value = '格式化完成';
  } catch (error) {
    formatStatus.value = error instanceof Error ? `格式化失败：${error.message}` : '格式化失败';
  }
};

const copyContent = async () => {
  if (!canOperateCode.value) return;

  try {
    await navigator.clipboard.writeText(displayCode.value);
    formatStatus.value = '已复制到剪贴板';
  } catch (error) {
    formatStatus.value = error instanceof Error ? `复制失败：${error.message}` : '复制失败';
  }
};
</script>

<template>
  <section class="preview-panel">
    <template v-if="clip">
      <header class="header">
        <h2>{{ clip.title }}</h2>
        <div v-if="canOperateCode" class="controls">
          <label>
            <span>语言</span>
            <select v-model="selectedLanguage">
              <option v-for="option in languageOptions" :key="option.value" :value="option.value">{{ option.label }}</option>
            </select>
          </label>
          <button type="button" @click="formatCode">格式化</button>
          <button type="button" @click="copyContent">复制</button>
        </div>
      </header>

      <CodeEditor
        v-if="clip.kind !== 'image'"
        :model-value="displayCode"
        :language="selectedLanguage"
        :language-label="languageLabel"
      />
      <div v-else class="image-viewer">
        <img :src="clip.image_data_url ?? ''" alt="clipboard image" />
      </div>

      <p v-if="formatStatus" class="status">{{ formatStatus }}</p>
    </template>

    <div v-else class="empty-state">
      未选中内容
    </div>
  </section>
</template>

<style scoped>
.preview-panel {
  padding: 14px;
  display: grid;
  grid-template-rows: auto 1fr auto;
  gap: 12px;
  min-height: 0;
}
.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
}
.header h2 { margin: 0; font-size: 18px; font-weight: 600; color: #1e293b; }
.controls {
  display: flex;
  align-items: center;
  gap: 8px;
}
.controls label {
  display: flex;
  align-items: center;
  gap: 6px;
  color: #64748b;
  font-size: 13px;
}
.controls select,
.controls button {
  border: 1px solid #cbd5e1;
  border-radius: 8px;
  background: #fff;
  color: #334155;
  padding: 6px 10px;
}
.controls button {
  cursor: pointer;
}
.controls button:hover {
  background: #f8fafc;
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
.status {
  margin: 0;
  color: #64748b;
  font-size: 13px;
}
</style>
