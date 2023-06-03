// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { Comptroller } from "compound-protocol/contracts/Comptroller.sol";
import { ComptrollerInterface } from "compound-protocol/contracts/ComptrollerInterface.sol";
import { WhitePaperInterestRateModel } from "compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import { InterestRateModel } from "compound-protocol/contracts/InterestRateModel.sol";
import { CErc20Delegate } from "compound-protocol/contracts/CErc20Delegate.sol";
import { CErc20Delegator } from "compound-protocol/contracts/CErc20Delegator.sol";

contract CompoundScript is Script {
  // Underlaying Token
  string public uTokenName = "USD Coin";
  string public uTokenSymbol = "USDC";

  // Interest Rate Model
  uint256 public baseRatePerYear = 0;
  uint256 public multiplierPerYear = 0;

  // Initial Exchange Rate
  uint256 public initialExchangeRateMantissa = 1;

  // cToken
  string public cTokenName = "Compound USD Coin";
  string public cTokenSymbol = "cUSDC";
  uint8 public cTokenDecimals = 18;

  function run() external {
    vm.startBroadcast(vm.envUint("WALLET_PRIVATE_KEY"));

    console.log("\n=== Dealing with Underlaying Token ===");
    ERC20 USDC = new ERC20(uTokenName, uTokenSymbol);
    console.log("Name: %s,", USDC.name());
    console.log("Symbol: %s,", USDC.symbol());
    console.log("Decimals: %d,", USDC.decimals());
    console.log("Address: %s", address(USDC));

    console.log("\n=== Dealing with Comptroller ===");
    Comptroller comptroller = new Comptroller();
    ComptrollerInterface comptrollerInterface = ComptrollerInterface(address(comptroller));
    console.log("Address: %s", address(comptroller));

    console.log("\n=== Dealing with Interest Rate Model ===");
    InterestRateModel interestRateModel = new WhitePaperInterestRateModel(
      baseRatePerYear, multiplierPerYear
    );
    console.log("Address: %s", address(interestRateModel));

    console.log("\n=== Dealing with CERC20 Delegate ===");
    CErc20Delegate cErc20Delegate = new CErc20Delegate();
    console.log("Address: %s", address(cErc20Delegate));

    console.log("\n=== Dealing with CERC20 Delegator ===");
    CErc20Delegator cUSDC = new CErc20Delegator(
        address(USDC), // address underlying_,
        comptrollerInterface, // ComptrollerInterface comptroller_,
        interestRateModel, // InterestRateModel interestRateModel_,
        initialExchangeRateMantissa, // uint initialExchangeRateMantissa_,
        cTokenName, // string memory name_,
        cTokenSymbol, // string memory symbol_,
        cTokenDecimals, // uint8 decimals_,
        payable(address(msg.sender)), // address payable admin_,
        address(cErc20Delegate), // address implementation_,
        new bytes(0) // bytes memory becomeImplementationData
    );
    console.log("Address: %s", address(cUSDC));

    vm.stopBroadcast();
  }
}
