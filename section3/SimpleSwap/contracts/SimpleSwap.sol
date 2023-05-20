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
        // tokenA and tokenB should be contracts
        require(isContract(_tokenA), "SimpleSwap: TOKENA_IS_NOT_CONTRACT");
        require(isContract(_tokenB), "SimpleSwap: TOKENB_IS_NOT_CONTRACT");
        // tokenA and tokenB should be different
        require(_tokenA != _tokenB, "SimpleSwap: TOKENA_TOKENB_IDENTICAL_ADDRESS");
        // sort
        (tokenA, tokenB) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
    }

    /// @notice Get the reserves of the pool
    /// @return _reserveA The reserve of tokenA
    /// @return _reserveB The reserve of tokenB
    function getReserves() external view returns (uint256 _reserveA, uint256 _reserveB){
        _reserveA = reserveA;
        _reserveB = reserveB;
    }

    /// @notice Get the address of tokenA
    /// @return _tokenA The address of tokenA
    function getTokenA() external view returns (address _tokenA){
        _tokenA = tokenA;
    }

    /// @notice Get the address of tokenB
    /// @return _tokenB The address of tokenB
    function getTokenB() external view returns (address _tokenB){
        _tokenB = tokenB;
    }

    function isContract(address _addr) private returns (bool isContract){
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
}
