// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISimpleSwap } from "./interface/ISimpleSwap.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SimpleSwap is ISimpleSwap, ERC20 {
    using SafeMath for uint;

    address public tokenA;
    address public tokenB;

    uint256 private reserveA;
    uint256 private reserveB;

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

    /// @notice Swap tokenIn for tokenOut with amountIn
    /// @param tokenIn The address of the token to swap from
    /// @param tokenOut The address of the token to swap to
    /// @param amountIn The amount of tokenIn to swap
    /// @return amountOut The amount of tokenOut received
    function swap(address tokenIn, address tokenOut, uint256 amountIn) external returns (uint256 amountOut){
        // tokenIn and tokenOut should be tokenA or tokenB
        require(tokenIn == tokenA || tokenIn == tokenB, "SimpleSwap: INVALID_TOKEN_IN");
        require(tokenOut == tokenA || tokenOut == tokenB, "SimpleSwap: INVALID_TOKEN_OUT");
        // tokenIn and tokenOut should be different
        require(tokenIn != tokenOut, "SimpleSwap: IDENTICAL_ADDRESS");
        // amountIn should be greater than 0
        require(amountIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");

        // TODO: make sure the order of tokenIn and tokenOut is corresponding to tokenA and tokenB

        // Derive for amountOut
        // reserveA * reserveB = (reserveA + amountIn) * (reserveB - amountOut)
        //                     = (reserveA + amountIn) * reserveB - (reserveA + amountIn) * amountOut
        // (reserveA + amountIn) * amountOut = (reserveA + amountIn) * reserveB - (reserveA * reserveB)
        //                                   = (reserveA * reserveB) + (amountIn * reserveB) - (reserveA * reserveB)
        //                                   = (amountIn * reserveB)
        // amountOut = (amountIn * reserveB) / (reserveA + amountIn)
        amountOut = amountIn.mul(reserveB).div(reserveA.add(amountIn));
        _safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        _safeTransfer(tokenOut, msg.sender, amountOut);

        reserveA += amountIn;
        reserveB -= amountOut;

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
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
        // amountAIn and amountBIn should be greater than 0
        require(amountAIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");
        require(amountBIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");

        // calculate the best amountA and amountB to keep reserveA / reserveB ratio
        if (reserveA == 0 && reserveB == 0) {
            amountA = amountAIn;
            amountB = amountBIn;
        } else {
            amountA = amountAIn;
            amountB = amountA.mul(reserveB) / reserveA;
            if (amountB > amountBIn) {
                amountB = amountBIn;
                amountA = amountB.mul(reserveA) / reserveB;
                require(amountA <= amountAIn, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");
            }
        }

        reserveA += amountA;
        reserveB += amountB;
        liquidity = Math.sqrt(amountA.mul(amountB));
        _mint(msg.sender, liquidity);
        _safeTransferFrom(tokenA, msg.sender, address(this), amountA);
        _safeTransferFrom(tokenB, msg.sender, address(this), amountB);

        emit AddLiquidity(msg.sender, amountA, amountB, liquidity);
    }

    /// @notice Remove liquidity from the pool
    /// @param liquidity The amount of liquidity to remove
    /// @return amountA The amount of tokenA received
    /// @return amountB The amount of tokenB received
    function removeLiquidity(uint256 liquidity) external returns (uint256 amountA, uint256 amountB){
        // liquidity should be greater than 0
        require(liquidity > 0, "SimpleSwap: INSUFFICIENT_LIQUIDITY_BURNED");

        // calculate amountA and amountB
        uint256 totalSupply = totalSupply();
        amountA = liquidity.mul(reserveA) / totalSupply;
        amountB = liquidity.mul(reserveB) / totalSupply;

        _safeTransferFrom(address(this), msg.sender, address(this), liquidity);
        _burn(address(this), liquidity);
        _safeTransfer(tokenA, msg.sender, amountA);
        _safeTransfer(tokenB, msg.sender, amountB);

        emit RemoveLiquidity(msg.sender, amountA, amountB, liquidity);
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

    function _safeTransfer(
        address token,
        address to,
        uint value
    ) private {
        bytes4 selector = bytes4(keccak256(bytes("transfer(address,uint256)")));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(selector, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SimpleSwap: TRANSFER_FAILED"
        );
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint value
    ) private {
        bytes4 selector = bytes4(keccak256(bytes("transferFrom(address,address,uint256)")));
         (bool success, bytes memory data) = token.call(abi.encodeWithSelector(selector, from, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SimpleSwap: TRANSFER_FAILED"
        );
    }
}
