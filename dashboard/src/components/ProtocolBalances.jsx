
import { useEffect, useState } from 'react';
import { useDeFi } from '../hooks/useDeFi';

const TOKENS = [
    { key: 'WETH', name: 'WETH' },
    { key: 'DAI', name: 'DAI' },
    { key: 'USDC', name: 'USDC' },
    { key: 'WBTC', name: 'WBTC' },
];

export function ProtocolBalances({ onSelectToken, selectedToken }) {
    const { getProtocolBalances } = useDeFi();
    const [data, setData] = useState(null);
    const [loading, setLoading] = useState(false);

    const fetchData = async () => {
        setLoading(true);
        const res = await getProtocolBalances();
        if (res) setData(res);
        setLoading(false);
    };

    useEffect(() => {
        fetchData();
        const interval = setInterval(fetchData, 30000);
        return () => clearInterval(interval);
    }, [getProtocolBalances]);

    return (
        <div className="glass-panel p-4 w-full h-full flex flex-col">
            <div className="flex justify-between items-center mb-4">
                <h2 className="text-sm font-bold text-gray-400 uppercase tracking-widest">
                    Protocol Health
                </h2>
                <button
                    onClick={fetchData}
                    className="text-xs text-gray-500 hover:text-white transition-colors"
                >
                    {loading ? '...' : 'Refresh'}
                </button>
            </div>

            <div className="grid grid-cols-1 gap-3 flex-1 overflow-y-auto">
                {TOKENS.map(t => {
                    const posBal = data?.positionsBalances?.[t.key];
                    const pool = data?.poolBalances?.[t.key];
                    const isSelected = selectedToken === t.key;

                    return (
                        <div
                            key={t.key}
                            onClick={() => onSelectToken(t.key)}
                            className={`rounded-lg p-3 border cursor-pointer transition-all hover:bg-white/10 ${isSelected
                                    ? 'bg-white/10 border-yellow-500/50 shadow-[0_0_15px_rgba(234,179,8,0.1)]'
                                    : 'bg-white/5 border-white/5'
                                }`}
                        >
                            <div className="flex justify-between items-center border-b border-white/5 pb-1 mb-2">
                                <span className={`font-bold ${isSelected ? 'text-yellow-400' : 'text-gray-300'}`}>{t.name}</span>
                                {isSelected && <span className="text-[10px] bg-yellow-500/20 text-yellow-500 px-2 py-0.5 rounded">SELECTED</span>}
                            </div>

                            {/* Position Contract */}
                            <div className="flex justify-between text-xs mb-1">
                                <span className="text-gray-500">Positions:</span>
                                <span className="font-mono text-gray-300">
                                    {posBal ? `${Number(posBal.balance).toFixed(2)}` : '-'}
                                </span>
                            </div>

                            {/* Pool TVL */}
                            <div className="flex justify-between text-xs">
                                <span className="text-gray-500">Pool TVL:</span>
                                <span className="font-mono text-gray-300">
                                    {pool ? `${Number(pool.totalAssets).toFixed(2)}` : '-'}
                                </span>
                            </div>
                        </div>
                    )
                })}
            </div>
        </div>
    );
}
