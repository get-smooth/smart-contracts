// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.20 <0.9.0;

import { SignerVaultVanillaP256K1 } from "src/utils/SignerVaultVanillaP256K1.sol";
import { SignerVaultWebAuthnP256R1 } from "src/utils/SignerVaultWebAuthnP256R1.sol";
import { BaseTest } from "test/BaseTest/BaseTest.sol";

contract SignerVault is BaseTest {
    SignerVaultTestWrapper private implementation;

    function setUp() external {
        implementation = new SignerVaultTestWrapper();
    }

    function test_AllHaveDifferentRootSlots() external view {
        // it should all have different root slot

        assertNotEq(implementation.webAuthnP256R1Root(), implementation.vanillaP256K1Root());
    }

    function test_AllDerivateToADifferentAddressGivenTheSameKey(bytes32 clientIdHash, address signer) external view {
        // it should all derivate to a different address given the same key

        vm.assume(clientIdHash != keccak256(""));
        // bound the signer to an address not used for precompile contracts
        signer = address(uint160((bound(uint256(uint160(signer)), 100, type(uint256).max))));

        assertNotEq(
            implementation.getWebauthnP256R1StartingSlot(clientIdHash),
            implementation.getWebauthnP256R1StartingSlot(signer)
        );
    }
}

contract SignerVaultTestWrapper {
    function webAuthnP256R1Root() external pure returns (bytes32) {
        return SignerVaultWebAuthnP256R1.ROOT;
    }

    function vanillaP256K1Root() external pure returns (bytes32) {
        return SignerVaultVanillaP256K1.ROOT;
    }

    function getWebauthnP256R1StartingSlot(bytes32 clientIdHash) external pure returns (bytes32) {
        return SignerVaultWebAuthnP256R1.getSignerStartingSlot(clientIdHash);
    }

    function getWebauthnP256R1StartingSlot(address signer) external pure returns (bytes32) {
        return SignerVaultVanillaP256K1.getSignerStartingSlot(signer);
    }
}
