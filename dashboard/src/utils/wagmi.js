import { createConfig, http } from "wagmi"
import { polygon } from "wagmi/chains"
import { injected } from "wagmi/connectors"

export const config = createConfig({
    chains: [polygon],
    connectors: [injected()],
    transports: {
        [polygon.id]: http("https://polygon-mainnet.g.alchemy.com/v2/oT1vfY4yefQFB7Czqenvb"),
    },
    ssr: true,
})
