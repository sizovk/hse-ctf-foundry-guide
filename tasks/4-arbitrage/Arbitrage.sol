// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
}

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

contract Arbitrage {

    // Router for interaction with pool0
    address public constant UNI_ROUTER_0 = 0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008;
    // Router for interaction with pool1
    address public constant UNI_ROUTER_1 = 0x86dcd3293C53Cf8EFd7303B57beb2a3F671dDE98;

    address public immutable POOL_0;
    address public immutable POOL_1;
    uint256 public immutable MINIMUM_PROFIT;
    uint256 public immutable INITIAL_PLAYER_BALANCE;

    constructor(address pool0, address pool1, uint256 initialPlayerBalance, uint256 minimumProfit) {
        POOL_0 = pool0;
        POOL_1 = pool1;
        INITIAL_PLAYER_BALANCE = initialPlayerBalance;
        MINIMUM_PROFIT = minimumProfit;
    }

    function isSolved(address player) public view returns(bool) {
        return IERC20(IUniswapV2Pair(POOL_0).token1()).balanceOf(player) - INITIAL_PLAYER_BALANCE >= MINIMUM_PROFIT;
    }
}
