// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { AccountFactory } from "src/v1/AccountFactory.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  FactoryGetAddress
/// @notice Compute the address of the account based on the loginHash
contract FactoryGetAddress is BaseScript {
    function run() public broadcast returns (address accountAddress) {
        // address of the factory we wanna use
        address factoryAddress = vm.envAddress("FACTORY");
        AccountFactory factory = AccountFactory(factoryAddress);

        // arguments to pass to the `createAndInit` function
        bytes32 loginHash = vm.envBytes32("LOGIN_HASH");

        // check the account is not already deployed
        accountAddress = factory.getAddress(loginHash);
    }
}
