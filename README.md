# Uniswap Max contract

## Requirements

Please install the following:

-   [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
    -   You'll know you've done it right if you can run `git --version`
-   [Foundry / Foundryup](https://github.com/gakonst/foundry)
    -   This will install `forge`, `cast`, and `anvil`
    -   You can test you've installed them right by running `forge --version` and get an output like: `forge 0.2.0 (f016135 2022-07-04T00:15:02.930499Z)`
    -   To get the latest of each, just run `foundryup`

And you probably already have `make` installed... but if not [try looking here.](https://askubuntu.com/questions/161104/how-do-i-install-make)

## Setup

You'll need to add the following variables to a `.env` file:

-   `ETH_RPC_URL`: A URL to connect fork the mainnet.
-   `PRIVATE_KEY`: A private key from your wallet. You can get a private key from a new [Metamask](https://metamask.io/) account
-   Optional `ETHERSCAN_API_KEY`: If you want to verify on etherscan

## Quickstart

```sh
git https://github.com/Los-Byzantinos/Uniswap-Max
cd Uniswap-Max
```

Fill **ETH_RPC_URL** in `.env`

```sh
make test fork
```

## Local Testing

```
make anvil
```

Open an other terminal and :

```
make deploy-anvil
```

# Security

This codebase is not audited, don't use it in production.

This framework comes with slither parameters, a popular security framework from [Trail of Bits](https://www.trailofbits.com/). To use slither, you'll first need to [install python](https://www.python.org/downloads/) and [install slither](https://github.com/crytic/slither#how-to-install).

Then, you can run:

```
make slither
```

And get your slither output.

# Resources

-   [Chainlink Documentation](https://docs.chain.link/)
-   [Foundry Documentation](https://book.getfoundry.sh/)

# TODO before deployment

set optimization cycle to 500

mv lib/libraries src/

remmaping.txt

```
@solmate=lib/solmate/src/
@std=lib/forge-std/src/
@clones=lib/clones-with-immutable-args/src/
@chainlink/=lib/chainlink-brownie-contracts/
@openzeppelin/=lib/openzeppelin-contracts/
@uniswapCore/=src/libraries/v3-core/
@uniswap/v3-core/=src/libraries/v3-core/
@uniswapPeriphery/=src/libraries/v3-periphery/
forge-std/=lib/forge-std/src/
```
