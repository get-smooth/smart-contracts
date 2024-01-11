// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Test } from "forge-std/Test.sol";

contract BaseTest is Test {
    modifier assumeNoPrecompile(address fuzzedAddress) {
        assumeNotPrecompile(fuzzedAddress);

        _;
    }
}
