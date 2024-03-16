// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { INameResolver } from "@ensdomains/ens-contracts/contracts/resolvers/profiles/INameResolver.sol";
import { IAddrResolver } from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IAddrResolver.sol";

contract MockResolver is INameResolver, IAddrResolver {
    bytes32 public constant ADDR_REVERSE_NODE =
        0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;
    mapping(bytes32 => address payable) public addr;
    mapping(bytes32 => string) public name;

    function setAddr(bytes32 node, address payable addr_) external {
        addr[node] = addr_;
    }

    function setName(bytes32 node, string calldata name_) external {
        name[node] = name_;
    }

    function setReverseName(string memory name_) external {
        bytes32 reverseNode = keccak256(
            abi.encodePacked(ADDR_REVERSE_NODE, sha3HexAddress(msg.sender))
        );
        name[reverseNode] = name_;
    }

    /**
     * @dev An optimised function to compute the sha3 of the lower-case
     *      hexadecimal representation of an Ethereum address.
     * @param addr_ The address to hash
     * @return ret The SHA3 hash of the lower-case hexadecimal encoding of the
     *         input address.
     */
    function sha3HexAddress(address addr_) private pure returns (bytes32 ret) {
        addr_;
        ret;
        assembly {
            let
                lookup
            := 0x3031323334353637383961626364656600000000000000000000000000000000

            for {
                let i := 40
            } gt(i, 0) {

            } {
                i := sub(i, 1)
                mstore8(i, byte(and(addr_, 0xf), lookup))
                addr_ := div(addr_, 0x10)
                i := sub(i, 1)
                mstore8(i, byte(and(addr_, 0xf), lookup))
                addr_ := div(addr_, 0x10)
            }

            ret := keccak256(0, 40)
        }
    }
}
