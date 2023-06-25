// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "test/helper/FlashLoanPracticeSetUp.sol";
import "src/FlashLoanReceiver.sol";

contract FlashLoanPractice is FlashLoanPracticeSetUp {
  address public user1;
  address public user2;

  uint256 public initialUNIBalance;

  FlashLoanReceiver public flashLoanReceiver;

  function setUp() public override {

    string memory rpc = vm.envString("MAINNET_RPC_URL");
    vm.createSelectFork(rpc, 17_465_000);

    super.setUp();

    flashLoanReceiver = new FlashLoanReceiver();

    user1 = makeAddr("user1");
    user2 = makeAddr("user2");

    initialUNIBalance = 1000 * 10**UNI.decimals();

    deal(address(USDC), address(cUSDC), 10_000 * 10**USDC.decimals());
    deal(address(UNI), user1, initialUNIBalance);
  }

  function testFlashLoanLiquidate() public {
    // User1 collateralize 1000 UNI and borrow 2500 USDC
    vm.startPrank(user1);

    // mint uUNI
    UNI.approve(address(cUNI), initialUNIBalance);
    uint256 mintResult = cUNI.mint(initialUNIBalance);
    // check mint result
    require(mintResult == 0, "mint failed");
    require(cUNI.balanceOf(user1) == initialUNIBalance, "mint amount is not correct");

    // collateral cUNI
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(cUNI);
    proxiedComptroller.enterMarkets(cTokens);
    // check collateral result
    CToken[] memory assetsIn = proxiedComptroller.getAssetsIn(address(user1));
    require(address(assetsIn[0]) == address(cUNI), "assetsIn is not correct");

    // borrow USDC
    uint256 borrowAmount = 2500 * 10**USDC.decimals();
    uint256 borrowResult = cUSDC.borrow(borrowAmount);
    require(borrowResult == 0, "borrow failed");
    require(USDC.balanceOf(user1) == borrowAmount, "borrow amount is not correct");

    vm.stopPrank();

    // Price of UNI goes down to $4
    priceOracle.setUnderlyingPrice(CToken(address(cUNI)), 4e18);
    require(priceOracle.getUnderlyingPrice(CToken(address(cUNI))) == 4e18, "price is not correct");

    // Check shortfall for user1
    (,, uint256 shortfallAfterPriceChange) = proxiedComptroller.getAccountLiquidity(address(user1));
    require(shortfallAfterPriceChange > 0, "shortfall is not correct");

    // Calculate liquidate amount for user2
    uint256 borrowBalance = cUSDC.borrowBalanceCurrent(address(user1));
    uint256 liquidateAmount = borrowBalance * closeFactorMantissa / 1e18;

    // User2 liquidate user1's position
    vm.startPrank(user2);
    bytes memory receiverData = abi.encode(
      address(user1),
      cUSDC,
      cUNI,
      address(UNI)
    );
    flashLoanReceiver.loanAndRepay(address(USDC), liquidateAmount, receiverData);
    vm.stopPrank();

    // Profit should greater than $63 USDC
    assertGe(USDC.balanceOf(address(flashLoanReceiver)), 63 * 10**USDC.decimals());
  }
}
