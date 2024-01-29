// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20;

import { AccountFactory } from "src/AccountFactory.sol";
import { Account as SmartAccount } from "src/Account.sol";
import { BaseTest } from "test/BaseTest.sol";
import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";

contract AccountFactory__Constructor is BaseTest {
    function test_NeverRevert() external {
        try new AccountFactory(address(0), address(0), address(0)) {
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
        address(new AccountFactory(address(0), address(0), address(0)));

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
        address(new AccountFactory(address(0), address(0), address(0)));

        // make sure the implementation contract has been deployed
        assertFalse(keccak256(predictedImplementationAddress.code) == keccak256(""));
    }

    function test_ExposeTheImplementationAddressAfterBeingDeployed() external {
        // it should expose the implementation address after being deployed

        AccountFactory factory = new AccountFactory(address(0), address(0), address(0));
        assertNotEq(factory.accountImplementation(), address(0));
    }

    function test_ExposeTheOwnerOfNameServiceAfterBeingDeployed() external {
        // it should expose the implementation address after being deployed

        AccountFactory factory = new AccountFactory(address(0), address(0), address(99));
        assertEq(factory.nameServiceOwner(), address(99));
    }

    /// @notice The role of this test is to ensure the factory brick the instance of the account it deployed
    ///         By bricking, we refer to the process of making the instance of the account deployed unusable by anyone
    ///         The role of the instace deployed by the factory is to be used as reference implementation for proxies
    ///         only. The brick process is irreversible but only affect the instance itself as it use its own storage
    function test_BricksTheDeployedAccount() external {
        // it bricks the deployed account

        // deploy the factory and get the address of the implementation contract
        // the constructor function of the factory contract is responsible of bricking the account
        AccountFactory factory = new AccountFactory(address(0), address(0), address(99));
        SmartAccount account = SmartAccount(factory.accountImplementation());

        // try to call the `initialize` function on the account
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        account.initialize();

        // try to call the `addFirstSigner` function on the account
        vm.expectRevert(SmartAccount.FirstSignerAlreadySet.selector);
        // the `addFirstSigner` function only accept to be called by the factory,
        // that's why we set the factory address as msg.sender
        vm.prank(address(factory));
        account.addFirstSigner(uint256(2), uint256(2), bytes32(hex"22"));
    }
}
