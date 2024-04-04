// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { MessageHashUtils } from "@openzeppelin/utils/cryptography/MessageHashUtils.sol";
import "src/utils/Signature.sol" as Signature;
import { BaseTestUtils } from "test/BaseTest/BaseTestUtils.sol";
import { BaseTestCreateFixtures } from "test/BaseTest/BaseTestCreateFixtures.sol";

/// @title BaseTest
/// @notice This contract override the default Foundry's `Test` contract with some utility functions
contract BaseTest is Test, BaseTestUtils, BaseTestCreateFixtures {
    // solhint-disable-next-line var-name-mixedcase
    VmSafe.Wallet internal SMOOTH_SIGNER;

    /// @notice Utility function to craft a deployment signature
    /// @dev In production, the deployment of an account using our factory is gated by an approval from us.
    ///      The factory will check if smoo.th approved the deployment by verifying a signature
    ///      we create using an approved signer (the operator and also the owner of the factory).
    ///      This utility function is used to craft a signature for the deployment of an account.
    ///      This is for testing purposes only.
    /// @param authenticatorData The authenticator data returned by the authenticator on the signer creation
    /// @param account The address of the account that will be deployed
    /// @return signature The signature to be used for the deployment
    function craftDeploymentSignature(
        bytes memory authenticatorData,
        address account
    )
        internal
        view
        returns (bytes memory signature)
    {
        // recreate the message to sign
        bytes memory message = abi.encode(Signature.Type.CREATION, authenticatorData, account, block.chainid);

        // hash the message with the EIP-191 prefix
        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(message);

        // sign the hash of the message and get the signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SMOOTH_SIGNER.privateKey, hash);

        // return the signature appended with the creation type
        signature = abi.encodePacked(Signature.Type.CREATION, r, s, v);
    }

    /// @notice The constructor is in charge of creating a `mock` operator for the deployment purpose
    ///         of the tests. The address of this operator is expected to be the owner of the account factory.
    ///         The owner of the factory is expected to be the signer of the deployment signature.
    constructor() {
        SMOOTH_SIGNER = vm.createWallet("SMOOTH_FAKE_OPERATOR");
    }
}
