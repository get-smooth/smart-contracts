// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { BaseTest } from "test/BaseTest.sol";
import { SmartAccount } from "src/v1/SmartAccount.sol";
import { ERC1967Proxy } from "src/v1/AccountFactory.sol";
import { SignerVaultWebAuthnP256R1 } from "src/utils/SignerVaultWebAuthnP256R1.sol";
import "src/utils/Signature.sol" as Signature;

contract SmartAccount__ValidateCreationSignature is BaseTest {
    WrapperAccount internal account;
    MockFactory internal factory;
    MockEntryPoint internal entrypoint;
    address internal admin;

    // deploy the mocked entrypoint, the mocked factory, the account and set the admin
    function setUp() external {
        admin = validCreate.signer;

        // deploy a mock of the entrypoint
        entrypoint = new MockEntryPoint();

        // deploy a mock of the factory that will deploy the account base implementation
        factory = new MockFactory(admin, address(entrypoint));

        // deploy a valid instance of the account implementation and set a valid signer
        account = factory.mockDeployAccount(
            validCreate.pubKeyX, validCreate.pubKeyY, validCreate.usernameHash, validCreate.credIdHash
        );
    }

    // utilitary function to get a valid initcode
    function _getValidInitCode() internal view returns (bytes memory) {
        return abi.encodePacked(
            address(factory),
            abi.encodeWithSelector(
                MockFactory.mockDeployAccount.selector,
                validCreate.pubKeyX,
                validCreate.pubKeyY,
                validCreate.usernameHash,
                validCreate.credIdHash,
                validCreate.signature
            )
        );
    }

    function _getValidInitCode(bytes memory signature) internal view returns (bytes memory) {
        return abi.encodePacked(
            address(factory),
            abi.encodeWithSelector(
                MockFactory.mockDeployAccount.selector,
                validCreate.pubKeyX,
                validCreate.pubKeyY,
                validCreate.usernameHash,
                validCreate.credIdHash,
                signature
            )
        );
    }

    // utilitary function to slice a bytes array
    function _sliceBytes(bytes calldata b, uint256 endIndex) external pure returns (bytes memory) {
        return b[:endIndex];
    }

    function test_FailsIfTheNonceIsNot0(uint256 randomNonce) external {
        // it fails if the nonce is not 0

        // bound the nonce to a invalid range
        randomNonce = bound(randomNonce, 1, type(uint256).max);

        // get a valid initcode
        bytes memory initCode = _getValidInitCode();

        // mock the call to the entrypoint to return the random nonce
        vm.mockCall(address(entrypoint), abi.encodeWithSelector(MockEntryPoint.getNonce.selector), abi.encode(1));

        // assert that the signature validation fails if the nonce is not equal to zero
        assertEq(account.validateCreationSignature(validCreate.signature, initCode), Signature.State.FAILURE);
    }

    function test_FailsIfTheInitCodeIsNotLongEnough(uint256 bytesLength) external {
        // it fails if the initcode is not long enough

        // bound the length of the initCode to a invalid range
        bytesLength = bound(bytesLength, 0, 151);

        // create a truncated version of the valid initCode by calling an utilitary function in a different context
        bytes memory initCode = this._sliceBytes(_getValidInitCode(), bytesLength);

        // assert that the signature validation fails if the nonce is not equal to zero
        assertEq(account.validateCreationSignature(validCreate.signature, initCode), Signature.State.FAILURE);
    }

    function test_FailsIfTheInitCodeIsNotCorrectlyConstructed() external {
        // it fails if the initcode is not correctly constructured

        bytes memory invalidInitCode = abi.encodePacked(
            address(factory),
            abi.encodeWithSelector(
                MockFactory.mockDeployAccount.selector,
                validCreate.pubKeyY,
                validCreate.pubKeyX, // X and Y inverted
                validCreate.usernameHash,
                validCreate.credIdHash,
                validCreate.signature
            )
        );

        assertEq(account.validateCreationSignature(validCreate.signature, invalidInitCode), Signature.State.FAILURE);
    }

    function test_FailsIfTheUseropFactoryIsNotCorrect(address incorrectFactory) external {
        // it fails if the userop factory is not correct

        vm.assume(incorrectFactory != address(factory));

        bytes memory initCodeWithIncorrectFactory = abi.encodePacked(
            address(incorrectFactory),
            abi.encodeWithSelector(
                MockFactory.mockDeployAccount.selector,
                validCreate.pubKeyX,
                validCreate.pubKeyY,
                validCreate.usernameHash,
                validCreate.credIdHash,
                validCreate.signature
            )
        );

        assertEq(
            account.validateCreationSignature(validCreate.signature, initCodeWithIncorrectFactory),
            Signature.State.FAILURE
        );
    }

    function test_FailsIfTheAdminOfTheFactoryIsNotCorrect(address incorrectSigner) external {
        // it fails if the admin of the factory is not correct
        vm.assume(incorrectSigner != admin);

        // mock the call to the factory to expected signer (second argument is the selector of the admin)
        // @dev: no way to access the selector of admin directly since it is a public state variable
        vm.mockCall(address(factory), hex"f851a440", abi.encode(incorrectSigner));

        assertEq(account.validateCreationSignature(validCreate.signature, _getValidInitCode()), Signature.State.FAILURE);
    }

    function test_FailsIfThePassedSignatureIsNotCorrect(string memory name) external {
        // it fails if the passed signature is not correct

        // create an invalid signature with a random signer
        (, uint256 signerSK) = makeAddrAndKey(name);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSK, keccak256("Signed by qdqd"));
        bytes memory invalidSignature = abi.encodePacked(r, s, v);

        assertEq(account.validateCreationSignature(invalidSignature, _getValidInitCode()), Signature.State.FAILURE);
    }

    function test_NeverReverts(bytes calldata signature, bytes calldata initCode) external {
        // it never reverts

        try account.validateCreationSignature(signature, initCode) {
            assertTrue(true);
        } catch Error(string memory) {
            fail("account.constructor() reverted");
        } catch {
            fail("account.constructor() reverted");
        }
    }

    function test_FailsIfTheCredIdDoesNotMatchTheCredIdStored(bytes32 incorrectCredIdHash) external {
        // it fails if the credId does not match the credId stored

        // make sure the fuzzed values do not match the real ones
        vm.assume(incorrectCredIdHash != validCreate.credIdHash);

        // get the starting slot used to store the signer sequentially
        bytes32 credIdStorageSlot = SignerVaultWebAuthnP256R1.getSignerStartingSlot(validCreate.credIdHash);

        // replace the stored value of the valid credIdHash with the incorrect value
        vm.store(address(account), credIdStorageSlot, incorrectCredIdHash);

        assertEq(account.validateCreationSignature(validCreate.signature, _getValidInitCode()), Signature.State.FAILURE);
    }

    function test_FailsIfThePubKeyXDoesNotMatchThePubKeyXStored(uint256 incorrectPubKeyX) external {
        // it fails if the pubKeyX does not match the pubKeyX stored

        // make sure the fuzzed values do not match the real ones
        vm.assume(incorrectPubKeyX != validCreate.pubKeyX);

        // get the starting slot used to store the signer sequentially
        bytes32 pubKeyXStorageSlot =
            bytes32(uint256(SignerVaultWebAuthnP256R1.getSignerStartingSlot(validCreate.credIdHash)) + 1);

        // replace the stored value of the valid credIdHash with the incorrect value
        vm.store(address(account), pubKeyXStorageSlot, bytes32(incorrectPubKeyX));

        assertEq(account.validateCreationSignature(validCreate.signature, _getValidInitCode()), Signature.State.FAILURE);
    }

    function test_FailsIfThePubKeyYDoesNotMatchThePubKeyYStored(uint256 incorrectPubKeyY) external {
        // it fails if the pubKeyY does not match the pubKeyY stored

        // make sure the fuzzed values do not match the real ones
        vm.assume(incorrectPubKeyY != validCreate.pubKeyY);

        // get the starting slot used to store the signer sequentially
        bytes32 pubKeyYStorageSlot =
            bytes32(uint256(SignerVaultWebAuthnP256R1.getSignerStartingSlot(validCreate.credIdHash)) + 2);

        // replace the stored value of the valid credIdHash with the incorrect value
        vm.store(address(account), pubKeyYStorageSlot, bytes32(incorrectPubKeyY));

        assertEq(account.validateCreationSignature(validCreate.signature, _getValidInitCode()), Signature.State.FAILURE);
    }

    // FIXME: TODO:
    function skip_test_SucceedIfTheSignatureRecoveryIsCorrect() external {
        // it succeed if the signature recovery is correct

        bytes memory createSignature = _craftCreationSignature(address(factory));

        // assert that the signature validation fails if the nonce is not equal to zero
        assertEq(
            account.validateCreationSignature(createSignature, _getValidInitCode(createSignature)),
            Signature.State.SUCCESS
        );
    }
}

