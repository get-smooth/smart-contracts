// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { AccountFactoryMultiSteps } from "src/AccountFactoryMultiSteps.sol";
import { BaseTest } from "test/BaseTest.sol";

contract AccountFactoryMultiSteps__CreateAccount is BaseTest {
    AccountFactoryMultiSteps internal factory;
    address internal implementation;

    // copy here the event definition from the contract
    // @dev: once we bump to 0.8.21, import the event from the contract
    event AccountCreated(
        bytes32 loginHash, address account, bytes32 indexed credIdHash, uint256 pubKeyX, uint256 pubKeyY
    );

    function setUp() external {
        factory = new AccountFactoryMultiSteps(address(0), address(0), address(0));
        implementation = factory.accountImplementation();
    }

    function test_NeverRevert(bytes32 randomHash) external {
        // it should never revert

        try factory.createAccount(randomHash) {
            assertTrue(true);
        } catch Error(string memory) {
            fail("factory.constructor() reverted");
        } catch {
            fail("factory.constructor() reverted");
        }
    }

    function test_UseADeterministicDeploymentProcess() external {
        // predict where the account linked to a specific hash will be deployed
        bytes32 loginHash = keccak256("muffin");
        address predictedAddress = factory.getAddress(loginHash);

        // check the address of the account doesn't have any code before the deployment
        assertEq(keccak256(predictedAddress.code), keccak256(""));

        // deploy the account contract using the same hash
        factory.createAccount(loginHash);

        // make sure the account contract has been deployed
        assertNotEq(keccak256(predictedAddress.code), keccak256(""));
    }

    function test_GivenAHashAlreadyUsed() external {
        // it should return existing account address

        bytes32 loginHash = keccak256("bao");

        // make sure the second attempt of creation return the already deployed address
        assertEq(factory.createAccount(loginHash), factory.createAccount(loginHash));
    }

    function test_GivenANewHash(bytes32 loginHash1, bytes32 loginHash2) external {
        // it should deploy a new account if none exists

        vm.assume(loginHash1 != loginHash2);
        assertNotEq(factory.createAccount(loginHash1), factory.createAccount(loginHash2));
    }

    function test_CallInitializeAfterDeployment() external {
        bytes32 loginHash = keccak256("plplplplplplplpl");

        // we tell the VM to expect *one* call to the initialize function with the loginHash as parameter
        vm.expectCall(implementation, abi.encodeWithSelector(this.initialize.selector), 1);

        // we call the function that is supposed to trigger the call
        factory.createAccount(loginHash);
    }

    function test_TriggerAnEventOnDeployment() external {
        bytes32 loginHash = keccak256("event");

        // we tell the VM to expect an event
        vm.expectEmit(true, true, false, true, address(factory));
        // we trigger the exact event we expect to be emitted in the next call
        emit AccountCreated(loginHash, factory.getAddress(loginHash), bytes32(0), uint256(0), uint256(0));

        // we call the function that is supposed to trigger the event
        // if the exact event is not triggered, the test will fail
        factory.createAccount(loginHash);
    }

    // @dev: I don't know why but encodeCall crashes when using Account.initialize
    //       when using the utils Test contract from Forge, so I had to copy the function here
    //       it works as expected if I switch to the utils Test contract from PRB 🤷‍♂️
    //       Anyway, remove this useless function once the bug is fixed
    function initialize() public { }
}
