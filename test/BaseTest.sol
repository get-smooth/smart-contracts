// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Test } from "forge-std/Test.sol";

contract BaseTest is Test {
    uint256 constant P256R1_MAX =
        115_792_089_210_356_248_762_697_446_949_407_573_530_086_143_415_290_314_195_533_631_308_867_097_853_951;

    modifier assumeNoPrecompile(address fuzzedAddress) {
        assumeNotPrecompile(fuzzedAddress);

        _;
    }

    function boundP256R1(uint256 x) internal pure returns (uint256) {
        return x % P256R1_MAX;
    }
}
