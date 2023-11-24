// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { AccountFactory } from "src/AccountFactory.sol";
import { BaseScript } from "../Base.s.sol";

/// @title Create an Account using an already deployed AccountFactory
/**
 * @notice
 *  forge script CreateAccount --sig "run(address,bytes32)" <...args>  <...flags>
 */
/// @dev If you need to deploy an AccountFactory, use the Deploy script in this directory
contract CreateAccount is BaseScript {
    function run(address factoryAddress, bytes32 loginHash) public broadcaster returns (address) {
        AccountFactory factory = AccountFactory(factoryAddress);
        return factory.createAccount(loginHash);
    }
}
