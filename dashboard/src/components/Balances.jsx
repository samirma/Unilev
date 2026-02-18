
import { useState, useEffect } from 'react';
import { useDeFi } from '../hooks/useDeFi';
import { useAccount } from 'wagmi';

const TOKENS = [
    { key: 'native', name: 'ETH' },
    { key: 'WETH', name: 'WETH' },
    { key: 'DAI', name: 'DAI' },
    { key: 'USDC', name: 'USDC' },
    { key: 'WBTC', name: 'WBTC' },
];

export function Balances() {
    const { isConnected, address } = useAccount();
    const { getTokenBalance, getNativeBalance, ADDRESSES } = useDeFi();
    const [balances, setBalances] = useState({});

    // Initial state with zeroes/dashes to prevent layout shift
    const [loading, setLoading] = useState(false);

    const fetchBalances = async () => {
        if (!address) return;
        setLoading(true);
        const newBalances = {};

        for (const t of TOKENS) {
            let bal;
            if (t.key === 'native') {
                bal = await getNativeBalance(address);
            } else {
                const tokenAddr = ADDRESSES[t.key];
                if (tokenAddr) {
                    bal = await getTokenBalance(tokenAddr, address);
                }
            }
            if (bal) newBalances[t.key] = bal;
        }
        setBalances(prev => ({ ...prev, ...newBalances }));
        setLoading(false);
    };

    useEffect(() => {
        if (isConnected && address) {
            fetchBalances();
            const interval = setInterval(fetchBalances, 15000);
            return () => clearInterval(interval);
        }
    }, [isConnected, address, getTokenBalance, getNativeBalance]);

    if (!isConnected) return null;

    return (
        <div className="glass-panel p-6">
            <div className="flex justify-between items-center mb-4">
                <h2 className="text-xl font-bold">Wallet Balances</h2>
                <button onClick={fetchBalances} className="text-xs text-gray-500 hover:text-white">
                    {loading ? 'Refreshing...' : 'Refresh'}
                </button>
            </div>
            <div className="space-y-3">
                {TOKENS.map(t => (
                    <div key={t.key} className="flex justify-between items-center bg-white/5 p-3 rounded-lg">
                        <span className="font-bold text-gray-300">{t.name}</span>
                        <div className="text-right">
                            <div className="font-mono text-white">
                                {balances[t.key] ? parseFloat(balances[t.key].balance).toFixed(4) : '...'}
                            </div>
                            <div className="text-xs text-gray-500 font-mono">
                                {balances[t.key] ? `(~$${balances[t.key].usdValue})` : ''}
                            </div>
                        </div>
                    </div>
                ))}
            </div>
        </div>
    );
}
