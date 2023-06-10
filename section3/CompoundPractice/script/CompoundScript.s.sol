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
  ERC20 public USDC;
  string public uTokenName = "USD Coin";
  string public uTokenSymbol = "USDC";

  // Price Oracle
  PriceOracle public priceOracle;

  // Comptroller
  Comptroller public comptroller;
  Comptroller public proxiedComptroller;
  uint256 public liquidationIncentive = 1e18;
  uint256 public closeFactorMantissa = 0.5e18;

  // Unitroller
  Unitroller public unitroller;


  // Interest Rate Model
  InterestRateModel public interestRateModel;
  uint256 public baseRatePerYear = 0;
  uint256 public multiplierPerYear = 0;

  // cToken
  CErc20Delegate public cErc20Delegate;
  string public cTokenName = "Compound USD Coin";
  string public cTokenSymbol = "cUSDC";
  uint8 public cTokenDecimals = 18;

  // Initial Exchange Rate
  uint256 public initialExchangeRateMantissa = 1e18;

  // cToken Delegator
  CErc20Delegator public cUSDC;

  // result to be reused for status check
  uint256 private _result;

  function run() external {
    vm.startBroadcast(vm.envUint("WALLET_PRIVATE_KEY"));

    _deployUnderlyingToken();
    _deployPriceOracle();
    _deployComptroller();
    _deployUnitroller();
    _dealUnitrollerImplementation();
    _deployInterestRateModel();
    _deployCTokenDelegate();
    _deployCTokenDelegator();

    vm.stopBroadcast();
  }


  /*
  =====================
  = Private Functions =
  =====================
  */
  function _deployUnderlyingToken() private {
    USDC = new ERC20(uTokenName, uTokenSymbol);
  }

  function _deployPriceOracle() private {
    priceOracle = new SimplePriceOracle();
  }

  function _deployComptroller() private {
    comptroller = new Comptroller();
  }

  function _deployUnitroller() private {
    unitroller = new Unitroller();
  }

  function _dealUnitrollerImplementation() private {
    // set implementation
    _result = unitroller._setPendingImplementation(address(comptroller));
    require(_result == 0, "Error setting unitroller pending implementation");
    comptroller._become(unitroller);
    proxiedComptroller = Comptroller(address(unitroller));

    // set liquidation incentive
    _result = proxiedComptroller._setLiquidationIncentive(liquidationIncentive);
    require(_result == 0, "Error setting liquidation incentive");

    // set close factor
    _result = proxiedComptroller._setCloseFactor(closeFactorMantissa);
    require(_result == 0, "Error setting close factor");

    // set price oracle
    _result = proxiedComptroller._setPriceOracle(priceOracle);
    require(_result == 0, "Error setting price oracle");
  }

  function _deployInterestRateModel() private {
    interestRateModel = new WhitePaperInterestRateModel(
      baseRatePerYear, multiplierPerYear
    );
  }

  function _deployCTokenDelegate() private {
    CErc20Delegate cErc20Delegate = new CErc20Delegate();
  }

  function _deployCTokenDelegator() private {
    cUSDC = new CErc20Delegator(
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
  }
}
