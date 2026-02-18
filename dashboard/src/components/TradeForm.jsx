
import { useState } from 'react';
import { useDeFi } from '../hooks/useDeFi';
import clsx from 'clsx';
import { useAccount } from 'wagmi';

const TOKENS = [
    { key: 'WETH', name: 'WETH' },
    { key: 'DAI', name: 'DAI' },
    { key: 'USDC', name: 'USDC' },
    { key: 'WBTC', name: 'WBTC' },
];

export function TradeForm() {
    const { isConnected } = useAccount();
    const { openPosition, calculateTokenAmountFromUsd, ADDRESSES } = useDeFi();

    const [collateralToken, setCollateralToken] = useState('WBTC');
    const [targetToken, setTargetToken] = useState('WETH');
    const [usdAmount, setUsdAmount] = useState('10');
    const [leverage, setLeverage] = useState('1');
    const [isShort, setIsShort] = useState(true);
    const [status, setStatus] = useState('');
    const [loading, setLoading] = useState(false);

    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!isConnected) return;
        setLoading(true);
        setStatus('Calculating amount...');

        try {
            const collateralAddr = ADDRESSES[collateralToken];
            const targetAddr = ADDRESSES[targetToken];

            // Calculate amount in collateral token
            // logic similar to openShortPosition.js: 
            // calculateTokenAmountFromUsd(collateral, usdAmount)
            // Note: openShortPosition used collateral contract to get decimals etc.

            const amount = await calculateTokenAmountFromUsd(collateralAddr, usdAmount);

            if (amount === 0n) {
                throw new Error("Failed to calculate amount");
            }

            setStatus('Approving & Opening Position...');

            const tx = await openPosition(
                collateralAddr,
                targetAddr,
                isShort,
                amount,
                parseInt(leverage)
            );

            setStatus(`Transaction Sent: ${tx.hash}`);
            await tx.wait();
            setStatus('✅ Position Opened Successfully!');

        } catch (error) {
            console.error(error);
            setStatus(`❌ Error: ${error.reason || error.message}`);
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="glass-panel p-6 w-full max-w-md">
            <h2 className="text-xl font-bold mb-6 bg-clip-text text-transparent bg-gradient-to-r from-pink-500 to-violet-500">
                Open Position
            </h2>

            <form onSubmit={handleSubmit} className="space-y-4">

                {/* Token Selection */}
                <div className="grid grid-cols-2 gap-4">
                    <div>
                        <label className="text-xs text-gray-400 mb-1 block">Collateral (Token 0)</label>
                        <select
                            value={collateralToken}
                            onChange={(e) => setCollateralToken(e.target.value)}
                            className="input-field bg-black/40"
                        >
                            {TOKENS.map(t => <option key={t.key} value={t.key}>{t.name}</option>)}
                        </select>
                    </div>
                    <div>
                        <label className="text-xs text-gray-400 mb-1 block">Target (Token 1)</label>
                        <select
                            value={targetToken}
                            onChange={(e) => setTargetToken(e.target.value)}
                            className="input-field bg-black/40"
                        >
                            {TOKENS.map(t => <option key={t.key} value={t.key}>{t.name}</option>)}
                        </select>
                    </div>
                </div>

                {/* Amount */}
                <div>
                    <label className="text-xs text-gray-400 mb-1 block">Amount (USD)</label>
                    <input
                        type="number"
                        value={usdAmount}
                        onChange={(e) => setUsdAmount(e.target.value)}
                        className="input-field"
                        placeholder="10"
                    />
                </div>

                {/* Leverage & Type */}
                <div className="grid grid-cols-2 gap-4">
                    <div>
                        <label className="text-xs text-gray-400 mb-1 block">Leverage</label>
                        <input
                            type="number"
                            value={leverage}
                            onChange={(e) => setLeverage(e.target.value)}
                            className="input-field"
                            min="1" max="10"
                        />
                    </div>
                    <div>
                        <label className="text-xs text-gray-400 mb-1 block">Type</label>
                        <div className="flex bg-black/40 rounded-lg p-1 border border-white/10">
                            <button
                                type="button"
                                onClick={() => setIsShort(false)}
                                className={clsx(
                                    "flex-1 py-2 rounded text-sm font-bold transition-all",
                                    !isShort ? "bg-green-600 text-white shadow-lg" : "text-gray-400 hover:text-white"
                                )}
                            >
                                LONG
                            </button>
                            <button
                                type="button"
                                onClick={() => setIsShort(true)}
                                className={clsx(
                                    "flex-1 py-2 rounded text-sm font-bold transition-all",
                                    isShort ? "bg-red-600 text-white shadow-lg" : "text-gray-400 hover:text-white"
                                )}
                            >
                                SHORT
                            </button>
                        </div>
                    </div>
                </div>

                <button
                    type="submit"
                    disabled={loading || !isConnected}
                    className={clsx(
                        "w-full primary-button mt-4",
                        loading && "opacity-50 cursor-not-allowed"
                    )}
                >
                    {loading ? 'Processing...' : 'Open Position'}
                </button>

                {status && (
                    <div className="mt-4 p-3 bg-white/5 rounded border border-white/10 text-xs font-mono break-all">
                        {status}
                    </div>
                )}

            </form>
        </div>
    );
}
