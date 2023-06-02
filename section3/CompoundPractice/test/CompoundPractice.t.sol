// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { EIP20Interface } from "compound-protocol/contracts/EIP20Interface.sol";
import { CErc20 } from "compound-protocol/contracts/CErc20.sol";
import "test/helper/CompoundPracticeSetUp.sol";

interface IBorrower {
  function borrow() external;
}

contract CompoundPracticeTest is CompoundPracticeSetUp {
  EIP20Interface public USDC = EIP20Interface(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
  CErc20 public cUSDC = CErc20(0x39AA39c021dfbaE8faC545936693aC917d5E7563);

  uint256 public forkId;
  address public user;
  uint256 public initialBalance;

  IBorrower public borrower;

  function setUp() public override {
    // Fork ethereum mainnet
    forkId = vm.createFork(vm.rpcUrl("mainnet"));
    vm.selectFork(forkId);
    // instead of forking in setup, we can also use `--fork-url mainnet` in forge test command.

    super.setUp();

    // Deployed in CompoundPracticeSetUp helper
    borrower = IBorrower(borrowerAddress);

    user = makeAddr("User");

    initialBalance = 10000 * 10 ** USDC.decimals();
    deal(address(USDC), user, initialBalance);

    vm.label(address(cUSDC), "cUSDC");
    vm.label(borrowerAddress, "Borrower");
  }

  function test_compound_mint_interest() public {
    vm.startPrank(user);

    // TODO: 1. Mint some cUSDC with USDC
    console.log(USDC.balanceOf(address(user)));
    USDC.approve(address(cUSDC), 100 * 10 ** USDC.decimals());
    uint256 mintResult = cUSDC.mint(100 * 10 ** USDC.decimals());
    require(mintResult == 0, "Mint failed");

    // TODO: 2. Modify block state to generate interest
    vm.roll(block.number + 100);

    // TODO: 3. Redeem and check the redeemed amount
    uint256 redeemResult = cUSDC.redeem(cUSDC.balanceOf(address(user)));
    require(redeemResult == 0, "Redeem failed");
    console.log(USDC.balanceOf(address(user)));
    assertGt(USDC.balanceOf(address(user)), initialBalance);
  }

  function test_compound_mint_interest_with_borrower() public {
    vm.startPrank(user);

    // TODO: 1. Mint some cUSDC with USDC
    console.log(USDC.balanceOf(address(user)));
    USDC.approve(address(cUSDC), 100 * 10 ** USDC.decimals());
    uint256 mintResult = cUSDC.mint(100 * 10 ** USDC.decimals());
    require(mintResult == 0, "Mint failed");

    // 2. Borrower.borrow() will borrow some USDC
    borrower.borrow();

    // TODO: 3. Modify block state to generate interest
    vm.roll(block.number + 100);

    // TODO: 4. Redeem and check the redeemed amount
    uint256 redeemResult = cUSDC.redeem(cUSDC.balanceOf(address(user)));
    require(redeemResult == 0, "Redeem failed");
    console.log(USDC.balanceOf(address(user)));
    assertGt(USDC.balanceOf(address(user)), initialBalance);
  }
}
