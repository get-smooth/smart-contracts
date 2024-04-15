// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { AccountFactory } from "src/v1/AccountFactory.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";
import { SignerVaultWebAuthnP256R1 } from "src/utils/SignerVaultWebAuthnP256R1.sol";
import "src/utils/Signature.sol" as Signature;

contract AccountHarness__Initiliaze is BaseTest {
    // @DEV: constant used by the `Initializable` library
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;
    AccountHarness private accountImplementation;
    AccountFactoryHarness private factory;

    function setUp() external {
        // 1. deploy an implementation of the account
        accountImplementation = new AccountHarness(makeAddr("entrypoint"), makeAddr("verifier"));

        // 2. deploy an implementation of the factory and its instance
        factory = new AccountFactoryHarness(address(accountImplementation), makeAddr("factorySigner"));
    }

    function test_RevertsIfCalledDirectly() external {
        // it reverts if called directly

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        accountImplementation.initialize(keccak256("credId"), 0, 0, "credId");
    }

    function test_CanBeCalledUsingAProxyAndSetVersionTo1() external setUpCreateFixture {
        // it can be called using a proxy and set version to 1

        // 1. tell the VM to expect a call to the initialize function
        vm.expectCall(
            address(accountImplementation),
            abi.encodeWithSelector(
                SmartAccount.initialize.selector,
                keccak256(createFixtures.signer.credId),
                createFixtures.signer.pubX,
                createFixtures.signer.pubY,
                createFixtures.signer.credId
            ),
            1
        );

        // 2. deploy the account and call the initialize function at the same time
        AccountHarness account = factory.exposed_deployAccount(
            keccak256(createFixtures.signer.credId),
            createFixtures.signer.pubX,
            createFixtures.signer.pubY,
            createFixtures.signer.credId
        );

        // 3. ensure the version 1 has been stored in the expected storage slot
        bytes32 value = vm.load(address(account), INITIALIZABLE_STORAGE);
        assertEq(value, bytes32(uint256(1)));
    }

    function test_StoreTheInitiator() external {
        // it stores the deployer address

        // 1. tell the VM to expect a call to the initialize function
        vm.expectCall(
            address(accountImplementation),
            abi.encodeWithSelector(
                SmartAccount.initialize.selector,
                keccak256(createFixtures.signer.credId),
                createFixtures.signer.pubX,
                createFixtures.signer.pubY,
                createFixtures.signer.credId
            ),
            1
        );

        // 2. deploy the account and call the initialize function at the same time
        AccountHarness account = factory.exposed_deployAccount(
            keccak256(createFixtures.signer.credId),
            createFixtures.signer.pubX,
            createFixtures.signer.pubY,
            createFixtures.signer.credId
        );

        // 2. check the factory is correctly set
        assertEq(account.factory(), address(factory));
    }

    function test_CanNotBeCalledTwice() external {
        // it can be called using a proxy and set version to 1

        // 1. deploy the account and call the initialize function at the same time
        AccountHarness account = factory.exposed_deployAccount(
            keccak256(createFixtures.signer.credId),
            createFixtures.signer.pubX,
            createFixtures.signer.pubY,
            createFixtures.signer.credId
        );

        // 2. call the initialize function a second time
        // check we can not call the initialize function again
        // (constant proxy version hardcoded in the account implementation)
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        account.initialize(
            keccak256(createFixtures.signer.credId),
            createFixtures.signer.pubX,
            createFixtures.signer.pubY,
            createFixtures.signer.credId
        );
    }

    function test_ItSetsTheCreationFuse() external setUpCreateFixture {
        // it stores the signer

        // 1. deploy the account and call the initialize function at the same time
        AccountHarness account = factory.exposed_deployAccount(
            keccak256(createFixtures.signer.credId),
            createFixtures.signer.pubX,
            createFixtures.signer.pubY,
            createFixtures.signer.credId
        );

        // 2. check the creation fuse has been set
        assertEq(account.exposed_creationFlowFuse(), 1);
    }

    // Duplicate of the event in the AccountHarness.sol file
    event SignerAdded(
        bytes1 indexed signatureType, bytes credId, bytes32 indexed credIdHash, uint256 pubKeyX, uint256 pubKeyY
    );

    function test_StoresTheSigner() external setUpCreateFixture {
        // it stores the signer

        bytes32 credIdHash = keccak256(createFixtures.signer.credId);
        uint256 pubX = createFixtures.signer.pubX;
        uint256 pubY = createFixtures.signer.pubY;
        bytes memory credId = createFixtures.signer.credId;

        // 1. we tell the VM to expect an event
        vm.expectEmit(true, true, true, true, factory.getAddress(createFixtures.response.authData));
        emit SignerAdded(Signature.Type.WEBAUTHN_P256R1, credId, credIdHash, pubX, pubY);

        // 2. deploy the account and call the initialize function at the same time
        AccountHarness account = factory.exposed_deployAccount(credIdHash, pubX, pubY, credId);

        // 3. get the starting slot of the signer
        bytes32 startingSlot = SignerVaultWebAuthnP256R1.getSignerStartingSlot(credIdHash);

        // 4. check the signer has been stored
        assertEq(vm.load(address(account), startingSlot), credIdHash);
        assertEq(uint256(vm.load(address(account), bytes32(uint256(startingSlot) + 1))), pubX);
        assertEq(uint256(vm.load(address(account), bytes32(uint256(startingSlot) + 2))), pubY);
    }
}

contract AccountHarness is SmartAccount {
    constructor(address entrypoint, address verifier) SmartAccount(entrypoint, verifier) { }

    function exposed_creationFlowFuse() external view returns (uint256) {
        return creationFlowFuse;
    }
}

contract AccountFactoryHarness is AccountFactory {
    constructor(address accountImplementation, address operator) AccountFactory(accountImplementation, operator) { }

    function exposed_deployAccount(
        bytes32 credIdHash,
        uint256 pubX,
        uint256 pubY,
        bytes calldata credId
    )
        external
        returns (AccountHarness account)
    {
        return AccountHarness(payable(address(_deployAccount(credIdHash, pubX, pubY, credId))));
    }
}
