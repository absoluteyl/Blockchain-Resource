// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISimpleSwap } from "./interface/ISimpleSwap.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SimpleSwap is ISimpleSwap, ERC20 {
    address public tokenA;
    address public tokenB;

    uint112 private reserveA;
    uint112 private reserveB;

    constructor(address _tokenA, address _tokenB)
        ERC20("SimpleSwap", "SSWAP")
    {
        // tokenA and tokenB should be contracts
        require(_isContract(_tokenA), "SimpleSwap: TOKENA_IS_NOT_CONTRACT");
        require(_isContract(_tokenB), "SimpleSwap: TOKENB_IS_NOT_CONTRACT");
        // tokenA and tokenB should be different
        require(_tokenA != _tokenB, "SimpleSwap: TOKENA_TOKENB_IDENTICAL_ADDRESS");
        // sort
        (tokenA, tokenB) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
    }

    /// @notice Add liquidity to the pool
    /// @param amountAIn The amount of tokenA to add
    /// @param amountBIn The amount of tokenB to add
    /// @return amountA The actually amount of tokenA added
    /// @return amountB The actually amount of tokenB added
    /// @return liquidity The amount of liquidity minted
    function addLiquidity(
        uint256 amountAIn,
        uint256 amountBIn
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity){
        reserveA += uint112(amountAIn);
        reserveB += uint112(amountBIn);
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

    function _isContract(address _addr) private returns (bool){
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
}
