// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { IUniswapV2Router01 } from "v2-periphery/interfaces/IUniswapV2Router01.sol";
import { IUniswapV2Factory } from "v2-core/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "v2-core/interfaces/IUniswapV2Pair.sol";
import { TestERC20 } from "../contracts/test/TestERC20.sol";

contract UniswapV2PracticeTest is Test {
    IUniswapV2Router01 public constant UNISWAP_V2_ROUTER =
        IUniswapV2Router01(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IUniswapV2Factory public constant UNISWAP_V2_FACTORY =
        IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    address public constant WETH9 = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    TestERC20 public testUSDC;
    IUniswapV2Pair public WETHTestUSDCPair;
    address public taker = makeAddr("Taker");
    address public maker = makeAddr("Maker");

    function setUp() public {
        // fork block
        vm.createSelectFork("mainnet", 17254242);

        // deploy test USDC
        testUSDC = _create_erc20("Test USDC", "USDC", 6);

        // mint 100 ETH, 10000 USDC to maker
        deal(maker, 100 ether);
        testUSDC.mint(maker, 10000 * 10 ** testUSDC.decimals());

        // mint 100 ETH to taker
        deal(taker, 100 ether);

        // create ETH/USDC pair
        WETHTestUSDCPair = IUniswapV2Pair(UNISWAP_V2_FACTORY.createPair(address(WETH9), address(testUSDC)));

        vm.label(address(UNISWAP_V2_ROUTER), "UNISWAP_V2_ROUTER");
        vm.label(address(UNISWAP_V2_FACTORY), "UNISWAP_V2_FACTORY");
        vm.label(address(WETH9), "WETH9");
        vm.label(address(testUSDC), "TestUSDC");
    }

    modifier addLiquidityForMaker() {
        vm.startPrank(maker);
        testUSDC.approve(address(UNISWAP_V2_ROUTER), 10000 * 10 ** testUSDC.decimals());
        (uint amountA, uint amountB, uint liquid) = UNISWAP_V2_ROUTER.addLiquidityETH{ value: 100 ether }(
            address(testUSDC),
            10000 * 10 ** testUSDC.decimals(),
            0,
            0,
            address(maker),
            block.timestamp + 100
        );
        vm.stopPrank();
        _;
    }

    // # Practice 1: maker add liquidity (100 ETH, 10000 USDC)
    function test_maker_addLiquidityETH() public addLiquidityForMaker {
        // add liquidity part is implemented in modifier
        // Checking
        IUniswapV2Pair wethUsdcPair = IUniswapV2Pair(UNISWAP_V2_FACTORY.getPair(address(WETH9), address(testUSDC)));
        (uint112 reserve0, uint112 reserve1, ) = wethUsdcPair.getReserves();
        assertEq(reserve0, 10000 * 10 ** testUSDC.decimals());
        assertEq(reserve1, 100 ether);
    }

    // # Practice 2: taker swap exact 100 ETH for testUSDC
    function test_taker_swapExactETHForTokens() public addLiquidityForMaker {
        // Set path
        address[] memory path = new address[](2);
        path[0] = address(WETH9);
        path[1] = address(testUSDC);

        vm.prank(taker);
        UNISWAP_V2_ROUTER.swapExactETHForTokens{ value: 100 ether }(
            0,
            path,
            address(taker),
            block.timestamp + 100
        );

        // Checking
        // # Disscussion 1: discuss why 4992488733 ?
        // input token 要扣 0.3％ 的 fee
        // (100 + 100 * (1-0.3%)) * (10,000 - x') = 100 * 10,000
        // => x' = 4992488733
        assertEq(testUSDC.balanceOf(taker), 4992488733);
        assertEq(taker.balance, 0);
    }

    // # Practice 3: taker swap exact 10000 USDC for ETH
    function test_taker_swapExactTokensForETH() public addLiquidityForMaker {
        // Give 10000USDC for taker
        testUSDC.mint(taker, 10000 * 10 ** testUSDC.decimals());

        // Set path
        address[] memory path = new address[](2);
        path[0] = address(testUSDC);
        path[1] = address(WETH9);

        vm.startPrank(taker);
        testUSDC.approve(address(UNISWAP_V2_ROUTER), 10000 * 10 ** testUSDC.decimals());
        UNISWAP_V2_ROUTER.swapExactTokensForETH(
            10000 * 10 ** testUSDC.decimals(),
            0,
            path,
            address(taker),
            block.timestamp + 100
        );
        vm.stopPrank();

        // Checking
        // # Disscussion 2: original balance is 100 ether, so delta is 49924887330996494742, but why ?
        // input token 要扣 0.3％ 的 fee
        // (100 - y') * (10,000 + (10,000 * 99.7%)) = 100 * 10,000
        // => y' = 49924887330996494742 (decimals of ether is 18)
        assertEq(testUSDC.balanceOf(taker), 0);
        assertEq(taker.balance, 149924887330996494742);
    }

    // # Practice 4: maker remove all liquidity
    function test_maker_removeLiquidityETH() public {
        vm.startPrank(maker);
        // Add Liquidity and get liquidity value
        testUSDC.approve(address(UNISWAP_V2_ROUTER), 10000 * 10 ** testUSDC.decimals());
        (,, uint liquidity) = UNISWAP_V2_ROUTER.addLiquidityETH{ value: 100 ether }(
            address(testUSDC),
            10000 * 10 ** testUSDC.decimals(),
            0,
            0,
            address(maker),
            block.timestamp + 100
        );

        // Approve router to transfer liquidity for maker
        WETHTestUSDCPair.approve(address(UNISWAP_V2_ROUTER), liquidity);
        UNISWAP_V2_ROUTER.removeLiquidityETH(
            address(testUSDC),
            liquidity,
            0,
            0,
            maker,
            block.timestamp + 100
        );
        vm.stopPrank();

        // Checking
        IUniswapV2Pair wethUsdcPair = IUniswapV2Pair(UNISWAP_V2_FACTORY.getPair(address(WETH9), address(testUSDC)));
        (uint112 reserve0, uint112 reserve1, ) = wethUsdcPair.getReserves();
        assertEq(reserve0, 1);
        assertEq(reserve1, 100000000);
    }

    function _create_erc20(string memory name, string memory symbol, uint8 decimals) internal returns (TestERC20) {
        TestERC20 testERC20 = new TestERC20(name, symbol, decimals);
        return testERC20;
    }
}
