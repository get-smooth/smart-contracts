// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { AccountFactory } from "src/v1/AccountFactory.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  FactoryCreateAndInitAccount
/// @notice Create and init an account using an already deployed factory
/// @dev    The signature must be signed by the admin of the factory
contract FactoryCreateAndInitAccount is BaseScript {
    /// @notice Deploy an account and init it
    /// @return accountAddress The address of the deployed account
    function run() public broadcast returns (address accountAddress) {
        address factoryAddress = vm.envAddress("FACTORY");
        AccountFactory factory = AccountFactory(factoryAddress);

        // arguments to pass to the `createAndInit` function
        bytes32 usernameHash = vm.envBytes32("USERNAME_HASH");
        bytes memory authData = vm.envBytes("AUTH_DATA");
        bytes memory signature = vm.envBytes("SIGNATURE");

        // check the account is not already deployed
        accountAddress = factory.getAddress(authData);
        require(accountAddress.code.length == 0, "Account already exists");

        // deploy and init the account
        address deployedAddress = factory.createAndInitAccount(usernameHash, authData, signature);

        // ensure the account has been deployed at the correct address
        require(deployedAddress == accountAddress, "Invalid account address");
    }
}
