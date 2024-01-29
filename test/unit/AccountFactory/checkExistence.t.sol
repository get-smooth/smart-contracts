// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20;

import { AccountFactoryTestWrapper } from "./AccountFactoryTestWrapper.sol";
import { BaseTest } from "test/BaseTest.sol";

contract AccountFactory__CheckAccountExistence is BaseTest {
    AccountFactoryTestWrapper internal factory;

    function setUp() external {
        factory = new AccountFactoryTestWrapper(address(0), address(0), address(0));
    }

    function test_NeverRevert(bytes32 randomHash) external {
        // it should never revert

        try factory.checkAccountExistence(randomHash) {
            assertTrue(true);
        } catch Error(string memory) {
            fail("factory.constructor() reverted");
        } catch {
            fail("factory.constructor() reverted");
        }
    }

    function test_ReturnsZeroIfTheAddressHasNoCode() external {
        // it should returns zero if the address has no code

        assertEq(factory.checkAccountExistence(keccak256("qdqd")), address(0));
    }

    function test_ReturnsTheCalculatedAddressIfItHasSomeCode() external {
        // it should returns the calculated address if it has some code

        // precalculate the address where the account will be deployed
        bytes32 loginHash = keccak256("qdqd");
        address precomputedAddress = factory.getAddress(loginHash);

        // set some random bytecode to this address
        bytes memory code = hex"6080604052348015610010";
        vm.etch(precomputedAddress, code);

        // check that the address is returned as it holds some code
        assertEq(factory.checkAccountExistence(loginHash), precomputedAddress);
    }
}
