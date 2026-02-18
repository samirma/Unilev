
import { useAccount, useConnect, useDisconnect } from 'wagmi';
import { injected } from 'wagmi/connectors';
import { useState, useEffect } from 'react';

export function ConnectButton() {
    const { address, isConnected } = useAccount();
    const { connect } = useConnect();
    const { disconnect } = useDisconnect();
    const [hasProvider, setHasProvider] = useState(false);

    useEffect(() => {
        setHasProvider(typeof window !== 'undefined' && typeof window.ethereum !== 'undefined');
    }, []);

    if (isConnected) {
        return (
            <div className="flex items-center gap-4">
                <span className="font-mono text-sm bg-white/10 px-3 py-1 rounded-full border border-white/10">
                    {address.slice(0, 6)}...{address.slice(-4)}
                </span>
                <button
                    onClick={() => disconnect()}
                    className="secondary-button text-sm px-4 py-2"
                >
                    Disconnect
                </button>
            </div>
        );
    }

    if (!hasProvider) {
        return (
            <a
                href="https://metamask.io/download/"
                target="_blank"
                rel="noopener noreferrer"
                className="secondary-button text-sm px-4 py-2 bg-orange-500/10 text-orange-400 border-orange-500/20 hover:bg-orange-500/20"
            >
                Install MetaMask
            </a>
        );
    }

    return (
        <button
            onClick={() => connect({ connector: injected() })}
            className="primary-button animate-pulse-glow"
        >
            Connect Wallet
        </button>
    );
}
