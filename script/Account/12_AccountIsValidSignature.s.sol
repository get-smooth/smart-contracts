// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { EIP1271_VALIDATION_SUCCESS } from "src/v1/Account/SmartAccountEIP1271.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  AccountIsValidSignature
/// @notice Check if a EIP1271 signature is valid
contract AccountIsValidSignature is BaseScript {
    function run() public broadcast returns (bool isValid) {
        // address of the account we wanna use
        address payable accountAddress = payable(vm.envAddress("ACCOUNT"));
        SmartAccount account = SmartAccount(accountAddress);

        // the message hash and the signature
        bytes32 hash = vm.envBytes32("HASH");
        bytes memory signature = vm.envBytes("SIGNATURE");

        // check the validity of the signature
        isValid = account.isValidSignature(hash, signature) == EIP1271_VALIDATION_SUCCESS;
    }
}
