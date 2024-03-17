// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20;

import { AccountFactory } from "src/v1/AccountFactory.sol";
import { BaseTest } from "test/BaseTest.sol";

contract AccountFactory__Constructor is BaseTest {
    address private entrypoint;

    function setUp() external {
        entrypoint = address(new MockEntryPoint());
    }

    function test_NeverRevert() external {
        try new AccountFactory(entrypoint, address(0), address(0)) {
            assertTrue(true);
        } catch Error(string memory) {
            fail("factory.constructor() reverted");
        } catch {
            fail("factory.constructor() reverted");
        }
    }

    /// @notice The address for an Ethereum contract is deterministically computed from the address of its
    /// creator and the nonce of the creator. The sender and nonce are RLP encoded and then hashed with Keccak-256.
    /// @dev replace this function with `vm.computeCreateAddress()` as soon is it fixed
    function _predictCREATEAddress(address deployer, uint64 nonce) internal pure returns (address) {
        bytes memory data;
        if (nonce == 0x00) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, bytes1(0x80));
        } else if (nonce <= 0x7f) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, uint8(nonce));
        } else if (nonce <= 0xff) {
            data = abi.encodePacked(bytes1(0xd7), bytes1(0x94), deployer, bytes1(0x81), uint8(nonce));
        } else if (nonce <= 0xffff) {
            data = abi.encodePacked(bytes1(0xd8), bytes1(0x94), deployer, bytes1(0x82), uint16(nonce));
        } else if (nonce <= 0xffffff) {
            data = abi.encodePacked(bytes1(0xd9), bytes1(0x94), deployer, bytes1(0x83), uint24(nonce));
        } else {
            data = abi.encodePacked(bytes1(0xda), bytes1(0x94), deployer, bytes1(0x84), uint32(nonce));
        }
        return address(uint160(uint256(keccak256(data))));
    }

    function test_HaveCreatedTheImplementationContractDuringTheDeployement() external {
        // it should have created the implementation contract during the deployement

        // predict where the factory will be deployed
        address predictedFactoryAddress = _predictCREATEAddress(address(this), vm.getNonce(address(this)));

        // use the address predicted for the factory to predict the address of the implementation contract
        // @dev: The EIP-161 states that a freshly created contract shall start with a nonce of 1
        address predictedImplementationAddress = _predictCREATEAddress(predictedFactoryAddress, uint64(1));

        // check the address of the implementation doesn't have any code before the deployment
        assertTrue(keccak256(predictedImplementationAddress.code) == keccak256(""));

        // deploy the factory contract -- it is supposed to deploy the implementation contract during the deployement
        address(new AccountFactory(entrypoint, makeAddr("verifier"), makeAddr("admin")));

        // make sure the implementation contract has been deployed
        assertFalse(keccak256(predictedImplementationAddress.code) == keccak256(""));
    }

    function test_DeployTheImplementationContractToAPredictableAddress() external {
        // it should deploy the account to a predictable address for a given nonce

        // predict where the factory will be deployed
        address predictedFactoryAddress = _predictCREATEAddress(address(this), vm.getNonce(address(this)));

        // use the address predicted for the factory to predict the address of the implementation contract
        // @dev: The EIP-161 states that a freshly created contract shall start with a nonce of 1
        address predictedImplementationAddress = _predictCREATEAddress(predictedFactoryAddress, uint64(1));

        // deploy the factory contract -- it is supposed to deploy the implementation contract during the deployement
        address(new AccountFactory(entrypoint, makeAddr("verifier"), makeAddr("admin")));

        // make sure the implementation contract has been deployed
        assertFalse(keccak256(predictedImplementationAddress.code) == keccak256(""));
    }

    function test_ExposeTheImplementationAddressAfterBeingDeployed() external {
        // it should expose the implementation address after being deployed

        AccountFactory factory = new AccountFactory(entrypoint, makeAddr("verifier"), makeAddr("admin"));
        assertNotEq(factory.accountImplementation(), address(0));
    }

    function test_ExposeTheAdminAfterBeingDeployed() external {
        // it should expose the admin after being deployed

        AccountFactory factory = new AccountFactory(entrypoint, makeAddr("verifier"), makeAddr("admin"));
        assertEq(factory.admin(), makeAddr("admin"));
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
