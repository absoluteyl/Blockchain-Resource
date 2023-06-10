// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "test/helper/CompoundLendingSetUp.sol";

contract CompoundLendingTest is CompoundLendingSetUp {

  address public user1;

  uint256 public initialBalanceA;
  uint256 public initialBalanceB;

  function setUp() public override {
    super.setUp();

    user1 = makeAddr("user1");
    initialBalanceA = 100 * 10 ** tokenA.decimals();
    initialBalanceB = 100 * 10 ** tokenB.decimals();

    deal(address(tokenA), user1, initialBalanceA);
    deal(address(tokenB), user1, initialBalanceB);
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
}
