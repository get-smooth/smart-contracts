// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { AccountFactory } from "src/v1/AccountFactory.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  FactoryGetOwner
/// @notice Fetch the owner of the factory
contract FactoryGetOwner is BaseScript {
    function run() public broadcast returns (address owner) {
        // address of the factory we wanna use
        address factoryAddress = vm.envAddress("FACTORY");
        AccountFactory factory = AccountFactory(factoryAddress);

        // fetch the version of the factory
        owner = factory.owner();
    }
}
