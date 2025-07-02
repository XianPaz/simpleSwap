// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title SimpleSwap
/// @notice A basic AMM-like token swap contract supporting liquidity provision, removal, and token swaps
/// @dev This contract does not include fees and supports only a fixed single token pair (tokenA and tokenB created in constructor)
contract SimpleSwap {

    /// @notice tokenA of the pool
    IERC20 public tokenA;

    /// @notice tokenB of the pool
    IERC20 public tokenB;

    /// @notice Reserves for tokenA
    uint public reserveA;

    /// @notice Reserves for tokenB
    uint public reserveB;

    /// @notice Total liquidity minted in the pool
    uint public totalLiquidity;
    
    /// @notice Mapping of user addresses to their liquidity balance
    mapping(address => uint) public liquidityBalance;

    /// @notice Emitted when liquidity is added to the pool
    /// @param provider The address providing liquidity
    /// @param amountA Amount of tokenA added
    /// @param amountB Amount of tokenB added
    /// @param liquidity Amount of liquidity tokens minted
    event LiquidityAdded(address indexed provider, uint amountA, uint amountB, uint liquidity);

    /// @notice Emitted when liquidity is removed from the pool
    /// @param provider The address removing liquidity
    /// @param amountA Amount of tokenA removed
    /// @param amountB Amount of tokenB removed
    /// @param liquidity Amount of liquidity tokens burned
    event LiquidityRemoved(address indexed provider, uint amountA, uint amountB, uint liquidity);

    /// @notice Emitted when a swap occurs
    /// @param trader The address executing the swap
    /// @param amountIn Amount of tokenIn
    /// @param amountOut Amount of tokenOut
    event TokenSwapped(address indexed trader, uint amountIn, uint amountOut);

    /// @notice Initializes the contract with token pair addresses
    /// @param _tokenA Address of token A
    /// @param _tokenB Address of token B
    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    /// @notice Adds liquidity to the pool
    /// @param _tokenA Must be the contract's tokenA
    /// @param _tokenB Must be the contract's tokenB
    /// @param amountADesired Amount of tokenA the user wants to add
    /// @param amountBDesired Amount of tokenB the user wants to add
    /// @param amountAMin Minimum acceptable amount of tokenA
    /// @param amountBMin Minimum acceptable amount of tokenB
    /// @param to Address that will receive the liquidity tokens
    /// @param deadline Timestamp after which the operation is invalid
    /// @return amountA Actual amount of tokenA used
    /// @return amountB Actual amount of tokenB used
    /// @return liquidity Amount of liquidity tokens minted
    function addLiquidity(
        address _tokenA,
        address _tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline) 
        external returns (
            uint amountA, uint amountB, uint liquidity) {

        require(_tokenA == address(tokenA) && _tokenB == address(tokenB), "invalid tokens");
        require(block.timestamp <= deadline, "expired");

        if (totalLiquidity == 0) {
            // first liquidity: use desired amounts directly
            amountA = amountADesired;
            amountB = amountBDesired;
            liquidity = sqrt(amountA * amountB);
        } else {
            // use the current ratio of reserves
            uint amountBOptimal = (amountADesired * reserveB) / reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "insufficient b amount");
                amountA = amountADesired;
                amountB = amountBOptimal;
            } else {
                uint amountAOptimal = (amountBDesired * reserveA) / reserveB;
                require(amountAOptimal >= amountAMin, "insufficient a amount");
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }
            liquidity = min(
                (amountA * totalLiquidity) / reserveA,
                (amountB * totalLiquidity) / reserveB
            );
        }

        require(amountA > 0 && amountB > 0, "insufficient liquidity minted");

        // transfer tokens from user to contract
        require(tokenA.transferFrom(msg.sender, address(this), amountA), "transfer failed for token a");
        require(tokenB.transferFrom(msg.sender, address(this), amountB), "transfer failed for token b");

        // update reserves
        reserveA += amountA;
        reserveB += amountB;

        // mint liquidity tokens to user
        totalLiquidity += liquidity;
        liquidityBalance[to] += liquidity;

        // emit event for added liquidity
        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);

        return (amountA, amountB, liquidity);
    }

    /// @notice Computes the square root of a number
    /// @param y Number to compute the square root of
    /// @return z Square root result
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /// @notice Returns the smaller of two unsigned integers
    /// @param x First number
    /// @param y Second number
    /// @return Minimum of x and y
    function min(uint x, uint y) internal pure returns (uint) {
        return x < y ? x : y;
    }

    /// @notice Removes liquidity from the pool
    /// @param _tokenA Must be the contract's tokenA
    /// @param _tokenB Must be the contract's tokenB
    /// @param liquidity Amount of liquidity to burn
    /// @param amountAMin Minimum amount of tokenA to receive
    /// @param amountBMin Minimum amount of tokenB to receive
    /// @param to Address to receive the withdrawn tokens
    /// @param deadline Timestamp after which the operation is invalid
    /// @return amountA Amount of tokenA returned
    /// @return amountB Amount of tokenB returned
    function removeLiquidity(
        address _tokenA,
        address _tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline) 
    external returns (
        uint amountA, uint amountB) {

        require(_tokenA == address(tokenA) && _tokenB == address(tokenB), "invalid tokens");
        require(block.timestamp <= deadline, "expired");
        require(liquidity > 0, "invalid liquidity");
        require(liquidity <= liquidityBalance[msg.sender], "not enough liquidity");

        // calculate proportional amounts
        amountA = (liquidity * reserveA) / totalLiquidity;
        amountB = (liquidity * reserveB) / totalLiquidity;

        require(amountA >= amountAMin, "insufficient token a amount");
        require(amountB >= amountBMin, "insufficient token b amount");

        // update liquidity and reserves
        liquidityBalance[msg.sender] -= liquidity;
        totalLiquidity -= liquidity;

        reserveA -= amountA;
        reserveB -= amountB;

        // transfer tokens to recipient
        require(tokenA.transfer(to, amountA), "transfer failed for token a");
        require(tokenB.transfer(to, amountB), "transfer failed for token b");

        // emit event for removed liquidity
        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);

        return (amountA, amountB);
    }

    /// @notice Swaps a fixed amount of input tokens for as many output tokens as possible
    /// @param amountIn Amount of input tokens to swap
    /// @param amountOutMin Minimum acceptable amount of output tokens
    /// @param path Array of token addresses (must contain exactly [tokenA, tokenB] or vice versa)
    /// @param to Address to receive output tokens
    /// @param deadline Timestamp after which the operation is invalid
    /// @return amounts Array containing input and output token amounts
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline) 
    external returns (
        uint[] memory amounts) {
    require(path.length == 2, "only one pair supported");
    require(block.timestamp <= deadline, "expired");

    address input = path[0];
    address output = path[1];

    require(
        (input == address(tokenA) && output == address(tokenB)) ||
        (input == address(tokenB) && output == address(tokenA)),
        "invalid token pair"
    );

    bool isAToB = (input == address(tokenA));

    uint reserveIn;
    uint reserveOut;
    if (isAToB) {
        reserveIn = reserveA;
        reserveOut = reserveB;
        tokenA.transferFrom(msg.sender, address(this), amountIn);
    } else {
        reserveIn = reserveB;
        reserveOut = reserveA;
        tokenB.transferFrom(msg.sender, address(this), amountIn);
    }

    // calculate amount out using constant product formula: x * y = k
    // y_out = (reserve_out * amount_in) / (reserve_in + amount_in)
    uint amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);

    require(amountOut >= amountOutMin, "insufficient output amount");

    // transfer output tokens to recipient
    if (isAToB) {
       require(tokenB.transfer(to, amountOut), "transfer fail for output token");
    } else {
       require(tokenA.transfer(to, amountOut), "transfer fail for output token");
    }

    // update reserves
    if (isAToB) {
        reserveA += amountIn;
        reserveB -= amountOut;
    } else {
        reserveB += amountIn;
        reserveA -= amountOut;
    }

    // return input and output amounts
    uint[] memory _amounts = new uint[](2);
    _amounts[0] = amountIn;
    _amounts[1] = amountOut;
    amounts = _amounts;

    // emit event for token swapped
    emit TokenSwapped(msg.sender, amountIn, amountOut);

    return amounts;
    }

    /// @notice Gets the price ratio between two tokens
    /// @param _tokenA Address of input token
    /// @param _tokenB Address of output token
    /// @return price Price scaled by 1e18
    function getPrice(
        address _tokenA, 
        address _tokenB) 
    external view returns (
        uint price) {

        require(
            (_tokenA == address(tokenA) && _tokenB == address(tokenB)) ||
            (_tokenA == address(tokenB) && _tokenB == address(tokenA)),
            "invalid token pair"
        );

        if (_tokenA == address(tokenA)) {
            require(reserveA > 0, "no liquidity");
            price = (reserveB * 1e18) / reserveA; // scaled by 1e18
        } else {
            require(reserveB > 0, "no liquidity");
            price = (reserveA * 1e18) / reserveB; // scaled by 1e18
        }
    }

    /// @notice Calculates the output amount for a given input using the constant product formula
    /// @param amountIn Input amount of tokens
    /// @param reserveIn Reserve amount of input token
    /// @param reserveOut Reserve amount of output token
    /// @return amountOut Expected output token amount
    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountOut) {
        require(amountIn > 0, "amount in must > zero");
        require(reserveIn > 0 && reserveOut > 0, "insufficient liquidity");

        amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
    }

}