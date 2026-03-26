
'use client';

import { useState } from 'react';
import { ConnectButton } from '@/components/ConnectButton';
import { ProtocolBalances } from '@/components/ProtocolBalances';
import { LiquidityPoolManager } from '@/components/LiquidityPoolManager';
import { FeeManager } from '@/components/FeeManager';
import Link from 'next/link';

export default function AdminPage() {
    const [selectedPoolToken, setSelectedPoolToken] = useState('USDC');

    return (
        <main className="min-h-screen p-6 text-white max-w-[1600px] mx-auto">
            {/* Header */}
            <header className="flex justify-between items-center mb-8 glass-panel p-4">
                <div className="flex items-center gap-3">
                    <Link href="/" className="hover:opacity-80 transition-opacity">
                        <div className="flex items-center gap-2">
                            <div className="w-8 h-8 rounded bg-gradient-to-r from-purple-500 to-cyan-500 flex items-center justify-center font-bold text-black">
                                E
                            </div>
                        </div>
                    </Link>
                    <h1 className="text-2xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-purple-400 to-cyan-400 tracking-wider border-l border-white/20 pl-4 ml-1">
                        ADMIN PANEL
                    </h1>
                </div>
                <div className="flex items-center gap-4">
                    <Link href="/" className="text-sm text-gray-400 hover:text-white transition-colors">
                        ← Back to Trading
                    </Link>
                    <ConnectButton />
                </div>
            </header>


            {/* Dashboard Grid */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 items-start">

                {/* Left Column: Balances & Trade */}
                <div className="space-y-6 w-full">
                    <LiquidityPoolManager
                        selectedTokenKey={selectedPoolToken}
                    />
                    <FeeManager />
                </div>

                {/* Right Column: Positions List */}
                <div className="lg:col-span-2 w-full">
                    <ProtocolBalances
                        selectedToken={selectedPoolToken}
                        onSelectToken={setSelectedPoolToken}
                    />
                </div>
            </div>


        </main>
    );
}
