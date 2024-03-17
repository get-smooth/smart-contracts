// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { Paymaster } from "src/v1/Paymaster.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  PaymasterWithdraw
/// @notice Withdraw funds to an arbitrary address
/// @dev    Can only be called by the owner of the paymaster
contract PaymasterWithdraw is BaseScript {
    function run() public payable broadcast {
        address paymasterAddress = vm.envAddress("PAYMASTER");
        address payable recipient = payable(vm.envAddress("RECIPIENT"));

        Paymaster paymaster = Paymaster(paymasterAddress);

        // get the initial balance of the paymaster
        uint256 initialBalance = paymaster.getDeposit();
        uint256 amount = vm.envOr("AMOUNT", initialBalance);

        // ensure we don't withdraw more than the paymaster has
        require(initialBalance >= amount, "Insufficient deposited funds");

        // withdraw some funds to the recipient
        paymaster.withdrawTo(recipient, amount);

        // check that the withdraw was successful
        require(paymaster.getDeposit() == initialBalance - amount, "Withdraw failed");
    }
}

/*
    ℹ️ HOW TO USE THIS SCRIPT USING A LEDGER:
    ADMIN=<ADMIN_ADDRESS> forge script PaymasterDeposit --rpc-url <RPC_URL> --ledger  \
    --sender <ACCOUNT_ADDRESS>  [--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT WITH AN ARBITRARY PRIVATE KEY (NOT RECOMMENDED):
    PRIVATE_KEY=<PRIVATE_KEY> ADMIN=<ADMIN_ADDRESS>  forge script PaymasterDeposit  \
    --rpc-url <RPC_URL>[--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT ON ANVIL IN DEFAULT MODE:
    ADMIN=<ADMIN_ADDRESS>  forge script PaymasterDeposit --rpc-url http://127.0.0.1:8545 --broadcast --sender \
    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --mnemonics "test test test test test test test test test test test junk"
*/
