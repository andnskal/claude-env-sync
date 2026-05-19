'use client'

import { useState, useEffect } from 'react'
import type { SheetDataResponse } from '@/lib/types'

export function useSheetData() {
  const [data, setData] = useState<SheetDataResponse | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    async function fetchData() {
      try {
        setLoading(true)
        const res = await fetch('/api/sheet-data')
        if (!res.ok) throw new Error(`HTTP ${res.status}`)
        const json: SheetDataResponse = await res.json()
        setData(json)
        setError(null)
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Unknown error')
      } finally {
        setLoading(false)
      }
    }
    fetchData()
  }, [])

  return { data, loading, error }
}
