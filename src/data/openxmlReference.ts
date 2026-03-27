export interface OpenXmlEntry {
  id: string;
  label: string;
  category: 'WordprocessingML' | 'SpreadsheetML' | 'PresentationML' | 'DrawingML' | 'Packaging';
  path: string;
  description: string;
  attributes: string[];
  tags: string[];
}

export const OPENXML_REFERENCE: OpenXmlEntry[] = [
  {
    id: 'w-p',
    label: '<w:p>',
    category: 'WordprocessingML',
    path: '/word/document.xml',
    description: '段落节点，是 Word 文档正文最常见的容器元素。',
    attributes: ['w:rsidR', 'w:rsidRDefault', 'w14:paraId'],
    tags: ['paragraph', '文本段落', 'docx', 'word'],
  },
  {
    id: 'w-r',
    label: '<w:r>',
    category: 'WordprocessingML',
    path: '/word/document.xml',
    description: 'Run（文本片段），用于承载同一格式的连续文本。',
    attributes: ['w:rsidRPr'],
    tags: ['run', '文本片段', '格式', 'docx'],
  },
  {
    id: 'w-t',
    label: '<w:t>',
    category: 'WordprocessingML',
    path: '/word/document.xml',
    description: '纯文本节点，通常位于 <w:r> 内部。',
    attributes: ['xml:space'],
    tags: ['text', '字符串', 'docx'],
  },
  {
    id: 'w-tbl',
    label: '<w:tbl>',
    category: 'WordprocessingML',
    path: '/word/document.xml',
    description: 'Word 表格根元素，包含行 <w:tr> 与单元格 <w:tc>。',
    attributes: ['w:tblStyle', 'w:tblW'],
    tags: ['table', '表格', 'docx'],
  },
  {
    id: 'a-blip',
    label: '<a:blip>',
    category: 'DrawingML',
    path: '/word/media/* 或 /ppt/media/*',
    description: '图片引用节点，通常通过 r:embed 关联到关系文件中的资源。',
    attributes: ['r:embed', 'cstate'],
    tags: ['image', '图片', 'drawingml', 'docx', 'pptx'],
  },
  {
    id: 'x-c',
    label: '<c>',
    category: 'SpreadsheetML',
    path: '/xl/worksheets/sheet*.xml',
    description: 'Excel 单元格节点，v/is/f 子元素分别表示值、富文本、公式。',
    attributes: ['r', 's', 't'],
    tags: ['cell', '单元格', 'xlsx', 'excel'],
  },
  {
    id: 'x-row',
    label: '<row>',
    category: 'SpreadsheetML',
    path: '/xl/worksheets/sheet*.xml',
    description: '工作表行节点，内部包含多个 <c> 单元格。',
    attributes: ['r', 'spans', 'ht', 'customHeight'],
    tags: ['row', '行', 'xlsx', 'excel'],
  },
  {
    id: 'p-sld',
    label: '<p:sld>',
    category: 'PresentationML',
    path: '/ppt/slides/slide*.xml',
    description: 'PPT 单页幻灯片根元素。',
    attributes: ['show', 'showMasterSp'],
    tags: ['slide', '幻灯片', 'pptx'],
  },
  {
    id: 'p-sp',
    label: '<p:sp>',
    category: 'PresentationML',
    path: '/ppt/slides/slide*.xml',
    description: 'PPT 形状元素，可表示文本框、占位符、图形等对象。',
    attributes: ['useBgFill'],
    tags: ['shape', '文本框', '对象', 'pptx'],
  },
  {
    id: 'rels-relationship',
    label: '<Relationship>',
    category: 'Packaging',
    path: '/_rels/.rels 与 */_rels/*.rels',
    description: 'OPC 关系项，使用 Id / Type / Target 描述部件之间的引用关系。',
    attributes: ['Id', 'Type', 'Target', 'TargetMode'],
    tags: ['relationship', 'opc', 'rels', 'packaging'],
  },
];
