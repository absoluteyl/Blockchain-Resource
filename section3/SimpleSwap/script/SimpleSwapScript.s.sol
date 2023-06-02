// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../contracts/SimpleSwap.sol";

contract SimpleSwapScript is Script {
  // script command:
  // forge script script/SimpleSwapScript.s.sol --rpc-url sepolia --broadcast
  function run() external {
    vm.startBroadcast(vm.envUint("WALLET_PRIVATE_KEY"));

    SimpleSwap simpleSwap = new SimpleSwap(
      address(0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9), // WETH
      address(0x53844F9577C2334e541Aec7Df7174ECe5dF1fCf0)  // tDAI
    );

    vm.stopBroadcast();
  }
  // deployed contract address: https://sepolia.etherscan.io/tx/0xde85abbdd6e749fa2bee3328f239dbb93632af76b3aaacaeb27b88c06e4a0d9f
}