contract WrapperAccount is SmartAccount {
    constructor(address _entryPoint, address _webAuthnVerifier) SmartAccount(_entryPoint, _webAuthnVerifier) { }

    // test only, expose the internal `_validateCreationSignature` method
    function validateCreationSignature(
        bytes calldata signature,
        bytes calldata initCode
    )
        external
        view
        returns (uint256)
    {
        return _validateCreationSignature(signature, initCode);
    }
}

contract MockEntryPoint {
    uint256 internal nonce;

    function getNonce(address, uint192) external pure returns (uint256) {
        // harcoded to 0 for testing the creation flow
        return 0;
    }
}

contract MockFactory is BaseTest {
    address payable public immutable accountImplementation;
    address public immutable admin;

    mapping(bytes32 usernameHash => address accountAddress) public addresses;

    function owner() public view returns (address) {
        return admin;
    }

    // reproduce the constructor of the factory with the mocked account implementation
    constructor(address _admin, address entrypoint) {
        // set the address of the expected signer of the signature
        admin = _admin;

        // deploy the implementation of the account
        WrapperAccount account = new WrapperAccount(entrypoint, makeAddr("verifier"));

        // set the address of the implementation deployed
        accountImplementation = payable(address(account));
    }

    // shortcut the real deployment/setup process for testing purposes
    function mockDeployAccount(
        uint256 pubKeyX,
        uint256 pubKeyY,
        bytes32 loginHash,
        bytes32 credIdHash
    )
        external
        returns (WrapperAccount)
    {
        // deploy the proxy for the user. During the deployment, the initialize function in the implementation contract
        // is called using the `delegatecall` opcode
        WrapperAccount account = WrapperAccount(
            payable(
                new ERC1967Proxy{ salt: loginHash }(
                    accountImplementation, abi.encodeWithSelector(SmartAccount.initialize.selector)
                )
            )
        );

        // set the first signer of the account using the parameters given
        account.addFirstSigner(pubKeyX, pubKeyY, credIdHash);

        addresses[loginHash] = address(account);

        return account;
    }

    function getAddress(bytes32 usernameHash) external view returns (address) {
        return addresses[usernameHash];
    }
}
