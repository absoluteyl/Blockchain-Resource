// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";

import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";

import { Comptroller } from "compound-protocol/contracts/Comptroller.sol";
import { ComptrollerInterface } from "compound-protocol/contracts/ComptrollerInterface.sol";
import { Unitroller } from "compound-protocol/contracts/Unitroller.sol";

import { WhitePaperInterestRateModel } from "compound-protocol/contracts/WhitePaperInterestRateModel.sol";

import { CErc20Delegate, CToken } from "compound-protocol/contracts/CErc20Delegate.sol";
import { CErc20Delegator } from "compound-protocol/contracts/CErc20Delegator.sol";

import { SimplePriceOracle } from "compound-protocol/contracts/SimplePriceOracle.sol";

contract CompoundScript is Script {
  // Underlaying Token
  ERC20 public uToken;
  string public uTokenName = "USD Coin";
  string public uTokenSymbol = "USDC";

  // Comptroller
  Comptroller public comptroller;
  Comptroller public proxiedComptroller;

  // Unitroller
  Unitroller public unitroller;

  // Interest Rate Model
  WhitePaperInterestRateModel public interestRateModel;
  uint256 public baseRatePerYear = 0;
  uint256 public multiplierPerYear = 0;

  // Initial Exchange Rate
  uint256 public initialExchangeRateMantissa = 1e18;

  // cToken
  CErc20Delegate public cErc20Delegate;
  string public cTokenName = "Compound USD Coin";
  string public cTokenSymbol = "cUSDC";
  uint8 public cTokenDecimals = 18;

  // cToken Delegator
  CErc20Delegator public cToken;

  // Comptroller Params
  uint256 public liquidationIncentive = 1e18;
  uint256 public closeFactorMantissa = 0.5e18;
  SimplePriceOracle public priceOracle;

  // result to be reused for status check
  uint256 private _result;

  function run() external {
    vm.startBroadcast(vm.envUint("WALLET_PRIVATE_KEY"));
    _deployUnderlyingToken();

    _deployComptroller();
    _deployUnitroller();
    _dealUnitrollerImplementation();

    _deployInterestRateModel();

    _deployCTokenDelegate();
    _deployCTokenDelegator();

    _deployPriceOracle();
    _configureComptroller();

    vm.stopBroadcast();
  }


  /*
  =====================
  = Private Functions =
  =====================
  */
  function _deployUnderlyingToken() private {
    uToken = new ERC20(uTokenName, uTokenSymbol);
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
  }

  function _deployInterestRateModel() private {
    interestRateModel = new WhitePaperInterestRateModel(
      baseRatePerYear, multiplierPerYear
    );
  }

  function _deployPriceOracle() private {
    priceOracle = new SimplePriceOracle();
  }

  function _deployCTokenDelegate() private {
    cErc20Delegate = new CErc20Delegate();
  }

  function _deployCTokenDelegator() private {
    cToken = new CErc20Delegator(
        address(uToken),              // underlying token
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

  function _configureComptroller() private {
    // set liquidation incentive（清算獎勵）
    _result = proxiedComptroller._setLiquidationIncentive(liquidationIncentive);
    require(_result == 0, "Error setting liquidation incentive");

    // set close factor（清算係數）
    _result = proxiedComptroller._setCloseFactor(closeFactorMantissa);
    require(_result == 0, "Error setting close factor");

    // set price oracle
    _result = proxiedComptroller._setPriceOracle(priceOracle);
    require(_result == 0, "Error setting price oracle");
  }
}
