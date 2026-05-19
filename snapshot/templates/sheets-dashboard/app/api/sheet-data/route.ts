import { fetchSheetData } from '@/lib/google-sheets'
import { transformRecords } from '@/lib/data-utils'

export const revalidate = 300 // ISR 5분

export async function GET() {
  try {
    const records = await fetchSheetData()
    const items = transformRecords(records)

    return Response.json({
      items,
      lastUpdated: new Date().toISOString(),
    })
  } catch (error) {
    console.error('Failed to fetch sheet data:', error)
    return Response.json(
      { error: 'Failed to fetch sheet data' },
      { status: 500 }
    )
  }
}
