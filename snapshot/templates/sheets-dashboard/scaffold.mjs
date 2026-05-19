#!/usr/bin/env node

/**
 * sheets-dashboard scaffold script
 *
 * 사용법:
 *   node scaffold.mjs --config ./config.json --out /path/to/project
 *
 * config.json 예시:
 * {
 *   "projectName": "38-stock-issue-list",
 *   "pageTitle": "품절 / 입고예정 안내",
 *   "pageDescription": "품절 현황, 입고 예정 정보를 제공하는 대시보드",
 *   "sheetId": "1PDQSta...",
 *   "sheetTabName": "재고이슈리스트",
 *   "dataStartRow": 3,
 *   "columns": {
 *     "productName": { "index": 1, "label": "상품명" },
 *     "restockDate": { "index": 3, "label": "입고 예정일" }
 *   },
 *   "allColumns": {
 *     "ezCode": { "index": 0, "label": "EZ코드" },
 *     "productName": { "index": 1, "label": "상품명" },
 *     "status": { "index": 2, "label": "현 상황" },
 *     "restockDate": { "index": 3, "label": "입고예정" },
 *     "remarks": { "index": 4, "label": "비고" }
 *   },
 *   "lastColumn": "E",
 *   "serviceAccountEmail": "xxx@xxx.iam.gserviceaccount.com"
 * }
 */

import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

// ── CLI 인자 파싱 ──
const args = process.argv.slice(2)
let configPath = null
let outDir = null

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--config' && args[i + 1]) configPath = args[++i]
  if (args[i] === '--out' && args[i + 1]) outDir = args[++i]
}

if (!configPath || !outDir) {
  console.error('Usage: node scaffold.mjs --config ./config.json --out /path/to/project')
  process.exit(1)
}

const config = JSON.parse(fs.readFileSync(configPath, 'utf8'))

// ── 유틸 ──
function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true })
}

function writeFile(relPath, content) {
  const fullPath = path.join(outDir, relPath)
  ensureDir(path.dirname(fullPath))
  fs.writeFileSync(fullPath, content, 'utf8')
  console.log(`  ✓ ${relPath}`)
}

function copyTemplate(relPath) {
  const src = path.join(__dirname, relPath)
  const content = fs.readFileSync(src, 'utf8')
  const replaced = content
    .replace(/\{\{PAGE_TITLE\}\}/g, config.pageTitle)
    .replace(/\{\{PAGE_DESCRIPTION\}\}/g, config.pageDescription || config.pageTitle)
  writeFile(relPath, replaced)
}

// ── 생성 시작 ──
console.log(`\n🔧 Scaffolding: ${config.projectName}`)
console.log(`   Target: ${outDir}\n`)

// 1. 템플릿에서 고정 파일 복사 (치환 포함)
copyTemplate('app/layout.tsx')
copyTemplate('app/api/sheet-data/route.ts')
copyTemplate('hooks/use-sheet-data.ts')
copyTemplate('lib/google-sheets.ts')

// 2. 동적 생성: column-config.ts
const columnMapEntries = Object.entries(config.allColumns)
  .map(([key, col]) => {
    const pad = ' '.repeat(Math.max(0, 20 - key.length))
    const colLetter = String.fromCharCode(65 + col.index)
    return `    ${key}: ${col.index},${pad}// ${colLetter}열: ${col.label}`
  })
  .join('\n')

writeFile('lib/column-config.ts', `// 컬럼 매핑 설정
// 시트 구조 변경 시 이 파일만 수정하면 됩니다.

export const SHEET_CONFIG = {
  tabName: '${config.sheetTabName}',
  dataStartRow: ${config.dataStartRow},
  range: '${config.sheetTabName}!A${config.dataStartRow}:${config.lastColumn}',
  columnMap: {
${columnMapEntries}
  },
} as const
`)

