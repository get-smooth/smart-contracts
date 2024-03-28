// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { AccountFactory } from "src/v1/AccountFactory.sol";
import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { BaseScript } from "../Base.s.sol";
import { Metadata } from "src/v1/Metadata.sol";

/// @title  FactoryDeploy
/// @notice Deploy the account factory
contract FactoryDeploy is BaseScript {
    function run() public broadcast returns (AccountFactory) {
        address owner = vm.envAddress("OWNER");
        address payable accountImplementation = payable(vm.envAddress("ACCOUNT_IMPLEMENTATION"));

        // 1. Check if the account implementation is deployed
        require(address(accountImplementation).code.length > 0, "Account not deployed");

        // 2. Check the version of the account is the expected one
        assertEqVersion(Metadata.VERSION, SmartAccount(accountImplementation).VERSION());

        // 3. Check the owner address is valid
        require(owner != address(0), "Invalid owner address");

        // 4. Deploy the account factory
        AccountFactory accountFactory = new AccountFactory(owner, accountImplementation);

        // 5. Check the version of the account factory is the expected one
        assertEqVersion(Metadata.VERSION, accountFactory.VERSION());

        return accountFactory;
    }
}
