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

contract FlashLoanPracticeSetUp is Test {
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
  uint256 public initialExchangeRateMantissaUSDC = 1e6;
  uint256 public initialExchangeRateMantissaUNI = 1e18;

  // Underlaying Tokens
  ERC20 constant USDC = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
  ERC20 constant UNI = ERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);

  // cTokens
  CErc20Delegate public cErc20Delegate;

  // cToken Delegator
  CErc20Delegator public cUSDC;
  string public cUSDCName = "Compound USDC";
  string public cUSDCSymbol = "cUSDC";
  uint8 public cUSDCDecimals = 18;

  CErc20Delegator public cUNI;
  string public cUNIName = "Compound UNI";
  string public cUNISymbol = "cUNI";
  uint8 public cUNIDecimals = 18;

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

    // deploy cErc20Delegate
    cErc20Delegate = new CErc20Delegate();

    // deploy cTokens
    cUSDC = new CErc20Delegator(
      address(USDC),
      proxiedComptroller,
      interestRateModel,
      initialExchangeRateMantissaUSDC,
      cUSDCName,
      cUSDCSymbol,
      cUSDCDecimals,
      payable(admin),
      address(cErc20Delegate),
      new bytes(0)
    );

    cUNI = new CErc20Delegator(
      address(UNI),
      proxiedComptroller,
      interestRateModel,
      initialExchangeRateMantissaUNI,
      cUNIName,
      cUNISymbol,
      cUNIDecimals,
      payable(admin),
      address(cErc20Delegate),
      new bytes(0)
    );

    // support cTokens to market
    _result = proxiedComptroller._supportMarket(CToken(address(cUSDC)));
    require(_result == 0, "Error setting support market for cUSDC");

    _result = proxiedComptroller._supportMarket(CToken(address(cUNI)));
    require(_result == 0, "Error setting support market for cUNI");

    // set Price for underlying tokens
    priceOracle.setUnderlyingPrice(CToken(address(cUSDC)), 1 * 10**(18 + (18-6))); // USDC decimals is 6, but cUSDC decimals is 18
    priceOracle.setUnderlyingPrice(CToken(address(cUNI)), 5e18);

    // set cUNI collateral factor
    _result = proxiedComptroller._setCollateralFactor(CToken(address(cUNI)), 0.5e18);
    require(_result == 0, "Error setting collateral factor for cUNI");

    vm.label(address(comptroller), "comptroller");
    vm.label(address(unitroller), "unitroller");
    vm.label(address(interestRateModel), "interestRateModel");
    vm.label(address(cErc20Delegate), "cErc20Delegate");
    vm.label(address(priceOracle), "priceOracle");
    vm.label(address(USDC), "USDC");
    vm.label(address(UNI), "UNI");
    vm.label(address(cUSDC), "cUSDC");
    vm.label(address(cUNI), "cUNI");
  }

  function testCompoundDeploy() public {
    require(address(comptroller) != address(0), "comptroller is not deployed");
    require(address(unitroller) != address(0), "unitroller is not deployed");
    require(address(interestRateModel) != address(0), "interestRateModel is not deployed");
    require(address(cErc20Delegate) != address(0), "cErc20Delegate is not deployed");
    require(address(priceOracle) != address(0), "priceOracle is not deployed");

    require(address(cUSDC) != address(0), "cUSDC is not deployed");
    require(address(cUNI) != address(0), "cUNI is not deployed");
  }
}
