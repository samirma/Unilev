
import { useState, useEffect } from 'react';
import { useDeFi } from '../hooks/useDeFi';
import { useAccount } from 'wagmi';

export function FeeManager() {
    const { getFeeDefaults, updateFeeDefaults } = useDeFi();
    const { isConnected } = useAccount();

    const [fees, setFees] = useState({ treasureFee: '', liquidationReward: '' });
    const [loading, setLoading] = useState(false);
    const [updating, setUpdating] = useState(false);
    const [status, setStatus] = useState('');

    const fetchFees = async () => {
        setLoading(true);
        const defaults = await getFeeDefaults();
        if (defaults) {
            setFees({
                treasureFee: defaults.treasureFee,
                liquidationReward: defaults.liquidationReward
            });
        }
        setLoading(false);
    };

    useEffect(() => {
        if (isConnected) fetchFees();
    }, [isConnected, getFeeDefaults]);

    const handleUpdate = async (e) => {
        e.preventDefault();
        setUpdating(true);
        setStatus('Sending transaction...');
        try {
            const tx = await updateFeeDefaults(fees.treasureFee, fees.liquidationReward);
            setStatus(`Tx Sent: ${tx.hash}`);
            await tx.wait();
            setStatus('✅ Fees Updated!');
            fetchFees();
        } catch (error) {
            console.error(error);
            setStatus(`❌ Error: ${error.reason || error.message}`);
        } finally {
            setUpdating(false);
        }
    };

    if (!isConnected) return null;

    return (
        <div className="glass-panel p-6 w-full mt-8 border-t border-white/10">
            <div className="flex justify-between items-center mb-6">
                <h2 className="text-xl font-bold text-gray-200">Fee Manager</h2>
                <button onClick={fetchFees} className="text-xs text-gray-500 hover:text-white">Refresh</button>
            </div>

            <form onSubmit={handleUpdate} className="grid grid-cols-1 md:grid-cols-3 gap-6 items-end">
                <div>
                    <label className="block text-xs text-gray-500 mb-2 uppercase tracking-wide">Treasure Fee (wei)</label>
                    <input
                        type="text"
                        value={fees.treasureFee}
                        onChange={(e) => setFees({ ...fees, treasureFee: e.target.value })}
                        className="input-field font-mono text-sm"
                        placeholder="0"
                    />
                </div>

                <div>
                    <label className="block text-xs text-gray-500 mb-2 uppercase tracking-wide">Liquidation Reward (wei)</label>
                    <input
                        type="text"
                        value={fees.liquidationReward}
                        onChange={(e) => setFees({ ...fees, liquidationReward: e.target.value })}
                        className="input-field font-mono text-sm"
                        placeholder="0"
                    />
                </div>

                <button
                    type="submit"
                    disabled={updating || loading}
                    className="primary-button py-2.5 text-sm bg-purple-600 hover:bg-purple-500 border-purple-500/20"
                >
                    {updating ? 'Updating...' : 'Update Defaults'}
                </button>
            </form>

            {status && (
                <div className="mt-4 p-3 bg-black/30 rounded text-xs font-mono text-gray-400 break-all">
                    {status}
                </div>
            )}
        </div>
    );
}
