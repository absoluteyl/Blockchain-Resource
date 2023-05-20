// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISimpleSwap } from "./interface/ISimpleSwap.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SimpleSwap is ISimpleSwap, ERC20 {
    address public tokenA;
    address public tokenB;

    uint112 private reserveA;
    uint112 private reserveB;

    constructor(address _tokenA, address _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    /// @notice Get the reserves of the pool
    /// @return _reserveA The reserve of tokenA
    /// @return _reserveB The reserve of tokenB
    function getReserves() external view returns (uint256 _reserveA, uint256 _reserveB){
        _reserveA = reserveA;
        _reserveB = reserveB;
    }
}
