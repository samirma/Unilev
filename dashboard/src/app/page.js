
'use client';

import { ConnectButton } from '@/components/ConnectButton';
import { Balances } from '@/components/Balances';
import { TradeForm } from '@/components/TradeForm';
import { PositionsList } from '@/components/PositionsList';
import Link from 'next/link';

export default function Home() {
    return (
        <main className="min-h-screen p-6 text-white max-w-[1600px] mx-auto">
            {/* Header */}
            <header className="flex justify-between items-center mb-8 glass-panel p-4">
                <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded bg-gradient-to-r from-purple-500 to-cyan-500 flex items-center justify-center font-bold text-black">
                        E
                    </div>
                    <h1 className="text-2xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-purple-400 to-cyan-400 tracking-wider">
                        ESWAP
                    </h1>
                </div>

                <div className="flex items-center gap-4">
                    <Link
                        href="/admin"
                        className="text-xs bg-white/5 hover:bg-white/10 px-3 py-1.5 rounded border border-white/10 text-gray-400 hover:text-white transition-all uppercase tracking-widest font-bold"
                    >
                        Admin Panel
                    </Link>
                    <ConnectButton />
                </div>
            </header>

            {/* Dashboard Grid */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 items-start">

                {/* Left Column: Balances & Trade */}
                <div className="space-y-6 w-full">
                    <Balances />
                    <TradeForm />
                </div>

                {/* Right Column: Positions List */}
                <div className="lg:col-span-2 w-full">
                    <PositionsList />
                </div>
            </div>

        </main>
    );
}
