// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "test/helper/CompoundLendingSetUp.sol";

contract CompoundLendingTest is CompoundLendingSetUp {

  address public user1;
  address public user2;

  uint256 public initialBalanceA;
  uint256 public initialBalanceB;

  function setUp() public override {
    super.setUp();

    user1 = makeAddr("user1");
    user2 = makeAddr("user2");

    initialBalanceA = 100 * 10 ** tokenA.decimals();
    initialBalanceB = 100 * 10 ** tokenB.decimals();

    deal(address(tokenA), user1, initialBalanceA);
    deal(address(tokenB), user1, initialBalanceB);

    deal(address(tokenA), user2, initialBalanceA);
    deal(address(tokenB), user2, initialBalanceB);
  }

  function testDeploy() public {
    require(address(comptroller) != address(0), "comptroller is not deployed");
    require(address(unitroller) != address(0), "unitroller is not deployed");
    require(address(interestRateModel) != address(0), "interestRateModel is not deployed");
    require(address(cErc20Delegate) != address(0), "cErc20Delegate is not deployed");
    require(address(priceOracle) != address(0), "priceOracle is not deployed");

    require(address(tokenA) != address(0), "tokenA is not deployed");
    require(address(tokenB) != address(0), "tokenB is not deployed");

    require(address(cTokenA) != address(0), "cTokenA is not deployed");
    require(address(cTokenB) != address(0), "cTokenB is not deployed");

    console.log("=== Deploy Result ===");
    console.log("comptroller: ", address(comptroller));
    console.log("unitroller: ", address(unitroller));
    console.log("interestRateModel: ", address(interestRateModel));
    console.log("cErc20Delegate: ", address(cErc20Delegate));
    console.log("priceOracle: ", address(priceOracle));
    console.log("tokenA: ", address(tokenA));
    console.log("tokenB: ", address(tokenB));
    console.log("cTokenA: ", address(cTokenA));
    console.log("cTokenB: ", address(cTokenB));
  }

  function testMintRedeemA() public {
    vm.startPrank(user1);

    tokenA.approve(address(cTokenA), initialBalanceA);
    uint256 mintResult = cTokenA.mint(initialBalanceA);
    require(mintResult == 0, "Mint failed");

    assertEq(cTokenA.balanceOf(address(user1)), initialBalanceA);

    uint256 redeemResult = cTokenA.redeem(cTokenA.balanceOf(address(user1)));
    require(redeemResult == 0, "Redeem failed");

    assertEq(tokenA.balanceOf(address(user1)), initialBalanceA);

    vm.stopPrank();
  }

  function testMintRedeemB() public {
    vm.startPrank(user1);

    tokenB.approve(address(cTokenB), initialBalanceB);
    uint256 mintResult = cTokenB.mint(initialBalanceB);
    require(mintResult == 0, "Mint failed");

    assertEq(cTokenB.balanceOf(address(user1)), initialBalanceB);

    uint256 redeemResult = cTokenB.redeem(cTokenB.balanceOf(address(user1)));
    require(redeemResult == 0, "Redeem failed");

    assertEq(tokenB.balanceOf(address(user1)), initialBalanceB);

    vm.stopPrank();
  }

  function testBorrowRepay() public {
    // let cTokenA has tokenA to borrow
    deal(address(tokenA), address(cTokenA), 10000 * 10**tokenA.decimals());

    vm.startPrank(user1);

    // mint cTokenB
    uint256 mintAmount = 1 * 10**tokenB.decimals();
    tokenB.approve(address(cTokenB), mintAmount);
    uint256 mintResult = cTokenB.mint(mintAmount);
    require(mintResult == 0, "Mint failed");
    require(cTokenB.balanceOf(address(user1)) == mintAmount, "Mint amount is not correct");

    // collateralize cTokenB
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(cTokenB);
    proxiedComptroller.enterMarkets(cTokens);

    // make sure cTokenB is been collateral
    CToken[] memory assetsIn = proxiedComptroller.getAssetsIn(address(user1));
    require(address(assetsIn[0]) == address(cTokenB), "assetsIn is not correct");

    // get account liquidity for user1
    (,uint256 initialLiquidity,) = proxiedComptroller.getAccountLiquidity(address(user1));

    // borrow tokenA
    uint256 borrowAmount = 50 * 10**tokenA.decimals();
    uint256 borrowResult = cTokenA.borrow(borrowAmount);
    require(borrowResult == 0, "Borrow failed");

    // get account liquidity for user1 after borrow
    (,uint256 liquidityAfterBorrow,) = proxiedComptroller.getAccountLiquidity(address(user1));

    assertEq(tokenA.balanceOf(address(user1)), initialBalanceA + borrowAmount);
    assertEq(liquidityAfterBorrow, 0);

    // repay tokenA
    tokenA.approve(address(cTokenA), borrowAmount);
    cTokenA.repayBorrow(borrowAmount);

    // get account liquidity for user1 after repay
    (,uint256 liquidityAfterRepay,) = proxiedComptroller.getAccountLiquidity(address(user1));

    assertEq(tokenA.balanceOf(address(user1)), initialBalanceA);
    assertEq(liquidityAfterRepay, initialLiquidity); // liquidity should be the same as before

    vm.stopPrank();
  }

  function testCollateralFactorChangeLiquidation() public {
    // let cTokenA has tokenA to borrow
    deal(address(tokenA), address(cTokenA), 10000 * 10**tokenA.decimals());

    // Prepare the debts for user1
    vm.startPrank(user1);

    // mint cTokenB
    uint256 mintAmount = 1 * 10**tokenB.decimals();
    tokenB.approve(address(cTokenB), mintAmount);
    uint256 mintResult = cTokenB.mint(mintAmount);
    require(mintResult == 0, "Mint failed");
    require(cTokenB.balanceOf(address(user1)) == mintAmount, "Mint amount is not correct");

    // collateralize cTokenB
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(cTokenB);
    proxiedComptroller.enterMarkets(cTokens);

    // make sure cTokenB is been collateral
    CToken[] memory assetsIn = proxiedComptroller.getAssetsIn(address(user1));
    require(address(assetsIn[0]) == address(cTokenB), "assetsIn is not correct");

    // get account liquidity for user1
    (,uint256 initialLiquidity,) = proxiedComptroller.getAccountLiquidity(address(user1));

    // borrow tokenA
    uint256 borrowAmount = 50 * 10**tokenA.decimals();
    uint256 borrowResult = cTokenA.borrow(borrowAmount);
    require(borrowResult == 0, "Borrow failed");

    // get account liquidity for user1 after borrow
    (,uint256 liquidityAfterBorrow,) = proxiedComptroller.getAccountLiquidity(address(user1));
    require(tokenA.balanceOf(address(user1)) == initialBalanceA + borrowAmount, "borrowAmount is not correct");
    require(liquidityAfterBorrow == 0, "liquidityAfterBorrow is not correct after borrow");

    vm.stopPrank();
    // Finish preparation

    // decrease collateral factor
    proxiedComptroller._setCollateralFactor(CToken(address(cTokenB)), 0.3e18);

    // get shortfall for user1 after collateral factor decrease
    // user1 borrows $50 tokenA, and close factor is 0.3, so user1's shortfall is $50 - ($100 * 0.3) = $20
    (,, uint256 shortfall) = proxiedComptroller.getAccountLiquidity(address(user1));
    assertEq(shortfall, 20);

    // user2 will liquidate user1
    vm.startPrank(user2);

    // user1 borrows 50 tokenA, and close factor is 0.5, so user2 can liquidate $50 * 0.5 = $25 tokenA
    uint256 liquidateAmount = 25 * 10**tokenA.decimals();
    tokenA.approve(address(cTokenA), liquidateAmount);
    uint256 liquidateResult = cTokenA.liquidateBorrow(address(user1), liquidateAmount, CToken(address(cTokenB)));
    require(liquidateResult == 0, "Liquidate failed");

    // get shortfall for user1 after user2 liquidates
    // after liquidate user1's debt becomes $25 tokenA, and the liquidation incentive for user2 is $25 * 1.08 = $27
    // user1's tokenB value will be $100 - $27 = $73, and since collateral factor is 0.3 now
    // user1 can only borrow $73 * 0.3 = $22 (it rounds) tokenA, so user1 still has shortfall: $25 - $22 = $3
    (,, uint256 shortfallAfterLiquidate) = proxiedComptroller.getAccountLiquidity(address(user1));
    assertEq(shortfallAfterLiquidate, 3);

    vm.stopPrank();
  }

  function testPriceChangeLiquidation() public {
    // let cTokenA has tokenA to borrow
    deal(address(tokenA), address(cTokenA), 10000 * 10**tokenA.decimals());

    // Prepare the debts for user1
    vm.startPrank(user1);

    // mint cTokenB
    uint256 mintAmount = 1 * 10**tokenB.decimals();
    tokenB.approve(address(cTokenB), mintAmount);
    uint256 mintResult = cTokenB.mint(mintAmount);
    require(mintResult == 0, "Mint failed");
    require(cTokenB.balanceOf(address(user1)) == mintAmount, "Mint amount is not correct");

    // collateralize cTokenB
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(cTokenB);
    proxiedComptroller.enterMarkets(cTokens);

    // make sure cTokenB is been collateral
    CToken[] memory assetsIn = proxiedComptroller.getAssetsIn(address(user1));
    require(address(assetsIn[0]) == address(cTokenB), "assetsIn is not correct");

    // get account liquidity for user1
    (,uint256 initialLiquidity,) = proxiedComptroller.getAccountLiquidity(address(user1));

    // borrow tokenA
    uint256 borrowAmount = 50 * 10**tokenA.decimals();
    uint256 borrowResult = cTokenA.borrow(borrowAmount);
    require(borrowResult == 0, "Borrow failed");

    // get account liquidity for user1 after borrow
    (,uint256 liquidityAfterBorrow,) = proxiedComptroller.getAccountLiquidity(address(user1));
    require(tokenA.balanceOf(address(user1)) == initialBalanceA + borrowAmount, "borrowAmount is not correct");
    require(liquidityAfterBorrow == 0, "liquidityAfterBorrow is not correct after borrow");

    vm.stopPrank();
    // Finish preparation

    // decrease price
    priceOracle.setUnderlyingPrice(CToken(address(cTokenB)), 70);

    // get shortfall for user1 after collateral factor decrease
    // user1 borrows $50 tokenA, and price is now $70, so user1's shortfall is $50 - ($70 * 0.3) = $15
    (,, uint256 shortfall) = proxiedComptroller.getAccountLiquidity(address(user1));
    assertEq(shortfall, 15);

    // user2 will liquidate user1
    vm.startPrank(user2);

    // user1 borrows 50 tokenA, and close factor is 0.5, so user2 can liquidate $50 * 0.5 = $25 tokenA
    uint256 liquidateAmount = 25 * 10**tokenA.decimals();
    tokenA.approve(address(cTokenA), liquidateAmount);
    uint256 liquidateResult = cTokenA.liquidateBorrow(address(user1), liquidateAmount, CToken(address(cTokenB)));
    require(liquidateResult == 0, "Liquidate failed");

    // get shortfall for user1 after user2 liquidates
    // after liquidate user1's debt becomes $25 tokenA, and the liquidation incentive for user2 is $25*1.08 = $27
    // user1's tokenB value will be $70 - $27 = $43, the allowed borrow amount becomes $43 * 0.5 = $22 (it rounds)
    // so user1 still has shortfall $25 - $22 = $3
    (,, uint256 shortfallAfterLiquidate) = proxiedComptroller.getAccountLiquidity(address(user1));
    console.log("shortfallAfterLiquidate: ", shortfallAfterLiquidate);
    assertEq(shortfallAfterLiquidate, 3);

    vm.stopPrank();
  }
}
