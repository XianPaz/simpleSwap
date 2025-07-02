# SimpleSwap

A minimalistic smart contract for token swaps and liquidity management, inspired by Uniswap v1. This contract allows users to:

- Add liquidity for a single token pair
- Remove liquidity proportionally
- Swap between two ERC20 tokens
- Query prices and output estimates

The repo contains other two contracts:

- XianPazTokenA & XianPazTokenB: mintable ERC20s, 18 decimals created with openZeppelin library.

You can find these contracts deployed and verified in Sepolia in the following addresses:

- XianPazTokenA -> 0x0286BF4682568aC31Cae0afAe87391dff0C3d078
- XianPazTokenB -> 0xC526b8eD99CB755cF6b7BC695D2541266713501F
- SimpleSwap -> 0x2550a37051a909Ab4792B4F2283b5884A2272C46

SimpleSwap contract has been verified executing the verify() function of the SwapVerifier contract deployed at 0x9f8F02DAB384DDdf1591C3366069Da3Fb0018220 using "Cristian Paz" as the author which can be found in Authors array, position 104 and 105.

⚠️ **Note**: This implementation supports only one fixed pair of tokens, without fees. It's meant for learning, experimentation, and educational purposes—not production use.

---

## 📄 Contract Overview

- **Token Pair**: Fixed at deployment via constructor (`tokenA`, `tokenB`)
- **Liquidity Tracking**: Custom liquidity shares tracked via internal bookkeeping
- **Formula**: Uses the constant product AMM formula: `x * y = k`
- **Fee**: No fee mechanism implemented
- **Math**: Includes custom `sqrt` and `min` helper functions

---

## 🛠 Public Functions

### `addLiquidity`

```solidity
function addLiquidity(
    address _tokenA,
    address _tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
) external returns (uint amountA, uint amountB, uint liquidity)
```

Adds tokenA and tokenB liquidity into the pool and receives liquidity shares.

**Parameters**:
* address _tokenA: Must be the address of tokenA
* address _tokenB: Must be the address of tokenB
* uint amountADesired: Amount of tokenA the user wants to deposit
* uint amountBDesired: Amount of tokenB the user wants to deposit
* uint amountAMin: Minimum acceptable amount of tokenA
* uint amountBMin: Minimum acceptable amount of tokenB
* address to: Address to credit with liquidity tokens
* uint deadline: Unix timestamp after which the transaction will revert

**Returns**:
* uint amountA: Actual amount of tokenA deposited
* uint amountB: Actual amount of tokenB deposited
* uint liquidity: Liquidity tokens minted

### `removeLiquidity`

```solidity
function removeLiquidity(
    address _tokenA,
    address _tokenB,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
) external returns (uint amountA, uint amountB)
```

Burns liquidity tokens and returns the user’s proportional share of reserves.

**Parameters**:
* address _tokenA: Must be the address of tokenA
* address _tokenB: Must be the address of tokenB
* uint liquidity: Amount of liquidity to remove
* uint amountAMin: Minimum acceptable amount of tokenA
* uint amountBMin: Minimum acceptable amount of tokenB
* address to: Address to receive withdrawn tokens
* uint deadline: Unix timestamp after which the transaction will revert

**Returns**:
* uint amountA: TokenA withdrawn
* uint amountB: TokenB withdrawn

### `swapExactTokensForTokens`

```solidity
function swapExactTokensForTokens(
    uint amountIn,
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline
) external returns (uint[] memory amounts)
```

Swaps a known amount of input tokens for as many output tokens as possible using the constant product formula.

**Parameters**:
* uint amountIn: Amount of input token to swap
* uint amountOutMin: Minimum acceptable amount of output token
* address[] path: Array of two token addresses [tokenA, tokenB] or [tokenB, tokenA]
* address to: Address to receive output tokens
* uint deadline: Unix timestamp after which the transaction will revert

**Returns**:
* uint[] amounts: [amountIn, amountOut]

### `getPrice`

```solidity
function getPrice(
    address _tokenA,
    address _tokenB
) external view returns (uint price)
```

Returns the current price ratio between tokenA and tokenB.

**Parameters**:
* address _tokenA: Address of input token
* address _tokenB: Address of output token

**Returns**:
* uint price: Exchange rate scaled by 1e18

### `getAmountOut`

```solidity
function getAmountOut(
    uint amountIn,
    uint reserveIn,
    uint reserveOut
) external pure returns (uint amountOut)
```

Calculates how many output tokens you get for a given input based on reserves.

**Parameters**:
* uint amountIn: Amount of input token
* uint reserveIn: Current reserve of input token
* uint reserveOut: Current reserve of output token

**Returns**:
* uint amountOut: Expected amount of output tokens

## 🧮 Internal Helpers

### `sqrt`

```solidity
function sqrt(uint y) internal pure returns (uint z)
```

Computes the square root of an integer.

**Parameters**:
* uint y: Value to compute the square root of

**Returns**:
* uint z: Resulting square root

### `min`

```solidity
function min(uint x, uint y) internal pure returns (uint)
```

Returns the smaller of two numbers.

**Parameters**:
* uint x: First number
* uint y: Second number

**Returns**:
* uint: Minimum value
