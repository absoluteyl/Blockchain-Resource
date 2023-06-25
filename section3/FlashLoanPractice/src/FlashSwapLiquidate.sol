pragma solidity 0.8.19;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IUniswapV2Callee} from "v2-core/interfaces/IUniswapV2Callee.sol";
import {IUniswapV2Factory} from "v2-core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "v2-core/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "v2-periphery/interfaces/IUniswapV2Router02.sol";
import {CErc20} from "compound-protocol/contracts/CErc20.sol";


contract FlashSwapLiquidate is IUniswapV2Callee {
  IERC20 public USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
  IERC20 public DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  CErc20 public cUSDC = CErc20(0x39AA39c021dfbaE8faC545936693aC917d5E7563);
  CErc20 public cDAI = CErc20(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
  IUniswapV2Router02 public router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  IUniswapV2Factory public factory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);


  function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external override {
    require(sender == address(this), "Sender must be this contract");
    require(amount0 > 0 || amount1 > 0, "amount0 or amount1 must be greater than 0");
    // 0. Decode callback data
    (
      address borrower,
      uint256 repayAmount // the DAI amount we need to repay to Uniswap
    ) = abi.decode(data, (address, uint256));

    // 1. liquidate borrower's cUSDC debt and get cDAI
    USDC.approve(address(cUSDC), amount1); // amount1 is USDC amount
    uint256 liquidateResult = cUSDC.liquidateBorrow(borrower, amount1, CErc20(cDAI));
    require(liquidateResult == 0, "liquidate failed");

    // 2. redeem cDAI to DAI
    uint256 redeemResult = cDAI.redeem(cDAI.balanceOf(address(this)));
    require(redeemResult == 0, "redeem failed");

    // 3. transfer DAI back to Uniswap
    DAI.transfer(msg.sender, repayAmount);
  }

  function liquidate(address borrower, uint256 amountOut) external {
    // Get pair address
    address[] memory path = new address[](2);
    path[0] = address(DAI);
    path[1] = address(USDC);
    address pair = factory.getPair(path[0], path[1]);

    // Calculate amountIn
    uint256 amountIn = router.getAmountsIn(amountOut, path)[0];

    // Swap by amountOut
    IUniswapV2Pair(pair).swap(
      0,
      amountOut,
      address(this),
      abi.encode(borrower, amountIn)
    );
  }
}
