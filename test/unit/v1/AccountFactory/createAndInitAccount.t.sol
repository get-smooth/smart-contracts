// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { SmartAccount } from "src/v1/SmartAccount.sol";
import { AccountFactory } from "src/v1/AccountFactory.sol";
import { BaseTest } from "test/BaseTest.sol";

contract AccountFactory__CreateAndInitAccount is BaseTest {
    AccountFactory private factory;
    address private mockedEntrypoint;

    // copy here the event definition from the contract
    // @dev: once we bump to 0.8.21, import the event from the contract
    event AccountCreated(
        bytes32 loginHash, address account, bytes32 indexed credIdHash, uint256 pubKeyX, uint256 pubKeyY
    );

    function setUp() external {
        // deploy the mocked mockedEntrypoint
        mockedEntrypoint = address(new MockEntryPoint());

        // deploy the factory
        factory = new AccountFactory(mockedEntrypoint, makeAddr("verifier"), validCreate.signer);
    }

    function test_UseADeterministicDeploymentProcess() external {
        // predict where the account linked to a specific hash will be deployed
        address predictedAddress = factory.getAddress(validCreate.usernameHash);

        // check the address of the account doesn't have any code before the deployment
        assertEq(keccak256(predictedAddress.code), keccak256(""));

        // deploy the account contract using the same hash
        factory.createAndInitAccount(
            validCreate.pubKeyX,
            validCreate.pubKeyY,
            validCreate.usernameHash,
            validCreate.credIdHash,
            _craftCreationSignature(address(factory))
        );

        // make sure the account contract has been deployed
        assertNotEq(keccak256(predictedAddress.code), keccak256(""));
    }

    function test_ReturnExistingAccountAddressGivenAHashAlreadyUsed() external {
        // it should return the existing account address

        // make sure the second attempt of creation return the already deployed address
        // without reverting or something else
        assertEq(
            factory.createAndInitAccount(
                validCreate.pubKeyX,
                validCreate.pubKeyY,
                validCreate.usernameHash,
                validCreate.credIdHash,
                _craftCreationSignature(address(factory))
            ),
            factory.createAndInitAccount(
                validCreate.pubKeyX,
                validCreate.pubKeyY,
                validCreate.usernameHash,
                validCreate.credIdHash,
                _craftCreationSignature(address(factory))
            )
        );
    }

    function test_DeployANewAccountIfNoneExistsGivenANewHash() external {
        // it should deploy a new account if none exists

        // deploy a valid proxy account using the constants predefined
        address proxy1 = factory.createAndInitAccount(
            validCreate.pubKeyX,
            validCreate.pubKeyY,
            validCreate.usernameHash,
            validCreate.credIdHash,
            _craftCreationSignature(address(factory))
        );

        assertNotEq(keccak256(proxy1.code), keccak256(""));
    }

    function test_RevertWithAnIncorrectValidSignature() external {
        // it should revert

        // this signature is a valid ECDSA signature but it as been created using a non authorized private key
        bytes memory invalidSignature = hex"0f7d6c13539049272786a4084a723d9147d85eed579f1a5f7cb743"
            hex"0d92ef48af08b662fec5e9741b995bc55a24c1449255bf39187a817a097cd7e369212ff8cf1c";

        // we tell the VM to expect a revert with a precise error
        vm.expectRevert(
            abi.encodeWithSelector(AccountFactory.InvalidSignature.selector, validCreate.usernameHash, invalidSignature)
        );

        // we call the function with the invalid signature to trigger the error
        factory.createAndInitAccount(
            validCreate.pubKeyX, validCreate.pubKeyY, validCreate.usernameHash, validCreate.credIdHash, invalidSignature
        );
    }

    function test_CallInitialize() external {
        // we tell the VM to expect *one* call to the initialize function with the loginHash as parameter
        vm.expectCall(factory.accountImplementation(), abi.encodeWithSelector(SmartAccount.initialize.selector), 1);

        // we call the function that is supposed to trigger the call
        factory.createAndInitAccount(
            validCreate.pubKeyX,
            validCreate.pubKeyY,
            validCreate.usernameHash,
            validCreate.credIdHash,
            _craftCreationSignature(address(factory))
        );
    }

    function test_CallTheProxyAddFirstSignerFunction() external {
        // we tell the VM to expect *one* call to the addFirstSigner function with the loginHash as parameter
        vm.expectCall(
            factory.getAddress(validCreate.usernameHash),
            abi.encodeCall(
                SmartAccount.addFirstSigner, (validCreate.pubKeyX, validCreate.pubKeyY, validCreate.credIdHash)
            ),
            1
        );

        // we call the function that is supposed to trigger the call
        factory.createAndInitAccount(
            validCreate.pubKeyX,
            validCreate.pubKeyY,
            validCreate.usernameHash,
            validCreate.credIdHash,
            _craftCreationSignature(address(factory))
        );
    }

    function test_TriggerAnEventOnDeployment() external {
        // we tell the VM to expect an event
        vm.expectEmit(true, true, true, true, address(factory));
        // we trigger the exact event we expect to be emitted in the next call
        emit AccountCreated(
            validCreate.usernameHash,
            factory.getAddress(validCreate.usernameHash),
            validCreate.credIdHash,
            validCreate.pubKeyX,
            validCreate.pubKeyY
        );

        // we call the function that is supposed to trigger the event
        // if the exact event is not triggered, the test will fail
        factory.createAndInitAccount(
            validCreate.pubKeyX,
            validCreate.pubKeyY,
            validCreate.usernameHash,
            validCreate.credIdHash,
            _craftCreationSignature(address(factory))
        );
    }
}

// Testing purpose only -- mimics the nonce manager of the entrypoint contract
contract MockEntryPoint {
    mapping(address account => mapping(uint256 index => uint256 nonce)) public nonces;

    function getNonce(address account, uint192 index) external view returns (uint256) {
        // harcoded to 0 for testing the creation flow
        return nonces[account][index];
    }
}
