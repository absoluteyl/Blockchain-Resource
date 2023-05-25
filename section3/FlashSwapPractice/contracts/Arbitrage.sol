// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Pair } from "v2-core/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Callee } from "v2-core/interfaces/IUniswapV2Callee.sol";

// This is a pracitce contract for flash swap arbitrage
contract Arbitrage is IUniswapV2Callee, Ownable {
    struct CallbackData {
        address basePool;
        address targetPool;
        address borrowToken;
        address debtToken;
        uint256 borrowAmt;
        uint256 lowDebtAmt;
        uint256 highDebtAmt;
    }

    //
    // EXTERNAL NON-VIEW ONLY OWNER
    //

    function withdraw() external onlyOwner {
        (bool success, ) = msg.sender.call{ value: address(this).balance }("");
        require(success, "Withdraw failed");
    }

    function withdrawTokens(address token, uint256 amount) external onlyOwner {
        require(IERC20(token).transfer(msg.sender, amount), "Withdraw failed");
    }

    //
    // EXTERNAL NON-VIEW
    //

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external override {
        require(sender == address(this), "Sender must be this contract");
        require(amount0 > 0 || amount1 > 0, "amount0 or amount1 must be greater than 0");

        // 3. decode callback data
        CallbackData memory callbackData = abi.decode(data, (CallbackData));
        require(msg.sender == callbackData.basePool, "msg.sender must be base pool");
        // 4. swap WETH to USDC
        IERC20(callbackData.borrowToken).transfer(callbackData.targetPool, callbackData.borrowAmt);
        IUniswapV2Pair(callbackData.targetPool).swap(
            0,
            callbackData.highDebtAmt,
            address(this),
            new bytes(0)
        );

        // 5. repay USDC to lower price pool
        require(IERC20(callbackData.debtToken).transfer(msg.sender, callbackData.lowDebtAmt), "Repay failed");
    }

    // Method 1 is
    //  - use USDC to borrow WETH from lower price pool
    //  - swap WETH for USDC in higher price pool
    //  - repay USDC to lower pool
    // Method 2 is
    //  - borrow USDC from higher price pool
    //  - swap USDC for WETH in lower pool
    //  - repay WETH to higher pool
    // for testing convenient, we implement the method 1 here
    function arbitrage(address priceLowerPool, address priceHigherPool, uint256 borrowAmount) external {
        // Get address of WETH and USDC
        address borrowToken = IUniswapV2Pair(priceLowerPool).token0();
        address debtToken = IUniswapV2Pair(priceLowerPool).token1();

        // Get how much USDC we need to pay to priceLowserPool if we want to borrow 5 WETH
        (uint112 lowerPoolReserve0, uint112 lowerPoolReserve1,) = IUniswapV2Pair(priceLowerPool).getReserves();
        uint256 lowerDebtAmount = _getAmountIn(
            borrowAmount,
            lowerPoolReserve1,
            lowerPoolReserve0
        );

        // Get how much USDC we can get from priceHigherPool if we swap 5 WETH
        (uint112 higherPoolReserve0, uint112 higherPoolReserve1,) = IUniswapV2Pair(priceHigherPool).getReserves();
        uint256 higherDebtAmount = _getAmountOut(
            borrowAmount,
            higherPoolReserve0,
            higherPoolReserve1
        );

        // 1. finish callbackData
        CallbackData memory callbackData = CallbackData(
            priceLowerPool,
            priceHigherPool,
            borrowToken,
            debtToken,
            borrowAmount,
            lowerDebtAmount,
            higherDebtAmount
        );

        // 2. flash swap (borrow WETH from lower price pool)
        IUniswapV2Pair(priceLowerPool).swap(
            borrowAmount,
            0,
            address(this),
            abi.encode(callbackData)
        );
    }

    //
    // INTERNAL PURE
    //

    // copy from UniswapV2Library
    function _getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = numerator / denominator + 1;
    }

    // copy from UniswapV2Library
    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }
}
