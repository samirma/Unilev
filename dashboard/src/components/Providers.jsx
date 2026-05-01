'use client'

import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useState } from 'react'
import { WagmiProvider } from 'wagmi'
import { config } from '../utils/wagmi'
import { AdminProvider } from '../contexts/AdminContext'

export function Providers({ children }) {
    const [queryClient] = useState(() => new QueryClient())

    return (
        <WagmiProvider config={config}>
            <QueryClientProvider client={queryClient}>
                <AdminProvider>
                    {children}
                </AdminProvider>
            </QueryClientProvider>
        </WagmiProvider>
    )
}
