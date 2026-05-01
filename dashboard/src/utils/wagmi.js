import { createConfig, http } from "wagmi"
import { polygon } from "wagmi/chains"
import { injected } from "wagmi/connectors"

export const config = createConfig({
    chains: [polygon],
    connectors: [injected()],
    transports: {
        // Explicitly override the viem default (polygon-rpc.com requires API key as of 2025)
        // Using polygon.drpc.org - a free and reliable public Polygon RPC
        [polygon.id]: http("https://polygon.drpc.org"),
    },
    ssr: true,
})
