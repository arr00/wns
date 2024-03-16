// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.19;

import { GovernorDelegateStorageV1, TimelockInterface, ENSWorldIdRegistry } from "./GovernorInterfaces.sol";
import { GovernanceToken } from "./GovernanceToken.sol";
import { AddressUtils } from "./AddressUtils.sol";

using AddressUtils for address;

contract GovernorDelegate is GovernorDelegateStorageV1 {
    /// @notice The name of this contract
    string public name;

    /// @notice The minimum settable proposal threshold
    uint public constant MIN_PROPOSAL_THRESHOLD = 1_000e18;

    /// @notice The maximum settable proposal threshold
    uint public constant MAX_PROPOSAL_THRESHOLD = 100_000e18;

    /// @notice The minimum settable voting period
    uint public constant MIN_VOTING_PERIOD = 5760; // About 24 hours

    /// @notice The max settable voting period
    uint public constant MAX_VOTING_PERIOD = 80640; // About 2 weeks

    /// @notice The min settable voting delay
    uint public constant MIN_VOTING_DELAY = 1;

    /// @notice The max settable voting delay
    uint public constant MAX_VOTING_DELAY = 40320; // About 1 week

    /// @notice The number of votes in support of a proposal required in order for a quorum to be reached and for a vote to succeed
    uint public constant quorumVotes = 400000e18; // 400,000 = 4% of governance token supplu

    /// @notice The maximum number of actions that can be included in a proposal
    uint public constant proposalMaxOperations = 10; // 10 actions

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,uint256 chainId,address verifyingContract)"
        );

    /// @notice The EIP-712 typehash for the ballot struct used by the contract
    bytes32 public constant BALLOT_TYPEHASH =
        keccak256("Ballot(uint256 proposalId,uint8 support)");

    /// @notice The EIP-712 typehash for the ballot with reason struct used by the contract
    bytes32 public constant BALLOT_WITH_REASON_TYPEHASH =
        keccak256("Ballot(uint256 proposalId,uint8 support,string reason)");

    /// @notice The EIP-712 typehash for the proposal struct used by the contract
    bytes32 public constant PROPOSAL_TYPEHASH =
        keccak256(
            "Proposal(address[] targets,uint256[] values,string[] signatures,bytes[] calldatas,string description,uint256 proposalId)"
        );

    /**
     * @notice Used to initialize the contract during delegator constructor
     * @param timelock_ The address of the Timelock
     * @param governanceToken_ The address of the governance token
     * @param votingPeriod_ The initial voting period
     * @param votingDelay_ The initial voting delay
     * @param proposalThreshold_ The initial proposal threshold
     */
    function initialize(
        string memory name_,
        address timelock_,
        address governanceToken_,
        uint votingPeriod_,
        uint votingDelay_,
        uint proposalThreshold_,
        ENSWorldIdRegistry ensWorldIdRegistry_
    ) public virtual {
        require(
            address(timelock) == address(0),
            "Governor::initialize: can only initialize once"
        );
        require(
            timelock_ != address(0),
            "Governor::initialize: invalid timelock address"
        );
        require(
            governanceToken_ != address(0),
            "Governor::initialize: invalid governance token address"
        );
        require(
            votingPeriod_ >= MIN_VOTING_PERIOD &&
                votingPeriod_ <= MAX_VOTING_PERIOD,
            "Governor::initialize: invalid voting period"
        );
        require(
            votingDelay_ >= MIN_VOTING_DELAY &&
                votingDelay_ <= MAX_VOTING_DELAY,
            "Governor::initialize: invalid voting delay"
        );
        require(
            proposalThreshold_ >= MIN_PROPOSAL_THRESHOLD &&
                proposalThreshold_ <= MAX_PROPOSAL_THRESHOLD,
            "Governor::initialize: invalid proposal threshold"
        );

        timelock = TimelockInterface(timelock_);
        governanceToken = GovernanceToken(governanceToken_);
        votingPeriod = votingPeriod_;
        votingDelay = votingDelay_;
        proposalThreshold = proposalThreshold_;
        name = name_;
        ensWorldIdRegistry = ensWorldIdRegistry_;
    }

    // TODO: Fix this
    function acceptAdmin() public {
        timelock.acceptAdmin();
    }

    /**
     * @notice Function used to propose a new proposal. Sender must have delegates above the proposal threshold
     * @param targets Target addresses for proposal calls
     * @param values Eth values for proposal calls
     * @param signatures Function signatures for proposal calls
     * @param calldatas Calldatas for proposal calls
     * @param description String description of the proposal
     * @return Proposal id of new proposal
     */
    function propose(
        address[] memory targets,
        uint[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) public returns (uint) {
        return
            proposeInternal(
                msg.sender,
                targets,
                values,
                signatures,
                calldatas,
                description
            );
    }

    /**
     * @notice Function used to propose a new proposal. Sender must have delegates above the proposal threshold
     * @param targets Target addresses for proposal calls
     * @param values Eth values for proposal calls
     * @param signatures Function signatures for proposal calls
     * @param calldatas Calldatas for proposal calls
     * @param description String description of the proposal
     * @param proposalId The id of the proposal to propose (reverted if this isn't the next proposal id)
     * @return Proposal id of new proposal
     */
    function proposeBySig(
        address[] memory targets,
        uint[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description,
        uint proposalId,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public returns (uint) {
        require(
            proposalId == proposalCount + 1,
            "Governor::proposeBySig: invalid proposal id"
        );
        address signatory;
        {
            bytes32 domainSeparator = keccak256(
                abi.encode(
                    DOMAIN_TYPEHASH,
                    keccak256(bytes(name)),
                    getChainIdInternal(),
                    address(this)
                )
            );

            bytes32[] memory hashedCalldatas = new bytes32[](calldatas.length);
            bytes32[] memory hashedSignatures = new bytes32[](
                signatures.length
            );
            for (uint256 i = 0; i < calldatas.length; ++i) {
                hashedCalldatas[i] = keccak256(calldatas[i]);
            }
            for (uint256 i = 0; i < signatures.length; ++i) {
                hashedSignatures[i] = keccak256(bytes(signatures[i]));
            }

            bytes32 structHash = keccak256(
                abi.encode(
                    PROPOSAL_TYPEHASH,
                    keccak256(abi.encodePacked(targets)),
                    keccak256(abi.encodePacked(values)),
                    keccak256(abi.encodePacked(hashedSignatures)),
                    keccak256(abi.encodePacked(hashedCalldatas)),
                    keccak256(bytes(description)),
                    proposalId
                )
            );
            bytes32 digest = keccak256(
                abi.encodePacked("\x19\x01", domainSeparator, structHash)
            );
            signatory = ecrecover(digest, v, r, s);
        }
        require(
            signatory != address(0),
            "Governor::proposeBySig: invalid signature"
        );

        return
            proposeInternal(
                signatory,
                targets,
                values,
                signatures,
                calldatas,
                description
            );
    }

    function proposeInternal(
        address proposer,
        address[] memory targets,
        uint[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) internal returns (uint) {
        // Allow addresses above proposal threshold and whitelisted addresses to propose
        (uint96 votes, ) = governanceToken.getPriorVotesWithENS(
            proposer,
            block.number - 1
        );
        require(
            votes > proposalThreshold || isWhitelisted(proposer),
            "Governor::proposeInternal: proposer votes below proposal threshold"
        );
        require(
            targets.length == values.length &&
                targets.length == signatures.length &&
                targets.length == calldatas.length,
            "Governor::proposeInternal: proposal function information arity mismatch"
        );
        require(
            targets.length != 0,
            "Governor::proposeInternal: must provide actions"
        );
        require(
            targets.length <= proposalMaxOperations,
            "Governor::proposeInternal: too many actions"
        );

        uint latestProposalId = latestProposalIds[proposer];
        if (latestProposalId != 0) {
            ProposalState proposersLatestProposalState = state(
                latestProposalId
            );
            require(
                proposersLatestProposalState != ProposalState.Active,
                "Governor::proposeInternal: one live proposal per proposer, found an already active proposal"
            );
            require(
                proposersLatestProposalState != ProposalState.Pending,
                "Governor::proposeInternal: one live proposal per proposer, found an already pending proposal"
            );
        }

        uint startBlock = block.number + votingDelay;
        uint endBlock = startBlock + votingPeriod;

        uint proposalId = ++proposalCount;
        {
            Proposal storage newProposal = proposals[proposalId];
            newProposal.proposer = proposer;
            newProposal.targets = targets;
            newProposal.values = values;
            newProposal.signatures = signatures;
            newProposal.calldatas = calldatas;
            newProposal.startBlock = startBlock;
            newProposal.endBlock = endBlock;

            latestProposalIds[proposer] = proposalId;
        }

        emit ProposalCreated(
            proposalId,
            proposer,
            targets,
            values,
            signatures,
            calldatas,
            startBlock,
            endBlock,
            description
        );
        return proposalId;
    }

    /**
     * @notice Queues a proposal of state succeeded
     * @param proposalId The id of the proposal to queue
     */
    function queue(uint proposalId) external {
        require(
            state(proposalId) == ProposalState.Succeeded,
            "Governor::queue: proposal can only be queued if it is succeeded"
        );
        Proposal storage proposal = proposals[proposalId];
        uint eta = block.timestamp + timelock.delay();
        for (uint i = 0; i < proposal.targets.length; i++) {
            queueOrRevertInternal(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                eta
            );
        }
        proposal.eta = eta;
        emit ProposalQueued(proposalId, eta);
    }

    function queueOrRevertInternal(
        address target,
        uint value,
        string memory signature,
        bytes memory data,
        uint eta
    ) internal {
        require(
            !timelock.queuedTransactions(
                keccak256(abi.encode(target, value, signature, data, eta))
            ),
            "Governor::queueOrRevertInternal: identical proposal action already queued at eta"
        );
        timelock.queueTransaction(target, value, signature, data, eta);
    }

    /**
     * @notice Executes a queued proposal if eta has passed
     * @param proposalId The id of the proposal to execute
     */
    function execute(uint proposalId) external payable {
        require(
            state(proposalId) == ProposalState.Queued,
            "Governor::execute: proposal can only be executed if it is queued"
        );
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        for (uint i = 0; i < proposal.targets.length; i++) {
            timelock.executeTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }
        emit ProposalExecuted(proposalId);
    }

    /**
     * @notice Cancels a proposal only if sender is the proposer, or proposer delegates dropped below proposal threshold
     * @param proposalId The id of the proposal to cancel
     */
    function cancel(uint proposalId) external {
        require(
            state(proposalId) != ProposalState.Executed,
            "Governor::cancel: cannot cancel executed proposal"
        );

        Proposal storage proposal = proposals[proposalId];

        // Proposer can cancel
        if (msg.sender != proposal.proposer) {
            require(
                (governanceToken.getPriorVotes(
                    proposal.proposer,
                    block.number - 1
                ) < proposalThreshold),
                "Governor::cancel: proposer above threshold"
            );
            // Whitelisted proposers can't be canceled for falling below proposal threshold
            if (isWhitelisted(proposal.proposer)) {
                require(
                    msg.sender == whitelistGuardian,
                    "Governor::cancel: whitelisted proposer"
                );
            }
        }

        proposal.canceled = true;
        for (uint i = 0; i < proposal.targets.length; i++) {
            timelock.cancelTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }

        emit ProposalCanceled(proposalId);
    }

    /**
     * @notice Gets actions of a proposal
     * @param proposalId the id of the proposal
     * @return targets of the proposal actions
     * @return values of the proposal actions
     * @return signatures of the proposal actions
     * @return calldatas of the proposal actions
     */
    function getActions(
        uint proposalId
    )
        external
        view
        returns (
            address[] memory targets,
            uint[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        )
    {
        Proposal storage p = proposals[proposalId];
        return (p.targets, p.values, p.signatures, p.calldatas);
    }

    /**
     * @notice Gets the receipt for a voter on a given proposal
     * @param proposalId the id of proposal
     * @param voter The bytes32 representation of the voter (either address as bytes32 or ENS node)
     * @return The voting receipt
     */
    function getReceipt(
        uint proposalId,
        bytes32 voter
    ) external view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }

    /**
     * @notice Gets the state of a proposal
     * @param proposalId The id of the proposal
     * @return Proposal state as a `ProposalState` enum
     */
    function state(uint proposalId) public view returns (ProposalState) {
        require(
            proposalCount >= proposalId && proposalId != 0,
            "Governor::state: invalid proposal id"
        );
        Proposal storage proposal = proposals[proposalId];
        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (
            proposal.forVotes <= proposal.againstVotes ||
            proposal.forVotes < quorumVotes
        ) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= proposal.eta + timelock.GRACE_PERIOD()) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    /**
     * @notice Cast a vote for a proposal
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     */
    function castVote(uint proposalId, VoteSupport support) external {
        emit VoteCast(
            msg.sender,
            proposalId,
            support,
            castVoteInternal(msg.sender, proposalId, support),
            ""
        );
    }

    /**
     * @notice Cast a vote for a proposal by signature
     * @dev External function that accepts EIP-712 signatures for voting on proposals.
     */
    function castVoteBySig(
        uint proposalId,
        VoteSupport support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                getChainIdInternal(),
                address(this)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(BALLOT_TYPEHASH, proposalId, support)
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        address signatory = ecrecover(digest, v, r, s);
        require(
            signatory != address(0),
            "Governor::castVoteBySig: invalid signature"
        );
        emit VoteCast(
            signatory,
            proposalId,
            support,
            castVoteInternal(signatory, proposalId, support),
            ""
        );
    }

    /**
     * @notice Cast a vote for a proposal with a reason
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     * @param reason The reason given for the vote by the voter
     */
    function castVoteWithReason(
        uint proposalId,
        VoteSupport support,
        string calldata reason
    ) external {
        emit VoteCast(
            msg.sender,
            proposalId,
            support,
            castVoteInternal(msg.sender, proposalId, support),
            reason
        );
    }

    function castVoteWithReasonBySig(
        uint proposalId,
        VoteSupport support,
        string calldata reason,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        address signatory;
        {
            bytes32 domainSeparator = keccak256(
                abi.encode(
                    DOMAIN_TYPEHASH,
                    keccak256(bytes(name)),
                    getChainIdInternal(),
                    address(this)
                )
            );
            bytes32 structHash = keccak256(
                abi.encode(
                    BALLOT_WITH_REASON_TYPEHASH,
                    proposalId,
                    support,
                    keccak256(bytes(reason))
                )
            );
            bytes32 digest = keccak256(
                abi.encodePacked("\x19\x01", domainSeparator, structHash)
            );
            signatory = ecrecover(digest, v, r, s);
        }
        require(
            signatory != address(0),
            "Governor::castVoteWithReasonBySig: invalid signature"
        );
        emit VoteCast(
            signatory,
            proposalId,
            support,
            castVoteInternal(signatory, proposalId, support),
            reason
        );
    }

    /**
     * @notice Internal function that caries out voting logic
     * @param voter The voter that is casting their vote
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     * @return The number of votes cast
     */
    function castVoteInternal(
        address voter,
        uint proposalId,
        VoteSupport support
    ) internal returns (uint96) {
        require(
            state(proposalId) == ProposalState.Active,
            "Governor::castVoteInternal: voting is closed"
        );

        Proposal storage proposal = proposals[proposalId];

        (uint96 totalVotes, bytes32 ensNode) = governanceToken
            .getPriorVotesWithENS(voter, proposal.startBlock);

        require(
            ensWorldIdRegistry.validatedEnsNodes(ensNode),
            "Governor::castVoteInternal: voter ENS node not validated"
        );

        Receipt storage receipt = proposal.receipts[ensNode];

        require(
            receipt.hasVoted == false,
            "Governor::castVoteInternal: voter already voted"
        );

        if (support == VoteSupport.Against) {
            proposal.againstVotes = proposal.againstVotes + totalVotes;
        } else if (support == VoteSupport.For) {
            proposal.forVotes = proposal.forVotes + totalVotes;
        } else {
            proposal.abstainVotes = proposal.abstainVotes + totalVotes;
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = totalVotes;

        return totalVotes;
    }

    /**
     * @notice View function which returns if an account is whitelisted
     * @param account Account to check white list status of
     * @return If the account is whitelisted
     */
    function isWhitelisted(address account) public view returns (bool) {
        return (whitelistAccountExpirations[account] > block.timestamp);
    }

    /**
     * @notice Admin function for setting the voting delay
     * @param newVotingDelay new voting delay, in blocks
     */
    function _setVotingDelay(uint newVotingDelay) external {
        require(msg.sender == admin, "Governor::_setVotingDelay: admin only");
        require(
            newVotingDelay >= MIN_VOTING_DELAY &&
                newVotingDelay <= MAX_VOTING_DELAY,
            "Governor::_setVotingDelay: invalid voting delay"
        );
        uint oldVotingDelay = votingDelay;
        votingDelay = newVotingDelay;

        emit VotingDelaySet(oldVotingDelay, votingDelay);
    }

    /**
     * @notice Admin function for setting the voting period
     * @param newVotingPeriod new voting period, in blocks
     */
    function _setVotingPeriod(uint newVotingPeriod) external {
        require(msg.sender == admin, "Governor::_setVotingPeriod: admin only");
        require(
            newVotingPeriod >= MIN_VOTING_PERIOD &&
                newVotingPeriod <= MAX_VOTING_PERIOD,
            "Governor::_setVotingPeriod: invalid voting period"
        );
        uint oldVotingPeriod = votingPeriod;
        votingPeriod = newVotingPeriod;

        emit VotingPeriodSet(oldVotingPeriod, votingPeriod);
    }

    /**
     * @notice Admin function for setting the proposal threshold
     * @dev newProposalThreshold must be greater than the hardcoded min
     * @param newProposalThreshold new proposal threshold
     */
    function _setProposalThreshold(uint newProposalThreshold) external {
        require(
            msg.sender == admin,
            "Governor::_setProposalThreshold: admin only"
        );
        require(
            newProposalThreshold >= MIN_PROPOSAL_THRESHOLD &&
                newProposalThreshold <= MAX_PROPOSAL_THRESHOLD,
            "Governor::_setProposalThreshold: invalid proposal threshold"
        );
        uint oldProposalThreshold = proposalThreshold;
        proposalThreshold = newProposalThreshold;

        emit ProposalThresholdSet(oldProposalThreshold, proposalThreshold);
    }

    /**
     * @notice Admin function for setting the whitelist expiration as a timestamp for an account. Whitelist status allows accounts to propose without meeting threshold
     * @param account Account address to set whitelist expiration for
     * @param expiration Expiration for account whitelist status as timestamp (if now < expiration, whitelisted)
     */
    function _setWhitelistAccountExpiration(
        address account,
        uint expiration
    ) external {
        require(
            msg.sender == admin || msg.sender == whitelistGuardian,
            "Governor::_setWhitelistAccountExpiration: admin only"
        );
        whitelistAccountExpirations[account] = expiration;

        emit WhitelistAccountExpirationSet(account, expiration);
    }

    /**
     * @notice Admin function for setting the whitelistGuardian. WhitelistGuardian can cancel proposals from whitelisted addresses
     * @param account Account to set whitelistGuardian to (0x0 to remove whitelistGuardian)
     */
    function _setWhitelistGuardian(address account) external {
        require(
            msg.sender == admin,
            "Governor::_setWhitelistGuardian: admin only"
        );
        address oldGuardian = whitelistGuardian;
        whitelistGuardian = account;

        emit WhitelistGuardianSet(oldGuardian, whitelistGuardian);
    }

    /**
     * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
     * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
     * @param newPendingAdmin New pending admin.
     */
    function _setPendingAdmin(address newPendingAdmin) external {
        // Check caller = admin
        require(msg.sender == admin, "Governor:_setPendingAdmin: admin only");

        // Save current value, if any, for inclusion in log
        address oldPendingAdmin = pendingAdmin;

        // Store pendingAdmin with value newPendingAdmin
        pendingAdmin = newPendingAdmin;

        // Emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin)
        emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);
    }

    /**
     * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
     * @dev Admin function for pending admin to accept role and update admin
     */
    function _acceptAdmin() external {
        // Check caller is pendingAdmin and pendingAdmin ≠ address(0)
        require(
            msg.sender == pendingAdmin && msg.sender != address(0),
            "Governor:_acceptAdmin: pending admin only"
        );

        // Save current values for inclusion in log
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;

        // Store admin with value pendingAdmin
        admin = pendingAdmin;

        // Clear the pending value
        pendingAdmin = address(0);

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
    }

    function getChainIdInternal() internal view returns (uint) {
        uint chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }
}
