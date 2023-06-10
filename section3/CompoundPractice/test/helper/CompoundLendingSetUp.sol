// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";

import { Comptroller } from "compound-protocol/contracts/Comptroller.sol";
import { ComptrollerInterface } from "compound-protocol/contracts/ComptrollerInterface.sol";
import { Unitroller } from "compound-protocol/contracts/Unitroller.sol";

import { WhitePaperInterestRateModel } from "compound-protocol/contracts/WhitePaperInterestRateModel.sol";

import { CErc20Delegate, CToken } from "compound-protocol/contracts/CErc20Delegate.sol";
import { CErc20Delegator } from "compound-protocol/contracts/CErc20Delegator.sol";

import { SimplePriceOracle } from "compound-protocol/contracts/SimplePriceOracle.sol";

contract CompoundLendingSetUp is Test {
  // Comptroller
  Comptroller public comptroller;
  Comptroller public proxiedComptroller;

  // Unitroller
  Unitroller public unitroller;

  // Comptroller Params
  uint256 public liquidationIncentive = 1.08e18;
  uint256 public closeFactorMantissa = 0.5e18;
  SimplePriceOracle public priceOracle;

  // Interest Rate Model
  WhitePaperInterestRateModel public interestRateModel;
  uint256 public baseRatePerYear = 0;
  uint256 public multiplierPerYear = 0;

  // Initial Exchange Rate
  uint256 public initialExchangeRateMantissa = 1e18;

  // Underlaying Tokens
  ERC20 public tokenA;
  string public tokenAName = "TokenA";
  string public tokenASymbol = "TA";

  // cTokens
  CErc20Delegate public cErc20Delegate;

  // cToken Delegator
  CErc20Delegator public cTokenA;
  string public cTokenAName = "Compound TokenA";
  string public cTokenASymbol = "cTA";
  uint8 public cTokenADecimals = 18;

  address public admin;

  function setUp() public virtual {
    admin = makeAddr("admin");

    // deploy price oracle
    priceOracle = new SimplePriceOracle();

    // deploy comptroller and unitroller
    comptroller = new Comptroller();
    unitroller = new Unitroller();
    uint _result = unitroller._setPendingImplementation(address(comptroller));
    require(_result == 0, "Error setting unitroller pending implementation");
    comptroller._become(unitroller);
    proxiedComptroller = Comptroller(address(unitroller));

    // set liquidation incentive（清算獎勵）
    _result = proxiedComptroller._setLiquidationIncentive(liquidationIncentive);
    require(_result == 0, "Error setting liquidation incentive");

    // set close factor（清算係數）
    _result = proxiedComptroller._setCloseFactor(closeFactorMantissa);
    require(_result == 0, "Error setting close factor");

    // set price oracle
    _result = proxiedComptroller._setPriceOracle(priceOracle);
    require(_result == 0, "Error setting price oracle");

    // deploy interest rate model
    interestRateModel = new WhitePaperInterestRateModel(baseRatePerYear, multiplierPerYear);

    // deploy underlying tokens
    tokenA = new ERC20(tokenAName, tokenASymbol);

    // deploy cErc20Delegate
    cErc20Delegate = new CErc20Delegate();

    // deploy cTokens
    cTokenA = new CErc20Delegator(
      address(tokenA),
      proxiedComptroller,
      interestRateModel,
      initialExchangeRateMantissa,
      cTokenAName,
      cTokenASymbol,
      cTokenADecimals,
      payable(admin),
      address(cErc20Delegate),
      new bytes(0)
    );

    // support cTokens to market
    _result = proxiedComptroller._supportMarket(CToken(address(cTokenA)));
    require(_result == 0, "Error setting support market for cTokenA");

    vm.label(address(comptroller), "comptroller");
    vm.label(address(unitroller), "unitroller");
    vm.label(address(interestRateModel), "interestRateModel");
    vm.label(address(cErc20Delegate), "cErc20Delegate");
    vm.label(address(priceOracle), "priceOracle");
    vm.label(address(tokenA), "tokenA");
    vm.label(address(cTokenA), "cTokenA");
  }
}
