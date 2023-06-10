// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "test/helper/CompoundLendingSetUp.sol";

contract CompoundLendingTest is CompoundLendingSetUp {

  address public user1;

  uint256 public initialBalanceA;

  function setUp() public override {
    super.setUp();

    user1 = makeAddr("user1");
    initialBalanceA = 100 * 10 ** tokenA.decimals();

    deal(address(tokenA), user1, initialBalanceA);
  }

  function testDeploy() public {
    require(address(comptroller) != address(0), "comptroller is not deployed");
    require(address(unitroller) != address(0), "unitroller is not deployed");
    require(address(interestRateModel) != address(0), "interestRateModel is not deployed");
    require(address(cErc20Delegate) != address(0), "cErc20Delegate is not deployed");
    require(address(priceOracle) != address(0), "priceOracle is not deployed");

    require(address(tokenA) != address(0), "tokenA is not deployed");
    require(address(cTokenA) != address(0), "cTokenA is not deployed");

    console.log("=== Deploy Result ===");
    console.log("comptroller: ", address(comptroller));
    console.log("unitroller: ", address(unitroller));
    console.log("interestRateModel: ", address(interestRateModel));
    console.log("cErc20Delegate: ", address(cErc20Delegate));
    console.log("priceOracle: ", address(priceOracle));
    console.log("tokenA: ", address(tokenA));
    console.log("cTokenA: ", address(cTokenA));
  }

  function testMintA() public {
    vm.startPrank(user1);

    tokenA.approve(address(cTokenA), initialBalanceA);
    uint256 mintResult = cTokenA.mint(initialBalanceA);
    require(mintResult == 0, "Mint failed");

    vm.stopPrank();

    assertEq(cTokenA.balanceOf(address(user1)), initialBalanceA);
  }

  function testRedeemA() public {
    vm.startPrank(user1);

    tokenA.approve(address(cTokenA), initialBalanceA);
    uint256 mintResult = cTokenA.mint(initialBalanceA);
    require(mintResult == 0, "Mint failed");

    uint256 redeemResult = cTokenA.redeem(cTokenA.balanceOf(address(user1)));
    require(redeemResult == 0, "Redeem failed");

    vm.stopPrank();

    assertEq(tokenA.balanceOf(address(user1)), initialBalanceA);
  }
}
