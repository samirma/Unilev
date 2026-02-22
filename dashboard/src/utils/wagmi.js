import { createConfig } from "wagmi"
import { polygon } from "wagmi/chains"
import { injected } from "wagmi/connectors"

export const config = createConfig({
    chains: [polygon],
    connectors: [injected()],
    transports: {
        // No explicit transport - wagmi will use the injected provider (MetaMask)
        [polygon.id]: undefined,
    },
    ssr: true,
})
