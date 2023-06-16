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

  ERC20 public tokenB;
  string public tokenBName = "TokenB";
  string public tokenBSymbol = "TB";

  // cTokens
  CErc20Delegate public cErc20Delegate;

  // cToken Delegator
  CErc20Delegator public cTokenA;
  string public cTokenAName = "Compound TokenA";
  string public cTokenASymbol = "cTA";
  uint8 public cTokenADecimals = 18;

  CErc20Delegator public cTokenB;
  string public cTokenBName = "Compound TokenB";
  string public cTokenBSymbol = "cTB";
  uint8 public cTokenBDecimals = 18;

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
    tokenB = new ERC20(tokenBName, tokenBSymbol);

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

    cTokenB = new CErc20Delegator(
      address(tokenB),
      proxiedComptroller,
      interestRateModel,
      initialExchangeRateMantissa,
      cTokenBName,
      cTokenBSymbol,
      cTokenBDecimals,
      payable(admin),
      address(cErc20Delegate),
      new bytes(0)
    );

    // support cTokens to market
    _result = proxiedComptroller._supportMarket(CToken(address(cTokenA)));
    require(_result == 0, "Error setting support market for cTokenA");

    _result = proxiedComptroller._supportMarket(CToken(address(cTokenB)));
    require(_result == 0, "Error setting support market for cTokenB");

    // set Price for underlying tokens
    priceOracle.setUnderlyingPrice(CToken(address(cTokenA)), 1e18);
    priceOracle.setUnderlyingPrice(CToken(address(cTokenB)), 100e18);

    // set cTokenB collateral factor
    _result = proxiedComptroller._setCollateralFactor(CToken(address(cTokenB)), 0.5e18);
    require(_result == 0, "Error setting collateral factor for cTokenB");

    vm.label(address(comptroller), "comptroller");
    vm.label(address(unitroller), "unitroller");
    vm.label(address(interestRateModel), "interestRateModel");
    vm.label(address(cErc20Delegate), "cErc20Delegate");
    vm.label(address(priceOracle), "priceOracle");
    vm.label(address(tokenA), "tokenA");
    vm.label(address(tokenB), "tokenB");
    vm.label(address(cTokenA), "cTokenA");
    vm.label(address(cTokenB), "cTokenB");
  }
}
