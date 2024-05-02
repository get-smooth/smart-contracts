// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { BaseTest } from "test/BaseTest/BaseTest.sol";
import { SmartAccount, Initializable, UUPSUpgradeable, Metadata } from "src/v1/Account/SmartAccount.sol";
import { AccountFactory } from "src/v1/AccountFactory.sol";

contract SmartAccount__Upgradeable is BaseTest {
    address internal entryPoint;
    address internal verifier;

    AccountFactory internal factory;
    SmartAccount internal account;

    function setUp() external setUpCreateFixture {
        // 1. set the entrypoint and the verifier
        entryPoint = makeAddr("entrypoint");
        verifier = makeAddr("verifier");

        // 2. deploy an implementation of the account
        address accountImplementation = address(new SmartAccount(entryPoint, verifier));

        // 3. deploy the implementation of the factory and one instance
        factory = new AccountFactory(address(accountImplementation), SMOOTH_SIGNER.addr);

        // 4. get the address of the future account
        address accountFutureAddress = factory.getAddress(createFixtures.response.authData);

        // 5. craft a valid deployment signature
        bytes memory signature = craftDeploymentSignature(createFixtures.response.authData, accountFutureAddress);

        // 6. deploy an account instance and set the first signer
        account = SmartAccount(
            payable(
                factory.createAndInitAccount(
                    createFixtures.response.authData, signature, createFixtures.transaction.calldataHash
                )
            )
        );
    }

    function test_CanBeUpgradedWithoutData() external {
        // it can be upgraded to another implementation

        // 1. deploy a new implementation of the account
        address newEntryPoint = makeAddr("new-entrypoint");
        SmartAccountV2 newAccountImplementation = new SmartAccountV2(newEntryPoint, makeAddr("new-verifier"));

        // 2. fetch the entrypoint of the current account
        address currentEntryPoint = address(account.entryPoint());

        // 3. upgrade the account to the new implementation
        vm.prank(currentEntryPoint);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, address(newAccountImplementation), "")
        );

        // 4. make sure the account has been upgraded
        assertEq(address(account.entryPoint()), newEntryPoint);
    }

    function test_CanBeUpgradedWithData() external {
        // it can be upgraded to another implementation

        // 1. deploy a new implementation of the account
        address newEntryPoint = makeAddr("new-entrypoint");
        SmartAccountV2 newAccountImplementation = new SmartAccountV2(newEntryPoint, makeAddr("new-verifier"));

        // 2. fetch the entrypoint of the current account
        address currentEntryPoint = address(account.entryPoint());

        // 3. tell the VM to expect a call
        vm.expectCall(
            address(newAccountImplementation),
            abi.encodeWithSelector(SmartAccountV2.correctInitialize.selector, address(66)),
            1
        );

        // 4. upgrade the account to the new implementation
        vm.prank(currentEntryPoint);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(
                UUPSUpgradeable.upgradeToAndCall.selector,
                address(newAccountImplementation),
                abi.encodeWithSelector(SmartAccountV2.correctInitialize.selector, address(66))
            )
        );

        // 5. make sure the account has been upgraded
        assertEq(address(account.entryPoint()), newEntryPoint);
    }

    function test_RevertIfNotInitiatedByItself(address caller) external {
        // it revert if not initiated by itself

        // 1. make sure the fuzzed address is different from the entrypoint
        vm.assume(caller != entryPoint);

        // 2. deploy a new implementation of the account
        SmartAccount newAccountImplementation = new SmartAccount(makeAddr("new-entrypoint"), makeAddr("new-verifier"));

        // 3. tell the VM to expect a revert
        vm.expectRevert("account: not from EntryPoint");

        // 4. try to upgrade the account to the new implementation -- must revert
        vm.prank(caller);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, address(newAccountImplementation), "")
        );
    }

    function test_RevertIfReinitializerIsEqualOrBelow() external {
        // it revert if reinitializer is equal or below

        // 1. deploy a new implementation of the account
        address newEntryPoint = makeAddr("new-entrypoint");
        SmartAccountV2 newAccountImplementation = new SmartAccountV2(newEntryPoint, makeAddr("new-verifier"));

        // 2. fetch the entrypoint of the current account
        address currentEntryPoint = address(account.entryPoint());

        // 3. tell the VM to expect a call
        vm.expectCall(
            address(newAccountImplementation),
            abi.encodeWithSelector(SmartAccountV2.incorrectInitialize.selector, address(12)),
            1
        );

        // 4. tell the VM to expect a revert
        vm.expectRevert(Initializable.InvalidInitialization.selector);

        // 5. upgrade the account to the new implementation
        vm.prank(currentEntryPoint);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(
                UUPSUpgradeable.upgradeToAndCall.selector,
                address(newAccountImplementation),
                abi.encodeWithSelector(SmartAccountV2.incorrectInitialize.selector, address(12))
            )
        );

        // 6. make sure the account has not been upgraded
        assertEq(address(account.entryPoint()), currentEntryPoint);
    }

    function test_MaintainsTheSignersStored() external {
        // it maintains the signers stored

        // 1. fetch the current stored signer
        (bytes32 credIdHash, uint256 pubkeyX, uint256 pubkeyY) =
            account.getSigner(keccak256(createFixtures.signer.credId));
        assertNotEq(credIdHash, bytes32(0));
        assertNotEq(pubkeyX, 0);
        assertNotEq(pubkeyY, 0);

        // 2. deploy a new implementation of the account

        SmartAccountV2 newAccountImplementation =
            new SmartAccountV2(makeAddr("new-entrypoint"), makeAddr("new-verifier"));

        // 3. upgrade the account to the new implementation
        vm.prank(entryPoint);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, address(newAccountImplementation), "")
        );

        // 4. fetch the stored signer from the new implementation
        (bytes32 newCredIdHash, uint256 newPubkeyX, uint256 newPubkeyY) =
            account.getSigner(keccak256(createFixtures.signer.credId));

        // 5. make sure the stored signer has not changed
        assertEq(newCredIdHash, credIdHash);
        assertEq(newPubkeyX, pubkeyX);
        assertEq(newPubkeyY, pubkeyY);
    }

    function test_MaintainsTheFactoryAddressStored() external {
        // it maintains the factory address stored

        // 1. fetch the current factory
        address currentFactory = account.factory();
        assertNotEq(currentFactory, address(0));

        // 2. deploy a new implementation of the account
        SmartAccountV2 newAccountImplementation =
            new SmartAccountV2(makeAddr("new-entrypoint"), makeAddr("new-verifier"));

        // 3. upgrade the account to the new implementation
        vm.prank(entryPoint);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, address(newAccountImplementation), "")
        );

        // 4. make sure the stored factory has not changed
        assertEq(currentFactory, account.factory());
    }

    function test_CanUpdateTheWebauthnVerifier() external {
        // it can update the webauthn verifier

        // 1. deploy a new implementation of the account
        address newVerifier = makeAddr("new-verifier");
        SmartAccountV2 newAccountImplementation = new SmartAccountV2(makeAddr("new-entrypoint"), newVerifier);

        // 2. upgrade the account to the new implementation
        vm.prank(entryPoint);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, address(newAccountImplementation), "")
        );

        // 3. make sure the account has been upgraded
        assertEq(SmartAccountV2(payable(address(account))).exposed_webauthn256R1Verifier(), newVerifier);
    }

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint64 version);

    function test_EmitAnEvent() external {
        // it emits an event

        // 1. deploy a new implementation of the account
        SmartAccountV2 newAccountImplementation =
            new SmartAccountV2(makeAddr("new-entrypoint"), makeAddr("new-verifier"));

        // 2. we tell the VM to expect an event
        vm.expectEmit(true, false, false, true, address(account));
        emit Initialized(2);

        // 3. upgrade the account to the new implementation
        vm.prank(address(account.entryPoint()));
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(
                UUPSUpgradeable.upgradeToAndCall.selector,
                address(newAccountImplementation),
                abi.encodeWithSelector(SmartAccountV2.correctInitialize.selector, address(66))
            )
        );
    }

    function test_CanUpdateTheVersion() external {
        // it can update the version

        // 1. fetch the current version
        uint256 currentVersion = account.version();

        // 2. deploy a new implementation of the account
        SmartAccountV2 newAccountImplementation =
            new SmartAccountV2(makeAddr("new-entrypoint"), makeAddr("new-verifier"));

        // 3. upgrade the account to the new implementation
        vm.prank(entryPoint);
        account.execute(
            address(account),
            0,
            abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, address(newAccountImplementation), "")
        );

        // 4. make sure the version of the account has been updated
        assert(currentVersion < account.version());
    }
}

contract SmartAccountV2 is SmartAccount {
    constructor(address _entrypoint, address _verifier) SmartAccount(_entrypoint, _verifier) { }

    // expected to work as expected as the version is higher than the curret one
    function correctInitialize(address) external reinitializer(2) { }

    // expected to revert as the version is equal to the current one
    function incorrectInitialize() external reinitializer(1) { }

    function exposed_webauthn256R1Verifier() external view returns (address) {
        return address(webauthn256R1Verifier());
    }

    // increase the version by 1_000_000
    function version() external pure virtual override returns (uint256) {
        return Metadata.VERSION + 1_000_000;
    }
}
