// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { AccountFactory } from "src/AccountFactory.sol";
import { BaseTest } from "test/BaseTest.sol";

contract AccountFactory__CreateAndInitAccount is BaseTest {
    AccountFactory private factory;

    // copy here the event definition from the contract
    // @dev: once we bump to 0.8.21, import the event from the contract
    event AccountCreated(
        bytes32 loginHash, address account, bytes32 indexed credIdHash, uint256 pubKeyX, uint256 pubKeyY
    );

    function setUp() external {
        factory = new AccountFactory(address(0), address(0), validCreate.signer);
    }

    function test_UseADeterministicDeploymentProcess() external {
        // predict where the account linked to a specific hash will be deployed
        address predictedAddress = factory.getAddress(validCreate.loginHash);

        // check the address of the account doesn't have any code before the deployment
        assertEq(keccak256(predictedAddress.code), keccak256(""));

        // deploy the account contract using the same hash
        factory.createAndInitAccount(
            validCreate.pubKeyX, validCreate.pubKeyY, validCreate.loginHash, validCreate.credId, validCreate.signature
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
                validCreate.loginHash,
                validCreate.credId,
                validCreate.signature
            ),
            factory.createAndInitAccount(
                validCreate.pubKeyX,
                validCreate.pubKeyY,
                validCreate.loginHash,
                validCreate.credId,
                validCreate.signature
            )
        );
    }

    function test_DeployANewAccountIfNoneExistsGivenANewHash() external {
        // it should deploy a new account if none exists

        // deploy a valid proxy account using the constants predefined
        address proxy1 = factory.createAndInitAccount(
            validCreate.pubKeyX, validCreate.pubKeyY, validCreate.loginHash, validCreate.credId, validCreate.signature
        );

        assertNotEq(keccak256(proxy1.code), keccak256(""));
    }

    function test_RevertWithAnIncorrectValidSignature() external {
        // it should revert

        // this signature is a valid ECDSA signature but it as been created using a non authorized private key
        bytes memory invalidSignature = hex"1020211079cccfe88a67ed9d00d719c922b4d79e11ddb5f1f59c2e41"
            hex"fb27d5fa3f7825d448a05d75273f75f42def0010fdfb4f6ac1e0abe65dc426f7536d325c1b";

        // we tell the VM to expect a revert with a precise error
        vm.expectRevert(
            abi.encodeWithSelector(AccountFactory.InvalidSignature.selector, validCreate.loginHash, invalidSignature)
        );

        // we call the function with the invalid signature to trigger the error
        factory.createAndInitAccount(
            validCreate.pubKeyX, validCreate.pubKeyY, validCreate.loginHash, validCreate.credId, invalidSignature
        );
    }

    function test_CallInitialize() external {
        // we tell the VM to expect *one* call to the initialize function with the loginHash as parameter
        vm.expectCall(factory.accountImplementation(), abi.encodeWithSelector(this.initialize.selector), 1);

        // we call the function that is supposed to trigger the call
        factory.createAndInitAccount(
            validCreate.pubKeyX, validCreate.pubKeyY, validCreate.loginHash, validCreate.credId, validCreate.signature
        );
    }

    function test_CallTheProxyAddFirstSignerFunction() external {
        // we tell the VM to expect *one* call to the addFirstSigner function with the loginHash as parameter
        vm.expectCall(
            factory.getAddress(validCreate.loginHash),
            abi.encodeCall(
                this.addFirstSigner, (validCreate.pubKeyX, validCreate.pubKeyY, keccak256(validCreate.credId))
            ),
            1
        );

        // we call the function that is supposed to trigger the call
        factory.createAndInitAccount(
            validCreate.pubKeyX, validCreate.pubKeyY, validCreate.loginHash, validCreate.credId, validCreate.signature
        );
    }

    function test_TriggerAnEventOnDeployment() external {
        // we tell the VM to expect an event
        vm.expectEmit(true, true, true, true, address(factory));
        // we trigger the exact event we expect to be emitted in the next call
        emit AccountCreated(
            validCreate.loginHash,
            factory.getAddress(validCreate.loginHash),
            keccak256(validCreate.credId),
            validCreate.pubKeyX,
            validCreate.pubKeyY
        );

        // we call the function that is supposed to trigger the event
        // if the exact event is not triggered, the test will fail
        factory.createAndInitAccount(
            validCreate.pubKeyX, validCreate.pubKeyY, validCreate.loginHash, validCreate.credId, validCreate.signature
        );
    }

    // @dev: I don't know why but encodeCall crashes when using Account.XXX
    //       when using the utils Test contract from Forge, so I had to copy the function here
    //       it works as expected if I switch to the utils Test contract from PRB 🤷‍♂️
    //       Anyway, remove this useless function once the bug is fixed
    function initialize() public { }
    function addFirstSigner(uint256, uint256, bytes32) public { }
}
