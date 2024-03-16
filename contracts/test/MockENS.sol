// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockENS {
    mapping(bytes32 => address) private _resolvers;
    address private immutable _defaultResolver;

    constructor(address defaultResolver) {
        _defaultResolver = defaultResolver;
    }

    function setResolver(bytes32 ensNode, address resolverAddr) external {
        _resolvers[ensNode] = resolverAddr;
    }

    function resolver(bytes32 ensNode) external view returns (address) {
        return
            _resolvers[ensNode] == address(0)
                ? _defaultResolver
                : _resolvers[ensNode];
    }
}
