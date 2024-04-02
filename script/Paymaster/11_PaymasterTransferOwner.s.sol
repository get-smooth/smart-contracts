// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { Paymaster } from "src/v1/Paymaster.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  PaymasterTransferOwner
/// @notice Transfer the owner role to someone else
contract PaymasterTransferOwner is BaseScript {
    function run() public broadcast {
        // address of the paymaster we wanna use
        address paymasterAddress = vm.envAddress("PAYMASTER");
        Paymaster paymaster = Paymaster(paymasterAddress);

        // address of the new owner
        address newOwner = vm.envAddress("NEW_OWNER");

        // fetch the owner of the paymaster
        paymaster.transferOwnership(newOwner);
    }
}
