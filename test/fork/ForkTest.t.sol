// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { BaseTest } from "../BaseTest.sol";
import { IEntryPoint } from "@eth-infinitism/interfaces/IEntryPoint.sol";
import { DummyPaymaster } from "test/fork/utils/DummyPaymaster.sol";

// Dec-07-2023 02:32:23 PM +UTC on mainnet
uint256 constant DEFAULT_BLOCK_NUMBER = 18_735_027;
// The address of the StackUp bundler (#5) on Ethereum Mainnet
address constant DEFAULT_BUNDLER = 0x9C98B1528C26Cf36E78527308c1b21d89baED700;
address constant DEFAULT_ENTRYPOINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
/**
 * TODO:
 * [x] Make this contract impersonate a bundler
 * [x] Deploy a dummy paymaster and deposit few bucks
 * [ ] Mock all the account calls -- we do not test the account implementation yet
 * [ ] Generate on the fly a new name service owner and store the address
 * [ ] Generate on the fly valid/invalid user operations
 * [ ] Test all the scenarios described
 */

/// @notice Common logic needed by all fork tests.
abstract contract ForkTest is BaseTest {
    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    IEntryPoint internal immutable ENTRYPOINT;
    uint256 internal immutable BLOCK_NUMBER;
    address internal immutable BUNDLER;
    address internal immutable USEROP_SENDER;

    /*//////////////////////////////////////////////////////////////////////////
                                     STATE
    //////////////////////////////////////////////////////////////////////////*/

    address paymaster;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    constructor() {
        // The address of the 4337 entrypoint contract
        ENTRYPOINT = IEntryPoint(vm.envOr("ENTRYPOINT_ADDRESS", DEFAULT_ENTRYPOINT));
        // The block number to fork Ethereum Mainnet at
        BLOCK_NUMBER = vm.envOr("BLOCK_NUMBER", DEFAULT_BLOCK_NUMBER);
        // Valid BUNDLER address
        BUNDLER = vm.envOr("BUNDLER_ADDRESS", DEFAULT_BUNDLER);
        // The sender of the user operation
        USEROP_SENDER = vm.envAddress("USEROP_SENDER_ADDRESS");
    }

    // must be passed to the setUp function of the test contracts
    modifier initFork() {
        // Fork Ethereum Mainnet at a specific block number
        vm.createSelectFork({ blockNumber: BLOCK_NUMBER, urlOrAlias: "mainnet" });

        // Set the msg.sender and tx.origin to the address of the bundler
        vm.startPrank(BUNDLER, BUNDLER);

        // We increase the balance of the bundler by 10 ETHs
        vm.deal(BUNDLER, 10 ether);

        // We deploy a dummy paymaster, deposit 2 ETH and store the address in the paymaster variable
        DummyPaymaster dummyPaymaster = new DummyPaymaster{ salt: "fork_test_paymaster" }(address(ENTRYPOINT));
        dummyPaymaster.deposit{ value: 2 ether }();
        paymaster = address(dummyPaymaster);

        _;

        vm.stopPrank();
    }
}
