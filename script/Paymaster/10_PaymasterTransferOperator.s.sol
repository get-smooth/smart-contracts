// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { Paymaster } from "src/v1/Paymaster.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  PaymasterTransferOperator
/// @notice Transfer the operator role to someone else
contract PaymasterTransferOperator is BaseScript {
    function run() public broadcast {
        // address of the paymaster we wanna use
        address paymasterAddress = vm.envAddress("PAYMASTER");
        Paymaster paymaster = Paymaster(paymasterAddress);

        // address of the new operator
        address newOperator = vm.envAddress("NEW_OPERATOR");

        // fetch the operator of the paymaster
        paymaster.transferOperator(newOperator);
    }
}
