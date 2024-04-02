// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { AccountFactory } from "src/v1/AccountFactory.sol";
import { SmartAccount } from "src/v1/Account/SmartAccount.sol";
import { BaseScript } from "../Base.s.sol";
import { Metadata } from "src/v1/Metadata.sol";

/// @title  FactoryDeployImplementation
/// @notice Deploy an implementation of the account factory
contract FactoryDeployImplementation is BaseScript {
    function run() public broadcast returns (AccountFactory) {
        address payable accountImplementation = payable(vm.envAddress("ACCOUNT_IMPLEMENTATION"));

        // 1. Check if the account implementation is deployed
        require(address(accountImplementation).code.length > 0, "Account not deployed");

        // 2. Check the version of the account is the expected one
        require(Metadata.VERSION == SmartAccount(accountImplementation).version(), "Version mismatch");

        // 3. Confirm the account implementation address with the user
        string memory prompt = string(
            abi.encodePacked(
                "The account implementation can never be changed in the factory contract."
                " If you would like to update it later on, consider proxing the account implementaton",
                " contract and passing the proxy address as the account implementation.",
                "\n\n",
                "Are you sure you want to use the following contract? (yes for approval): ",
                vm.toString(accountImplementation)
            )
        );
        try vm.prompt(prompt) returns (string memory res) {
            // solhint-disable-next-line custom-errors
            // forgefmt: disable-next-item
            require(
                keccak256(abi.encodePacked(res)) == keccak256(abi.encodePacked("yes")),
                "Script aborted by the user"
            );
        } catch (bytes memory) {
            // solhint-disable-next-line custom-errors
            revert("Entrypoint address not approved");
        }

        // 4. Deploy the account factory
        AccountFactory accountFactoryImplementation = new AccountFactory(accountImplementation);

        // 5. Check the version of the account factory is the expected one
        require(Metadata.VERSION == accountFactoryImplementation.version(), "Version mismatch");

        return accountFactoryImplementation;
    }
}
