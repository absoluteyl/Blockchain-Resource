// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { SimplePriceOracle } from "compound-protocol/contracts/SimplePriceOracle.sol";
import { PriceOracle } from "compound-protocol/contracts/PriceOracle.sol";
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

    console.log("\n=== Deploying Underlaying Token ===");
    ERC20 USDC = new ERC20(uTokenName, uTokenSymbol);
    console.log("Name: %s,", USDC.name());
    console.log("Symbol: %s,", USDC.symbol());
    console.log("Decimals: %d,", USDC.decimals());
    console.log("Address: %s", address(USDC));

    console.log("\n=== Deploying Price Oracle ===");
    PriceOracle priceOracle = new SimplePriceOracle();
    console.log("Address: %s", address(priceOracle));

    console.log("\n=== Deploying Comptroller ===");
    Comptroller comptroller = new Comptroller();
    ComptrollerInterface comptrollerInterface = ComptrollerInterface(address(comptroller));
    comptroller._setPriceOracle(priceOracle);
    console.log("Address: %s", address(comptroller));

    console.log("\n=== Deploying Interest Rate Model ===");
    InterestRateModel interestRateModel = new WhitePaperInterestRateModel(
      baseRatePerYear, multiplierPerYear
    );
    console.log("Address: %s", address(interestRateModel));

    console.log("\n=== Deploying CERC20 Delegate ===");
    CErc20Delegate cErc20Delegate = new CErc20Delegate();
    console.log("Address: %s", address(cErc20Delegate));

    console.log("\n=== Deploying CERC20 Delegator ===");
    CErc20Delegator cUSDC = new CErc20Delegator(
        address(USDC),                // underlying token
        proxiedComptroller,           // comptroller
        interestRateModel,            // interestRateModel
        initialExchangeRateMantissa,  // initialExchangeRateMantissa
        cTokenName,                   // cToken name
        cTokenSymbol,                 // cToken symbol
        cTokenDecimals,               // cToken decimals
        payable(address(msg.sender)), // admin
        address(cErc20Delegate),      // CERC20 Delegate implementation,
        new bytes(0)                  // becomeImplementationData
    );
    console.log("Address: %s", address(cUSDC));

    vm.stopBroadcast();
  }
}
