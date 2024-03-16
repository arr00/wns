// SPDX-License-Identifier: MIT
// Based on https://github.com/worldcoin/world-id-onchain-template/blob/main/contracts/src/Contract.sol
pragma solidity ^0.8.19;

import { IWorldID } from "./vendor/IWorldID.sol";
import { ByteHasher } from "./vendor/ByteHasher.sol";
import { ENSHelpers } from "./ENSHelpers.sol";

contract Registry is ENSHelpers {
    using ByteHasher for bytes;

    IWorldID public immutable worldId;

    /// @notice Thrown when attempting to reuse a nullifier
    error InvalidNullifier();

    /// @dev The contract's external nullifier hash
    uint256 internal immutable externalNullifier;

    /// @dev The World ID group ID (always 1)
    uint256 internal immutable groupId = 1;

    /// @dev Whether a nullifier hash has been used already. Used to guarantee an action is only performed once by a single person
    mapping(uint256 => bool) internal nullifierHashes;

    /// @notice Stores validated ENS nodes
    mapping(bytes32 => bool) public validatedEnsNodes;

    /// @param _worldId The WorldID instance that will verify the proofs
    /// @param _appId The World ID app ID
    /// @param _actionId The World ID action ID
    /// @param _ens The address of the ENS registry
    /// @param _reverseResolver The address of the ENS reverse resolver
    constructor(
        IWorldID _worldId,
        string memory _appId,
        string memory _actionId,
        address _ens,
        address _reverseResolver
    ) ENSHelpers(_ens, _reverseResolver) {
        worldId = _worldId;
        externalNullifier = abi
            .encodePacked(abi.encodePacked(_appId).hashToField(), _actionId)
            .hashToField();
    }

    /// @param ensNode The node to bind to
    /// @param root The root of the Merkle tree
    /// @param nullifierHash The nullifier hash for this proof, preventing double signaling
    /// @param proof The zero-knowledge proof
    function registerEns(
        bytes32 ensNode,
        uint256 root,
        uint256 nullifierHash,
        uint256[8] calldata proof
    ) public {
        // First, we make sure this person hasn't done this before
        if (nullifierHashes[nullifierHash]) revert InvalidNullifier();

        require(
            msg.sender == getEnsNodeResolvedAddress(ensNode),
            "Registry::registerEns: ENS node does not resolve to sender"
        );

        // We now verify the provided proof is valid and the user is verified by World ID
        worldId.verifyProof(
            root,
            groupId,
            abi.encodePacked(ensNode).hashToField(),
            nullifierHash,
            externalNullifier,
            proof
        );

        // We now record the user has done this, so they can't do it again (proof of uniqueness)
        nullifierHashes[nullifierHash] = true;

        // Set the ENS node as validated
        validatedEnsNodes[ensNode] = true;
    }
}
