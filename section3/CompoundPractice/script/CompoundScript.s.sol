// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { SimplePriceOracle } from "compound-protocol/contracts/SimplePriceOracle.sol";
import { PriceOracle } from "compound-protocol/contracts/PriceOracle.sol";
import { Comptroller } from "compound-protocol/contracts/Comptroller.sol";
import { ComptrollerInterface } from "compound-protocol/contracts/ComptrollerInterface.sol";
import { Unitroller } from "compound-protocol/contracts/Unitroller.sol";
import { WhitePaperInterestRateModel } from "compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import { InterestRateModel } from "compound-protocol/contracts/InterestRateModel.sol";
import { CErc20Delegate } from "compound-protocol/contracts/CErc20Delegate.sol";
import { CErc20Delegator } from "compound-protocol/contracts/CErc20Delegator.sol";

contract CompoundScript is Script {
  // Underlaying Token
  string public uTokenName = "USD Coin";
  string public uTokenSymbol = "USDC";

  // Close Factor
  uint256 public closeFactorMantissa = 0.5e18;

  // Interest Rate Model
  uint256 public baseRatePerYear = 0;
  uint256 public multiplierPerYear = 0;

  // Initial Exchange Rate
  uint256 public initialExchangeRateMantissa = 1;

  // cToken
  string public cTokenName = "Compound USD Coin";
  string public cTokenSymbol = "cUSDC";
  uint8 public cTokenDecimals = 18;

  // result to be reused for status check
  uint256 private _result;

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
    console.log("Address: %s", address(comptroller));

    console.log("\n=== Deploying Unitroller ===");
    Unitroller unitroller = new Unitroller();
    console.log("Address: %s", address(unitroller));

    console.log("\n=== Dealing with Unitroller implementation ===");
    // set implementation
    _result = unitroller._setPendingImplementation(address(comptroller));
    require(_result == 0, "Error setting unitroller pending implementation");
    comptroller._become(unitroller);
    Comptroller proxiedComptroller = Comptroller(address(unitroller));
    // set close factor
    _result = proxiedComptroller._setCloseFactor(closeFactorMantissa);
    require(_result == 0, "Error setting close factor");
    // set price oracle
    _result = proxiedComptroller._setPriceOracle(priceOracle);
    require(_result == 0, "Error setting price oracle");

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
