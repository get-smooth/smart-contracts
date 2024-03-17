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
        uint256 pubKeyX = vm.envUint("PUBKEY_X");
        uint256 pubKeyY = vm.envUint("PUBKEY_Y");
        bytes32 loginHash = vm.envBytes32("LOGIN_HASH");
        bytes32 credIdHash = vm.envBytes32("CREDID_HASH");
        bytes memory signature = vm.envBytes("SIGNATURE");

        // check the account is not already deployed
        accountAddress = factory.getAddress(loginHash);
        require(accountAddress.code.length == 0, "Account already exists");

        // deploy and init the account
        factory.createAndInitAccount(pubKeyX, pubKeyY, loginHash, credIdHash, signature);
    }
}
