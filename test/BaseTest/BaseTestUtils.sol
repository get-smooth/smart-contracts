// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import { Test } from "forge-std/Test.sol";

/// @title BaseTestUtils
/// @notice This contract exposes some generic utility functions to be used in your tests
contract BaseTestUtils is Test {
    // useful to bound a number to a valid P256R1 value
    uint256 internal constant P256R1_MAX = type(uint256).max;

    // use it the same way you use Foundry's `bound` function
    function boundP256R1(uint256 x) internal pure returns (uint256) {
        return x % P256R1_MAX;
    }

    // utility function to truncate a bytes array. Call the internal version of the function in your tests.
    function _truncBytes(
        bytes calldata data,
        uint256 start,
        uint256 end
    )
        external
        pure
        returns (bytes memory truncData)
    {
        truncData = data[start:end];
    }

    function truncBytes(bytes memory data, uint256 start, uint256 end) internal view returns (bytes memory truncData) {
        truncData = BaseTestUtils(address(this))._truncBytes(data, start, end);
    }
}
