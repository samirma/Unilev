
import { useState, useEffect } from 'react';
import { useDeFi } from '../hooks/useDeFi';
import clsx from 'clsx';
import { useAccount } from 'wagmi';
import { polygon } from 'wagmi/chains';
import { ethers } from 'ethers';
import { formatContractError, isUserCancellation } from '../utils/formatContractError';

export function TradeForm() {
    const { isConnected, chainId, address } = useAccount();
    const { 
        openPosition, 
        calculateTokenAmountFromUsd, 
        getPoolBorrowCapacity, 
        ADDRESSES, 
        SUPPORTED_TOKENS_LIST,
        isMetaMaskInstalled,
        getTokenBalance,
        getAmountInUsd
    } = useDeFi();

    const [marginToken, setMarginToken] = useState('USDC');
    const [tradingToken, setTradingToken] = useState('WBTC');
    const [amount, setAmount] = useState('0');
    const [leverage, setLeverage] = useState('1');
    const [isShort, setIsShort] = useState(false);
    const [status, setStatus] = useState('');
    const [loading, setLoading] = useState(false);

    // Balance & Value State
    const [balanceData, setBalanceData] = useState(null);
    const [usdValue, setUsdValue] = useState('0.00');

    // Liquidity State
    const [borrowCapacity, setBorrowCapacity] = useState(null);
    const [requiredBorrow, setRequiredBorrow] = useState(null);
    const [isLiquiditySufficient, setIsLiquiditySufficient] = useState(true);

    const isCorrectNetwork = chainId === polygon.id;

    // Fetch USD Value of the entered amount
    useEffect(() => {
        const fetchUsdValue = async () => {
            if (!amount || isNaN(amount) || !balanceData) {
                setUsdValue('0.00');
                return;
            }
            try {
                const marginAddr = ADDRESSES[marginToken];
                const amountBig = ethers.parseUnits(amount.toString(), balanceData.decimals);
                const usdBig = await getAmountInUsd(marginAddr, amountBig);
                setUsdValue(parseFloat(ethers.formatUnits(usdBig, 18)).toFixed(2));
            } catch (err) {
                console.error("Error fetching USD value:", err);
            }
        };
        fetchUsdValue();
    }, [amount, marginToken, balanceData, ADDRESSES, getAmountInUsd]);

    // Fetch user balance for the selected margin token
    useEffect(() => {
        const fetchBalance = async () => {
            if (!isConnected || !address || !isCorrectNetwork) return;
            const marginAddr = ADDRESSES[marginToken];
            if (!marginAddr) return;

            const data = await getTokenBalance(marginAddr, address);
            setBalanceData(data);
        };
        fetchBalance();
    }, [isConnected, address, isCorrectNetwork, marginToken, ADDRESSES, getTokenBalance]);

    // Fetch pool capacity when collateral token changes
    useEffect(() => {
        const fetchCapacity = async () => {
            if (!isConnected || !isCorrectNetwork) return;

            // If shorting, the borrowed capacity relies on the trading token (base) pool
            // If longing, the borrowed capacity relies on the margin token (quote) pool
            const borrowCapacityToken = isShort ? tradingToken : marginToken;
            const capacityTokenAddr = ADDRESSES[borrowCapacityToken];

            if (!capacityTokenAddr) return;

            const capacityData = await getPoolBorrowCapacity(capacityTokenAddr);
            setBorrowCapacity(capacityData);
        };
        fetchCapacity();

        // Setup initial default selected tokens if not set properly (e.g if 'USDC/WBTC' don't exist in config)
        if (SUPPORTED_TOKENS_LIST.length > 0) {
            if (!SUPPORTED_TOKENS_LIST.find(t => t.key === marginToken)) {
                setMarginToken(SUPPORTED_TOKENS_LIST[0].key);
            }
            if (!SUPPORTED_TOKENS_LIST.find(t => t.key === tradingToken)) {
                setTradingToken(SUPPORTED_TOKENS_LIST[Math.min(1, SUPPORTED_TOKENS_LIST.length - 1)].key);
            }
        }
    }, [isConnected, isCorrectNetwork, marginToken, tradingToken, isShort, ADDRESSES, getPoolBorrowCapacity, SUPPORTED_TOKENS_LIST]);

    // Calculate required borrow when amount/leverage changes
    useEffect(() => {
        const calculateRequired = async () => {
            if (!isConnected || !isCorrectNetwork || !borrowCapacity || !balanceData) return;
            
            if (!amount || isNaN(amount) || !leverage || isNaN(leverage)) {
                setRequiredBorrow(null);
                setIsLiquiditySufficient(true);
                return;
            }

            try {
                // Parse amount directly
                const marginAmount = ethers.parseUnits(amount.toString(), balanceData.decimals);
                if (marginAmount === 0n) return;

                // required distance (leverage - 1) * margin
                const lev = BigInt(leverage);
                const reqBorrowAmount = marginAmount * (lev - 1n);

                setRequiredBorrow(reqBorrowAmount);

                if (borrowCapacity.rawCapacity) {
                    setIsLiquiditySufficient(borrowCapacity.rawCapacity >= reqBorrowAmount);
                } else {
                    setIsLiquiditySufficient(false);
                }
            } catch (err) {
                console.error("Error calculating required borrow:", err);
            }
        };

        // Add a slight debounce to avoid slamming RPC on every keystroke
        const timeout = setTimeout(calculateRequired, 300);
        return () => clearTimeout(timeout);
    }, [isConnected, isCorrectNetwork, borrowCapacity, amount, leverage, marginToken, ADDRESSES, balanceData]);

    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!isConnected || !isCorrectNetwork || !balanceData) return;
        setLoading(true);
        setStatus('Preparing transaction...');

        try {
            // "token0" is what trader SENDS as margin
            // "token1" is the other half of the pair to trade
            const marginAddr = ADDRESSES[marginToken]; // sent by user
            const tradingAddr = ADDRESSES[tradingToken]; // traded against

            // Check if they are trying illegal setups via the UI selector
            if (marginAddr === tradingAddr) {
                throw new Error("Margin token and Trade token cannot be the same.");
            }

            const amountBig = ethers.parseUnits(amount.toString(), balanceData.decimals);

            if (amountBig === 0n) {
                throw new Error("Amount cannot be zero");
            }

            // Validation 1: Leverage limit
            const levInt = parseInt(leverage);
            if (levInt > 5) {
                throw new Error("Maximum allowed leverage is 5x.");
            }

            // Validation 2: Minimum USD amount ($1)
            const usdBig = await getAmountInUsd(marginAddr, amountBig);
            if (usdBig < 1000000000000000000n) { // 1e18
                throw new Error("Minimum position size is $1 USD.");
            }

            setStatus('Approving & Opening Position...');

            const tx = await openPosition(
                marginAddr,
                tradingAddr,
                isShort,
                amountBig,
                parseInt(leverage)
            );

            setStatus(`Transaction Sent: ${tx.hash}`);
            await tx.wait();
            setStatus('✅ Position Opened Successfully!');

        } catch (error) {
            console.error(error);
            if (isUserCancellation(error)) {
                setStatus(''); // Just clear it if they cancel
            } else {
                const friendlyError = formatContractError(error);
                setStatus(`❌ Error: ${friendlyError}`);
            }
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

                {/* Direction Selection */}
                <div>
                    <label className="text-xs text-gray-400 mb-2 block font-bold uppercase tracking-wider">Position Direction</label>
                    <div className="grid grid-cols-2 gap-3">
                        <button
                            type="button"
                            onClick={() => setIsShort(false)}
                            className={clsx(
                                "py-3 rounded-xl border-2 transition-all flex flex-col items-center justify-center gap-1",
                                !isShort
                                    ? "bg-green-500/10 border-green-500 text-green-400 shadow-[0_0_15px_rgba(34,197,94,0.3)]"
                                    : "bg-black/40 border-transparent text-gray-400 hover:bg-white/5 hover:text-gray-300"
                            )}
                        >
                            <span className="font-bold text-lg tracking-wider">LONG</span>
                            <span className={clsx("text-xs", !isShort ? "text-green-500/80" : "text-gray-500")}>
                                Uses {marginToken} Pool
                            </span>
                        </button>
                        <button
                            type="button"
                            onClick={() => setIsShort(true)}
                            className={clsx(
                                "py-3 rounded-xl border-2 transition-all flex flex-col items-center justify-center gap-1",
                                isShort
                                    ? "bg-red-500/10 border-red-500 text-red-400 shadow-[0_0_15px_rgba(239,68,68,0.3)]"
                                    : "bg-black/40 border-transparent text-gray-400 hover:bg-white/5 hover:text-gray-300"
                            )}
                        >
                            <span className="font-bold text-lg tracking-wider">SHORT</span>
                            <span className={clsx("text-xs", isShort ? "text-red-500/80" : "text-gray-500")}>
                                Uses {tradingToken} Pool
                            </span>
                        </button>
                    </div>
                </div>

                {/* Token Selection */}
                <div className="grid grid-cols-2 gap-4">
                    <div>
                        <label className="text-xs text-gray-400 mb-1 block">Margin (Sent) Token</label>
                        <select
                            value={marginToken}
                            onChange={(e) => setMarginToken(e.target.value)}
                            className="input-field bg-black/40"
                        >
                            {SUPPORTED_TOKENS_LIST.map(t => <option key={t.key} value={t.key}>{t.name}</option>)}
                        </select>
                    </div>
                    <div>
                        <label className="text-xs text-gray-400 mb-1 block">Trading (Asset) Token</label>
                        <select
                            value={tradingToken}
                            onChange={(e) => setTradingToken(e.target.value)}
                            className="input-field bg-black/40"
                        >
                            {SUPPORTED_TOKENS_LIST.map(t => <option key={t.key} value={t.key}>{t.name}</option>)}
                        </select>
                    </div>
                </div>

                {/* Amount & Leverage Grid */}
                <div className="grid grid-cols-2 gap-4">
                    {/* Amount */}
                    <div>
                        <div className="flex justify-between mb-1">
                            <label className="text-xs text-gray-400 block">Amount ({marginToken})</label>
                            {balanceData && (
                                <span 
                                    onClick={() => setAmount(balanceData.balance)}
                                    className="text-xs text-blue-400 cursor-pointer hover:text-blue-300"
                                >
                                    Max: {parseFloat(balanceData.balance).toFixed(4)}
                                </span>
                            )}
                        </div>
                        <input
                            type="number"
                            value={amount}
                            onChange={(e) => setAmount(e.target.value)}
                            className="input-field"
                            placeholder="0.00"
                        />
                    </div>

                    {/* Leverage */}
                    <div>
                        <label className="text-xs text-gray-400 mb-1 block">Leverage (Max 5x)</label>
                        <input
                            type="number"
                            value={leverage}
                            onChange={(e) => setLeverage(e.target.value)}
                            className="input-field"
                            min="1" max="5"
                        />
                    </div>
                </div>

                {/* Amount USD Display */}
                <div className="text-[10px] text-gray-500 text-right px-1">
                    Value: ≈ ${usdValue} USD
                </div>

                {/* Liquidity Information */}
                {(requiredBorrow !== null && borrowCapacity !== null && leverage > 1) && (
                    <div className={clsx(
                        "p-3 rounded text-sm transition-colors",
                        isLiquiditySufficient ? "bg-white/5 text-gray-400" : "bg-red-500/20 text-red-400 border border-red-500/50"
                    )}>
                        <div className="flex justify-between mb-1">
                            <span>Required Borrow:</span>
                            <span className="font-mono">
                                {borrowCapacity ? formatSmallDisplay(requiredBorrow, borrowCapacity) : '0'} {isShort ? tradingToken : marginToken}
                            </span>
                        </div>
                        <div className="flex justify-between">
                            <span>Pool Capacity:</span>
                            <span className="font-mono">
                                {borrowCapacity.capacityFormatted} {isShort ? tradingToken : marginToken}
                            </span>
                        </div>
                        {!isLiquiditySufficient && (
                            <div className="mt-2 text-xs font-bold w-full text-center uppercase tracking-wide">
                                Insufficient Pool Liquidity
                            </div>
                        )}
                    </div>
                )}

                <button
                    type="submit"
                    disabled={loading || !isConnected || !isCorrectNetwork || !isLiquiditySufficient || !isMetaMaskInstalled}
                    className={clsx(
                        "w-full primary-button mt-4",
                        (loading || !isCorrectNetwork || !isLiquiditySufficient || !isMetaMaskInstalled) && "opacity-50 cursor-not-allowed"
                    )}
                >
                    {!isMetaMaskInstalled
                        ? 'Install MetaMask'
                        : !isCorrectNetwork
                            ? 'Wrong Network'
                            : !isLiquiditySufficient
                                ? 'Insufficient Liquidity'
                                : loading
                                    ? 'Processing...'
                                    : 'Open Position'}
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

// Small helper just for the UI so we aren't showing massive BigInts unformatted
function formatSmallDisplay(bigIntAmount, capacityData) {
    if (!capacityData || !bigIntAmount) return "0";
    // We expect capacityData to be derived from decimals, so we cheat here 
    // to find decimals inversely, but it's simpler to just do this roughly:
    // Capacity BigInt / Capacity Formatted = 10^decimals
    try {
        const capacityNum = parseFloat(capacityData.capacityFormatted);
        if (capacityNum === 0 || capacityData.rawCapacity === 0n) return "0";

        // Approx ratio
        const display = parseFloat(bigIntAmount.toString()) / parseFloat(capacityData.rawCapacity.toString()) * capacityNum;
        return display.toFixed(4);
    } catch {
        return "0.00";
    }
}
