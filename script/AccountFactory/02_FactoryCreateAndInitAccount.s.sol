// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { AccountFactory } from "src/v1/AccountFactory.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  FactoryCreateAndInitAccount
/// @notice Create and init an account using an already deployed factory
/// @dev    The signature must be signed by the admin of the factory
contract FactoryCreateAndInitAccount is BaseScript {
    function run() public broadcast returns (address accountAddress) {
        address factoryAddress = vm.envAddress("FACTORY");
        bytes memory authData = vm.envBytes("AUTH_DATA");
        bytes memory signature = vm.envBytes("SIGNATURE");
        bytes memory callData = vm.envBytes("CALL_DATA");

        return run(factoryAddress, authData, signature, callData);
    }

    /// @notice Deploy an account and init it
    /// @return accountAddress The address of the deployed account
    function run(
        address factoryAddress,
        bytes memory authData,
        bytes memory signature,
        bytes memory callData
    )
        internal
        broadcast
        returns (address accountAddress)
    {
        AccountFactory factory = AccountFactory(factoryAddress);

        // check the account is not already deployed
        accountAddress = factory.getAddress(authData);
        require(accountAddress.code.length == 0, "Account already exists");

        // deploy and init the account
        address deployedAddress = factory.createAndInitAccount(authData, signature, keccak256(callData));

        // ensure the account has been deployed at the correct address
        require(deployedAddress == accountAddress, "Invalid account address");
    }
}
