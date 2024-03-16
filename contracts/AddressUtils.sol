// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.19;

library AddressUtils {
    function toBytes32(address a) internal pure returns (bytes32 addr) {
        assembly {
            addr := a
        }
    }
}
