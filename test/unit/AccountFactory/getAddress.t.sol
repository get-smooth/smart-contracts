// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { AccountFactory } from "src/AccountFactory.sol";
import { BaseTest } from "test/BaseTest.sol";

contract AccountFactory__GetAddress is BaseTest {
    bytes32 private constant LOGIN_HASH = keccak256("qdqd");
    address private constant EXPECTED_LOGIN_HASH_ADDRESS = 0x1D7C6D55303d641F01d34cF74a3Df2cD35FCC6de;
    AccountFactory private factory;

    function setUp() external {
        factory = new AccountFactory(address(0), address(0), address(0));
    }

    function test_NeverRevert(bytes32 randomLoginHash) external {
        // it never revert

        try factory.getAddress(randomLoginHash) {
            assertTrue(true);
        } catch Error(string memory) {
            fail("factory.getAddress() reverted");
        } catch {
            fail("factory.getAddress() reverted");
        }
    }

    function test_GivenARandomLoginHash(bytes32 randomLoginHash) external {
        // it return a valid address

        address computedAddress = factory.getAddress(randomLoginHash);
        assertNotEq(computedAddress, address(0));
    }

    function test_GivenTheHashOfAnEmptyString() external {
        // it return a valid address

        address computedAddress = factory.getAddress(keccak256(""));
        assertNotEq(computedAddress, address(0));
        assertNotEq(computedAddress, EXPECTED_LOGIN_HASH_ADDRESS);
    }

    function test_GivenAPredeterminedHash() external {
        // it return the precomputed address

        address computedAddress = factory.getAddress(LOGIN_HASH);
        assertEq(computedAddress, EXPECTED_LOGIN_HASH_ADDRESS);
    }

    function test_WhenTheFactoryIsDeployedAtADifferentAddress() external {
        // it return an address different than the original factory

        // we deploy a new instance of the factory at a different address but using the same parameters
        AccountFactory factory2 = new AccountFactory(address(0), address(0), address(0));
        assertNotEq(factory2.getAddress(LOGIN_HASH), factory.getAddress(LOGIN_HASH));
    }

    function test_WhenTheNonceOfTheFactoryChanges() external {
        // it has no impact on the address computed

        address computedAddress1 = factory.getAddress(LOGIN_HASH);
        // we artifically upgrade the nonce of the factory
        vm.setNonce(address(factory), 1234);
        // then recompute the address using the same login hash
        address computedAddress2 = factory.getAddress(LOGIN_HASH);
        assertEq(computedAddress1, computedAddress2);
    }
}
