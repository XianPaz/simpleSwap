// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SimpleSwap {
    IERC20 public tokenA;
    IERC20 public tokenB;

    uint public reserveA;
    uint public reserveB;

    uint public totalLiquidity;
    mapping(address => uint) public liquidityBalance;

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

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

        return (amountA, amountB, liquidity);
    }

    // helper function: square root
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

    // helper function: minimum of two numbers
    function min(uint x, uint y) internal pure returns (uint) {
        return x < y ? x : y;
    }

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

        return (amountA, amountB);
    }

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
    uint numerator = amountIn * reserveOut;
    uint denominator = reserveIn + amountIn;
    uint amountOut = numerator / denominator;

    require(amountOut >= amountOutMin, "insufficient output amount");

    // transfer output tokens to recipient
    if (isAToB) {
       require(tokenB.transfer(to, amountOut), "transfer failed for output token");
    } else {
       require(tokenA.transfer(to, amountOut), "transfer failed for output token");
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
    return amounts;
    }

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

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountOut) {
        require(amountIn > 0, "amount in must be greater than zero");
        require(reserveIn > 0 && reserveOut > 0, "insufficient liquidity");

        amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
    }

}