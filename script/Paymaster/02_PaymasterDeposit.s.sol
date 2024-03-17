// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { Paymaster } from "src/Paymaster.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  PaymasterDeposit
/// @notice Deposit funds to the paymaster
contract PaymasterDeposit is BaseScript {
    function run() public payable broadcast {
        address paymasterAddress = vm.envAddress("PAYMASTER");
        uint256 value = vm.envUint("AMOUNT");

        Paymaster paymaster = Paymaster(paymasterAddress);

        // get the initial balance of the paymaster
        uint256 initialBalance = paymaster.getDeposit();

        // deposit some funds into the paymaster
        paymaster.deposit{ value: value }();

        // check that the deposit was successful
        require(paymaster.getDeposit() == initialBalance + value, "Deposit failed");
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