// 3. 동적 생성: types.ts
const recordFields = Object.entries(config.allColumns)
  .map(([key, col]) => {
    const pad = ' '.repeat(Math.max(0, 20 - key.length))
    return `  ${key}: string${pad}// ${col.label}`
  })
  .join('\n')

const displayFields = Object.entries(config.columns)
  .map(([key, col]) => {
    const pad = ' '.repeat(Math.max(0, 20 - key.length))
    return `  ${key}: string${pad}// ${col.label}`
  })
  .join('\n')

writeFile('lib/types.ts', `// 시트 원본 레코드
export interface SheetRecord {
${recordFields}
}

// 화면 표시용 아이템
export interface DisplayItem {
${displayFields}
}

// API 응답
export interface SheetDataResponse {
  items: DisplayItem[]
  lastUpdated: string
}
`)

// 4. 동적 생성: data-utils.ts
const transformFields = Object.entries(config.columns)
  .map(([key]) => `      ${key}: r.${key}`)
  .join(',\n')

const filterCondition = Object.keys(config.columns)
  .map(k => `(r.${k} && r.${k}.trim().length > 0)`)
  .join(' || ')

writeFile('lib/data-utils.ts', `import type { SheetRecord, DisplayItem } from './types'

export function transformRecords(records: SheetRecord[]): DisplayItem[] {
  return records
    .filter(r => {
      // 최소 1개 표시 컬럼에 값이 있어야 함
      return ${filterCondition}
    })
    .map((r): DisplayItem => ({
${transformFields}
    }))
}
`)

// 5. 동적 생성: page.tsx
const tableHeaders = Object.entries(config.columns)
  .map(([, col], i) => {
    const align = i === 0 ? 'text-left' : 'text-right'
    const width = i === 0 ? '' : ' w-[140px]'
    return `                <th className="${align} py-2.5 px-4 font-medium text-gray-600${width}">${col.label}</th>`
  })
  .join('\n')

const tableCells = Object.entries(config.columns)
  .map(([key], i) => {
    const align = i === 0 ? 'text-gray-900' : 'text-right text-gray-500'
    const fallback = i === 0 ? '' : ` || '미정'`
    return `                  <td className="py-2.5 px-4 ${align}">{item.${key}${fallback}}</td>`
  })
  .join('\n')

writeFile('app/page.tsx', `'use client'

import { useSheetData } from '@/hooks/use-sheet-data'

export default function MainPage() {
  const { data, loading, error } = useSheetData()

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen text-gray-400 text-sm">
        불러오는 중...
      </div>
    )
  }

  if (error || !data) {
    return (
      <div className="flex items-center justify-center h-screen text-red-500 text-sm">
        데이터 로드 실패
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-white">
      <div className="max-w-2xl mx-auto px-4 py-8">
        <h1 className="text-lg font-bold text-gray-900 mb-1">${config.pageTitle}</h1>
        <p className="text-xs text-gray-400 mb-6">
          {new Date(data.lastUpdated).toLocaleDateString('ko-KR')} 기준
        </p>

        <div className="border rounded-lg overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-gray-50 border-b">
${tableHeaders}
              </tr>
            </thead>
            <tbody>
              {data.items.map((item, idx) => (
                <tr key={idx} className="border-b last:border-b-0 hover:bg-gray-50/50">
${tableCells}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
`)

// 6. .env.local
writeFile('.env.local', `GOOGLE_SERVICE_ACCOUNT_EMAIL=${config.serviceAccountEmail}
GOOGLE_PRIVATE_KEY="{{PRIVATE_KEY_HERE}}"
GOOGLE_SHEET_ID=${config.sheetId}
`)

console.log(`\n✅ Scaffold 완료!`)
console.log(`\n📋 다음 단계:`)
console.log(`   1. .env.local 에서 GOOGLE_PRIVATE_KEY 값을 입력하세요`)
console.log(`   2. npm install googleapis`)
console.log(`   3. npm run build`)
console.log(`   4. npm run dev\n`)
