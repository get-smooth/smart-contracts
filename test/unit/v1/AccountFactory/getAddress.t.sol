// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { AccountFactory } from "src/v1/AccountFactory.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";

contract AccountFactory__GetAddress is BaseTest {
    AccountFactoryHarness private factory;

    function setUp() external setUpCreateFixture {
        factory = new AccountFactoryHarness(makeAddr("owner"), makeAddr("account"));
    }

    function test_RevertIfTheAuthDataIsTooShort(bytes32 incorrectAuthData) external {
        // it revert if the authData is too short

        vm.expectRevert();
        factory.getAddress(abi.encodePacked(incorrectAuthData));
    }

    function test_GivenARandomAuthData(bytes32 randomWord) external {
        // it return a valid address

        // 1. create a false authData by replacing the last 3 32-words of the correct authData with random data
        truncBytes(createFixtures.response.authData, 0, createFixtures.response.authData.length - 32 * 3);
        bytes memory fakeAuthData = abi.encodePacked(
            createFixtures.response.authData, randomWord, keccak256(abi.encodePacked(randomWord)), vm.unixTime()
        );

        // 2. compute the address using the fake authData and make sure it's not the zero address
        address computedAddress = factory.getAddress(fakeAuthData);
        assertNotEq(computedAddress, address(0));
    }

    function test_GivenAPredeterminedHash() external {
        // it return the precomputed address

        address computedAddress = factory.getAddress(createFixtures.response.authData);
        assertEq(computedAddress, 0xdFa6C6d347bBab19e76c6f217C401ef2339Aa323);
    }

    function test_WhenTheFactoryIsDeployedAtADifferentAddress() external {
        // it return an address different than the original factory

        // we deploy a new instance of the factory at a different address but using the same parameters
        AccountFactory factory2 = new AccountFactory(makeAddr("owner"), makeAddr("account"));
        assertNotEq(
            factory2.getAddress(createFixtures.response.authData), factory.getAddress(createFixtures.response.authData)
        );
    }

    function test_WhenTheNonceOfTheFactoryChanges() external {
        // it has no impact on the address computed

        address computedAddress1 = factory.getAddress(createFixtures.response.authData);
        // we artifically upgrade the nonce of the factory
        vm.setNonce(address(factory), 1234);
        // then recompute the address using the same authenticator data
        address computedAddress2 = factory.getAddress(createFixtures.response.authData);
        assertEq(computedAddress1, computedAddress2);
    }

    function test_CalculateSameAddressUsingBothMethods() external {
        // it calculate same address using both methods

        bytes32 salt = factory.exposed_calculateSalt(createFixtures.response.authData);

        assertEq(factory.getAddress(createFixtures.response.authData), factory.exposed_getAddress(salt));
    }
}

contract AccountFactoryHarness is AccountFactory {
    constructor(address owner, address accountImplementation) AccountFactory(owner, accountImplementation) { }

    function exposed_calculateSalt(bytes calldata authenticatorData) external pure returns (bytes32) {
        return calculateSalt(authenticatorData);
    }

    function exposed_getAddress(bytes32 salt) external view returns (address) {
        return getAddress(salt);
    }
}
