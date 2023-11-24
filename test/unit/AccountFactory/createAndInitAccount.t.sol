// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 <0.9.0;

import { AccountFactory } from "src/AccountFactory.sol";
import { BaseTest } from "test/BaseTest.sol";

contract AccountFactory__CreateAndInitAccount is BaseTest {
    bytes32 private constant LOGIN_HASH = keccak256("qdqd");
    address private constant SIGNER = 0x7a8c35e1CcE64FD85baeD9a3e4f399cAADb52f20;
    bytes private constant SIGNATURE = hex"247bbb60d4e8fd56e177234fb566331249f367465120c95ce65f"
        hex"a784b0b917cd6e19a4b6ebfb5d93a217ea76c37ff6d98d5f3aa18015e7220543a95d215a50381c";
    AccountFactory private factory;

    // copy here the event definition from the contract
    // @dev: once we bump to 0.8.21, import the event from the contract
    event AccountCreatedAndInit(bytes32 loginHash, address account, bytes credId, uint256 pubKeyX, uint256 pubKeyY);

    function setUp() external {
        factory = new AccountFactory(address(0), address(0), SIGNER);
    }

    function test_ShouldUseADeterministicDeploymentProcess() external {
        // predict where the account linked to a specific hash will be deployed
        address predictedAddress = factory.getAddress(LOGIN_HASH);

        // check the address of the account doesn't have any code before the deployment
        assertEq(keccak256(predictedAddress.code), keccak256(""));

        // deploy the account contract using the same hash
        factory.createAndInitAccount(uint256(0), uint256(0), LOGIN_HASH, hex"", SIGNATURE);

        // make sure the account contract has been deployed
        assertNotEq(keccak256(predictedAddress.code), keccak256(""));
    }

    function test_GivenAHashAlreadyUsed() external {
        // it should return the existing account address

        // make sure the second attempt of creation return the already deployed address
        // without reverting or something else
        assertEq(
            factory.createAndInitAccount(uint256(0), uint256(0), LOGIN_HASH, hex"", SIGNATURE),
            factory.createAndInitAccount(uint256(0), uint256(0), LOGIN_HASH, hex"", SIGNATURE)
        );
    }

    function test_GivenANewHash() external {
        // it should deploy a new account if none exists

        // deploy a valid proxy account using the constants predefined
        address proxy1 = factory.createAndInitAccount(uint256(0), uint256(0), LOGIN_HASH, hex"", SIGNATURE);

        // generated using the same private key as the one used to generate the SIGNATURE constant
        bytes memory newValidCorrectSignature =
            hex"4b4b6f4ecc5fb0427bbbe61b539a6c45062b45d794641a5dc86e12bd8c6f68a747"
            hex"df2abe57a1df59f2d2d5ba5f9c89d723ea8a7c1ca79e95fc1321f3eeb775f51c";
        bytes32 newLoginHash = keccak256("xoxo");

        // deploy a valid proxy account using a different loginHash and a correct valid signature
        address proxy2 =
            factory.createAndInitAccount(uint256(0), uint256(0), newLoginHash, hex"", newValidCorrectSignature);

        assertNotEq(proxy1, proxy2);
        assertNotEq(keccak256(proxy1.code), keccak256(""));
        assertNotEq(keccak256(proxy2.code), keccak256(""));
    }

    function test_RevertGiven_AnIncorrectValidSignature() external {
        // it should revert

        // this signature is a valid ECDSA signature but it as been created using a non authorized private key
        bytes memory invalidSignature = hex"1020211079cccfe88a67ed9d00d719c922b4d79e11ddb5f1f59c2e41"
            hex"fb27d5fa3f7825d448a05d75273f75f42def0010fdfb4f6ac1e0abe65dc426f7536d325c1b";

        // we tell the VM to expect a revert with a precise error
        vm.expectRevert(
            abi.encodeWithSelector(AccountFactory.InvalidNameServiceSignature.selector, LOGIN_HASH, invalidSignature)
        );

        // we call the function with the invalid signature to trigger the error
        factory.createAndInitAccount(uint256(0), uint256(0), LOGIN_HASH, hex"", invalidSignature);
    }

    function test_ShouldCallInitialize() external {
        // we tell the VM to expect *one* call to the initialize function with the loginHash as parameter
        vm.expectCall(factory.accountImplementation(), abi.encodeCall(this.initialize, (LOGIN_HASH)), 1);

        // we call the function that is supposed to trigger the call
        factory.createAndInitAccount(uint256(0), uint256(0), LOGIN_HASH, hex"", SIGNATURE);
    }

    function test_ShouldCallTheProxyAddFirstSignerFunction() external {
        uint256 pubKeyX = uint256(43);
        uint256 pubKeyY = uint256(22);
        bytes memory credId = abi.encodePacked(keccak256("a"), keccak256("b"));

        // we tell the VM to expect *one* call to the addFirstSigner function with the loginHash as parameter
        vm.expectCall(
            factory.getAddress(LOGIN_HASH), abi.encodeCall(this.addFirstSigner, (pubKeyX, pubKeyY, credId)), 1
        );

        // we call the function that is supposed to trigger the call
        factory.createAndInitAccount(pubKeyX, pubKeyY, LOGIN_HASH, credId, SIGNATURE);
    }

    function test_ShouldTriggerAnEventOnDeployment() external {
        uint256 pubKeyX = uint256(43);
        uint256 pubKeyY = uint256(22);
        bytes memory credId = abi.encodePacked(keccak256("a"), keccak256("b"));

        // we tell the VM to expect an event
        vm.expectEmit(true, true, true, true, address(factory));
        // we trigger the exact event we expect to be emitted in the next call
        emit AccountCreatedAndInit(LOGIN_HASH, factory.getAddress(LOGIN_HASH), credId, pubKeyX, pubKeyY);

        // we call the function that is supposed to trigger the event
        // if the exact event is not triggered, the test will fail
        factory.createAndInitAccount(pubKeyX, pubKeyY, LOGIN_HASH, credId, SIGNATURE);
    }

    // @dev: I don't know why but encodeCall crashes when using Account.XXX
    //       when using the utils Test contract from Forge, so I had to copy the function here
    //       it works as expected if I switch to the utils Test contract from PRB 🤷‍♂️
    //       Anyway, remove this useless function once the bug is fixed
    function initialize(bytes32) public { }
    function addFirstSigner(uint256, uint256, bytes calldata) public { }
}
