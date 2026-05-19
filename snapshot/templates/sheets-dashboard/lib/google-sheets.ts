import { google } from 'googleapis'
import { SHEET_CONFIG } from './column-config'
import type { SheetRecord } from './types'

function getAuth() {
  return new google.auth.GoogleAuth({
    credentials: {
      client_email: process.env.GOOGLE_SERVICE_ACCOUNT_EMAIL,
      private_key: process.env.GOOGLE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    },
    scopes: ['https://www.googleapis.com/auth/spreadsheets.readonly'],
  })
}

export async function fetchSheetData(): Promise<SheetRecord[]> {
  const auth = getAuth()
  const sheets = google.sheets({ version: 'v4', auth })

  const response = await sheets.spreadsheets.values.get({
    spreadsheetId: process.env.GOOGLE_SHEET_ID,
    range: SHEET_CONFIG.range,
  })

  const rows = response.data.values || []

  return rows
    .map((row): SheetRecord | null => {
      const hasData = row.some((cell: string) => (cell || '').toString().trim().length > 0)
      if (!hasData) return null

      const record: Record<string, string> = {}
      for (const [key, colIndex] of Object.entries(SHEET_CONFIG.columnMap)) {
        record[key] = (row[colIndex as number] || '').toString().trim()
      }
      return record as unknown as SheetRecord
    })
    .filter((r): r is SheetRecord => r !== null)
}
