// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { Paymaster } from "src/v1/Paymaster.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  PaymasterWithdrawAsOperator
/// @notice Withdraw funds to an arbitrary address
/// @dev    Can only be called by the owner of the paymaster
contract PaymasterWithdrawAsOperator is BaseScript {
    function run() public payable broadcast {
        address paymasterAddress = vm.envAddress("PAYMASTER");

        Paymaster paymaster = Paymaster(paymasterAddress);

        // get the initial balance of the paymaster
        uint256 initialBalance = paymaster.getDeposit();
        uint256 amount = vm.envOr("AMOUNT", initialBalance);

        // ensure we don't withdraw more than the paymaster has
        require(initialBalance >= amount, "Insufficient deposited funds");

        // withdraw some funds to the recipient
        paymaster.withdrawTo(amount);

        // check that the withdraw was successful
        require(paymaster.getDeposit() == initialBalance - amount, "Withdraw failed");
    }
}
