// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { BaseScript } from "../Base.s.sol";

/// @title  AccountGetSigner
/// @notice Fetch an already stored signer in the account
contract AccountGetSigner is BaseScript {
    function run() public broadcast returns (bytes32 credIdHash, uint256 pubkeyX, uint256 pubkeyY) {
        // address of the account we wanna use
        address payable accountAddress = payable(vm.envAddress("ACCOUNT"));
        SmartAccount account = SmartAccount(accountAddress);

        // the credId hash of the signer
        bytes32 passedCredIdHash = vm.envBytes32("CREDID_HASH");

        // fetch the stored signer
        (credIdHash, pubkeyX, pubkeyY) = account.getSigner(passedCredIdHash);
    }
}
