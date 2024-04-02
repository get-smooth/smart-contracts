// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { BaseScript } from "../Base.s.sol";

// keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
bytes32 constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

/// @title  AccountGetProxyVersion
/// @notice Fetch the version of the proxy
contract AccountGetProxyVersion is BaseScript {
    function run() public broadcast returns (uint256 version) {
        // address of the account we wanna use
        address payable accountAddress = payable(vm.envAddress("ACCOUNT"));

        // load the storage of the Initializable contract
        bytes32 store = vm.load(accountAddress, INITIALIZABLE_STORAGE);

        // use the last 8 bytes of the storage to get the version
        version = uint256(store) & 0xFFFFFFFFFFFFFFFF;
    }
}
