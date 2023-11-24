// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { AccountFactory } from "src/AccountFactory.sol";
import { BaseScript } from "../Base.s.sol";

/// @title Create an Account using an already deployed AccountFactory and init it
/**
 * @notice
 *  forge script CreateAndInitAccount --sig run(address,uint256,uint256,bytes32,bytes,bytes)"
 * " <...args> <...flags>
 */
/// @dev If you need to deploy an AccountFactory, use the Deploy script in this directory
contract CreateAndInitAccount is BaseScript {
    function run(
        address factoryAddress,
        uint256 pubKeyX,
        uint256 pubKeyY,
        bytes32 loginHash,
        bytes calldata credId,
        bytes calldata nameServiceSignature // ℹ️ must be made by the nameServiceOwner of the AccountFactory
    )
        public
        broadcaster
        returns (address)
    {
        AccountFactory factory = AccountFactory(factoryAddress);
        return factory.createAndInitAccount(pubKeyX, pubKeyY, loginHash, credId, nameServiceSignature);
    }
}
