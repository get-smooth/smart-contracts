// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  AccountCheckSigner
/// @notice Check if an account has a specific signer
contract AccountCheckSigner is BaseScript {
    function run() public broadcast returns (bool hasSigner) {
        // address of the account we wanna use
        address payable accountAddress = payable(vm.envAddress("ACCOUNT"));
        SmartAccount account = SmartAccount(accountAddress);

        // the credId hash of the signer
        bytes32 passedCredIdHash = vm.envBytes32("CREDID_HASH");

        // fetch the stored signer
        (bytes32 credIdHash, uint256 pubkeyX, uint256 pubkeyY) = account.getSigner(passedCredIdHash);

        // check if the signer exists
        if (credIdHash == bytes32(0) || pubkeyX == 0 || pubkeyY == 0) {
            return false;
        }

        return true;
    }
}
