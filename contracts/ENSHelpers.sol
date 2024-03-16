// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { NameEncoder } from "@ensdomains/ens-contracts/contracts/utils/NameEncoder.sol";
import { ENS } from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import { INameResolver } from "@ensdomains/ens-contracts/contracts/resolvers/profiles/INameResolver.sol";
import { IAddrResolver } from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IAddrResolver.sol";
using NameEncoder for string;

abstract contract ENSHelpers {
    bytes32 public constant ADDR_REVERSE_NODE =
        0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;
    ENS public immutable ens; // ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
    INameResolver public immutable reverseResolver; // INameResolver(0xA2C122BE93b0074270ebeE7f6b7292C7deB45047);

    constructor(address _ens, address _reverseResolver) {
        ens = ENS(_ens);
        reverseResolver = INameResolver(_reverseResolver);
    }

    function encodeENSName(
        string memory ensName
    ) public pure returns (bytes32 node) {
        (, node) = ensName.dnsEncodeName();
    }

    function addressToEnsNode(address addr) public view returns (bytes32) {
        bytes32 reverseNode = keccak256(
            abi.encodePacked(ADDR_REVERSE_NODE, sha3HexAddress(addr))
        );
        bytes32 ensNameNode = encodeENSName(reverseResolver.name(reverseNode));
        if (ensNameNode == 0) return 0; // reverse ENS not set

        address resolver = ens.resolver(ensNameNode);

        (bool success, bytes memory res) = resolver.staticcall(
            abi.encodeWithSelector(IAddrResolver.addr.selector, ensNameNode)
        );

        if (!success || res.length != 32) {
            revert("ENS reverse record resolver error");
        }
        if (abi.decode(res, (address)) != addr) {
            revert("ENS reverse record not owned");
        }

        return ensNameNode;
    }

    /// @notice Get the resolved address of the ENS node. Returns 0 for unowned nodes.
    function getEnsNodeResolvedAddress(
        bytes32 ensNode
    ) public view returns (address) {
        address resolver = ens.resolver(ensNode);
        if (resolver == address(0)) return address(0);

        (bool success, bytes memory res) = resolver.staticcall(
            abi.encodeWithSelector(IAddrResolver.addr.selector, ensNode)
        );
        if (!success || res.length != 32) {
            return address(0);
        }

        return abi.decode(res, (address));
    }

    /**
     * @dev An optimized function to compute the sha3 of the lower-case
     *      hexadecimal representation of an Ethereum address.
     * @param addr The address to hash
     * @return ret The SHA3 hash of the lower-case hexadecimal encoding of the
     *         input address.
     * Credits: https://github.com/ensdomains/ens-contracts/blob/5aae6182fc37b315f6af3260e00ee0e3aec54b5d/contracts/reverseRegistrar/ReverseRegistrar.sol#L157-L181
     */
    function sha3HexAddress(address addr) private pure returns (bytes32 ret) {
        addr;
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
                mstore8(i, byte(and(addr, 0xf), lookup))
                addr := div(addr, 0x10)
                i := sub(i, 1)
                mstore8(i, byte(and(addr, 0xf), lookup))
                addr := div(addr, 0x10)
            }

            ret := keccak256(0, 40)
        }
    }
}
