// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import {
    GovernorBravoDelegateStorageV3,
    GovernorBravoEvents,
    TimelockInterface,
    CompInterface,
    GovernorAlphaInterface
} from "./GovernorBravoInterfaces.sol";

/// @custom:security-contact security@compound.finance
contract GovernorBravoDelegate is GovernorBravoDelegateStorageV3, GovernorBravoEvents {
    /// @notice The name of this contract
    string public constant name = "Compound Governor Bravo";

    /// @notice The minimum settable proposal threshold
    uint256 public constant MIN_PROPOSAL_THRESHOLD = 1000e18; // 1,000 Comp

    /// @notice The maximum settable proposal threshold
    uint256 public constant MAX_PROPOSAL_THRESHOLD = 100000e18; //100,000 Comp

    /// @notice The minimum settable voting period
    uint256 public constant MIN_VOTING_PERIOD = 5760; // About 24 hours

    /// @notice The max settable voting period
    uint256 public constant MAX_VOTING_PERIOD = 80640; // About 2 weeks

    /// @notice The min settable voting delay
    uint256 public constant MIN_VOTING_DELAY = 1;

    /// @notice The max settable voting delay
    uint256 public constant MAX_VOTING_DELAY = 40320; // About 1 week

    /// @notice The number of votes in support of a proposal required in order for a quorum to be reached and for a vote to succeed
    uint256 public constant quorumVotes = 400000e18; // 400,000 = 4% of Comp

    /// @notice The maximum number of actions that can be included in a proposal
    uint256 public constant proposalMaxOperations = 10; // 10 actions

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the ballot struct used by the contract
    bytes32 public constant BALLOT_TYPEHASH = keccak256("Ballot(uint256 proposalId,uint8 support)");

    /// @notice The EIP-712 typehash for the ballot with reason struct used by the contract
    bytes32 public constant BALLOT_WITH_REASON_TYPEHASH =
        keccak256("Ballot(uint256 proposalId,uint8 support,string reason)");

    /// @notice The EIP-712 typehash for the proposal struct used by the contract
    bytes32 public constant PROPOSAL_TYPEHASH = keccak256(
        "Proposal(address[] targets,uint256[] values,string[] signatures,bytes[] calldatas,string description,uint256 proposalId)"
    );

    /**
     * @notice Used to initialize the contract during delegator constructor
     * @param timelock_ The address of the Timelock
     * @param comp_ The address of the COMP token
     * @param votingPeriod_ The initial voting period
     * @param votingDelay_ The initial voting delay
     * @param proposalThreshold_ The initial proposal threshold
     */
    function initialize(
        address timelock_,
        address comp_,
        uint256 votingPeriod_,
        uint256 votingDelay_,
        uint256 proposalThreshold_
    ) public virtual {
        require(address(timelock) == address(0), "GovernorBravo::initialize: can only initialize once");
        require(msg.sender == admin, "GovernorBravo::initialize: admin only");
        require(timelock_ != address(0), "GovernorBravo::initialize: invalid timelock address");
        require(comp_ != address(0), "GovernorBravo::initialize: invalid comp address");
        require(
            votingPeriod_ >= MIN_VOTING_PERIOD && votingPeriod_ <= MAX_VOTING_PERIOD,
            "GovernorBravo::initialize: invalid voting period"
        );
        require(
            votingDelay_ >= MIN_VOTING_DELAY && votingDelay_ <= MAX_VOTING_DELAY,
            "GovernorBravo::initialize: invalid voting delay"
        );
        require(
            proposalThreshold_ >= MIN_PROPOSAL_THRESHOLD && proposalThreshold_ <= MAX_PROPOSAL_THRESHOLD,
            "GovernorBravo::initialize: invalid proposal threshold"
        );

        timelock = TimelockInterface(timelock_);
        comp = CompInterface(comp_);
        votingPeriod = votingPeriod_;
        votingDelay = votingDelay_;
        proposalThreshold = proposalThreshold_;
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
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) public returns (uint256) {
        return proposeInternal(msg.sender, targets, values, signatures, calldatas, description);
    }

    /**
     * @notice Function used to propose a new proposal. Sender must have delegates above the proposal threshold
     * @param targets Target addresses for proposal calls
     * @param values Eth values for proposal calls
     * @param signatures Function signatures for proposal calls
     * @param calldatas Calldatas for proposal calls
     * @param description String description of the proposal
     * @param proposalId The id of the proposal to propose (reverted if this isn't the next proposal id)
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     * @return Proposal id of new proposal
     */
    function proposeBySig(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description,
        uint256 proposalId,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public returns (uint256) {
        require(proposalId == proposalCount + 1, "GovernorBravo::proposeBySig: invalid proposal id");
        address signatory;
        {
            bytes32 domainSeparator =
                keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), getChainIdInternal(), address(this)));

            bytes32[] memory hashedCalldatas = new bytes32[](calldatas.length);
            bytes32[] memory hashedSignatures = new bytes32[](signatures.length);
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
            bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
            signatory = ecrecover(digest, v, r, s);
        }
        require(signatory != address(0), "GovernorBravo::proposeBySig: invalid signature");

        return proposeInternal(signatory, targets, values, signatures, calldatas, description);
    }

    function proposeInternal(
        address proposer,
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) internal returns (uint256) {
        // Reject proposals before initiating as Governor
        require(initialProposalId != 0, "GovernorBravo::proposeInternal: Governor Bravo not active");
        // Allow addresses above proposal threshold and whitelisted addresses to propose
        require(
            comp.getPriorVotes(proposer, block.number - 1) > proposalThreshold || isWhitelisted(proposer),
            "GovernorBravo::proposeInternal: proposer votes below proposal threshold"
        );
        require(
            targets.length == values.length && targets.length == signatures.length && targets.length == calldatas.length,
            "GovernorBravo::proposeInternal: proposal function information arity mismatch"
        );
        require(targets.length != 0, "GovernorBravo::proposeInternal: must provide actions");
        require(targets.length <= proposalMaxOperations, "GovernorBravo::proposeInternal: too many actions");

        uint256 latestProposalId = latestProposalIds[proposer];
        if (latestProposalId != 0) {
            ProposalState proposersLatestProposalState = state(latestProposalId);
            require(
                proposersLatestProposalState != ProposalState.Active,
                "GovernorBravo::proposeInternal: one live proposal per proposer, found an already active proposal"
            );
            require(
                proposersLatestProposalState != ProposalState.Pending,
                "GovernorBravo::proposeInternal: one live proposal per proposer, found an already pending proposal"
            );
        }

        uint256 startBlock = block.number + votingDelay;
        uint256 endBlock = startBlock + votingPeriod;

        proposalCount++;
        uint256 newProposalID = proposalCount;
        Proposal storage newProposal = proposals[newProposalID];
        // This should never happen but add a check in case.
        require(newProposal.id == 0, "GovernorBravo::proposeInternal: ProposalID collision");
        newProposal.id = newProposalID;
        newProposal.proposer = proposer;
        newProposal.eta = 0;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.signatures = signatures;
        newProposal.calldatas = calldatas;
        newProposal.startBlock = startBlock;
        newProposal.endBlock = endBlock;
        newProposal.forVotes = 0;
        newProposal.againstVotes = 0;
        newProposal.abstainVotes = 0;
        newProposal.canceled = false;
        newProposal.executed = false;

        latestProposalIds[newProposal.proposer] = newProposal.id;

        emit ProposalCreated(
            newProposal.id, proposer, targets, values, signatures, calldatas, startBlock, endBlock, description
        );
        return newProposal.id;
    }

    /**
     * @notice Queues a proposal of state succeeded
     * @param proposalId The id of the proposal to queue
     */
    function queue(uint256 proposalId) external {
        require(
            state(proposalId) == ProposalState.Succeeded,
            "GovernorBravo::queue: proposal can only be queued if it is succeeded"
        );
        Proposal storage proposal = proposals[proposalId];
        uint256 eta = block.timestamp + timelock.delay();
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            queueOrRevertInternal(
                proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], eta
            );
        }
        proposal.eta = eta;
        emit ProposalQueued(proposalId, eta);
    }

    function queueOrRevertInternal(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) internal {
        require(
            !timelock.queuedTransactions(keccak256(abi.encode(target, value, signature, data, eta))),
            "GovernorBravo::queueOrRevertInternal: identical proposal action already queued at eta"
        );
        timelock.queueTransaction(target, value, signature, data, eta);
    }

    /**
     * @notice Executes a queued proposal if eta has passed
     * @param proposalId The id of the proposal to execute
     */
    function execute(uint256 proposalId) external payable {
        require(
            state(proposalId) == ProposalState.Queued,
            "GovernorBravo::execute: proposal can only be executed if it is queued"
        );
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            timelock.executeTransaction(
                proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], proposal.eta
            );
        }
        emit ProposalExecuted(proposalId);
    }

    /**
     * @notice Cancels a proposal if sender is the proposer or proposalGuardian. Can be called by anyone if the proposer delegates dropped below proposal threshold.
     * @param proposalId The id of the proposal to cancel
     */
    function cancel(uint256 proposalId) external {
        require(state(proposalId) != ProposalState.Executed, "GovernorBravo::cancel: cannot cancel executed proposal");

        Proposal storage proposal = proposals[proposalId];

        // ProposalGuardian is only active if the expiration is in the future
        address proposalGuardian =
            proposalGuardian.expiration >= block.timestamp ? proposalGuardian.account : address(0);

        // Proposer or proposalGuardian can cancel
        if (msg.sender != proposal.proposer && msg.sender != proposalGuardian) {
            require(
                (comp.getPriorVotes(proposal.proposer, block.number - 1) < proposalThreshold),
                "GovernorBravo::cancel: proposer above threshold"
            );
            // Only whitelist guardian can cancel proposals from whitelisted proposers with delegations below the proposal threshold
            if (isWhitelisted(proposal.proposer)) {
                require(msg.sender == whitelistGuardian, "GovernorBravo::cancel: whitelisted proposer");
            }
        }

        proposal.canceled = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            timelock.cancelTransaction(
                proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], proposal.eta
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
    function getActions(uint256 proposalId)
        external
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
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
     * @param voter The address of the voter
     * @return The voting receipt
     */
    function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }

    /**
     * @notice Gets the state of a proposal
     * @param proposalId The id of the proposal
     * @return Proposal state as a `ProposalState` enum
     */
    function state(uint256 proposalId) public view returns (ProposalState) {
        require(
            proposalCount >= proposalId && proposalId > initialProposalId, "GovernorBravo::state: invalid proposal id"
        );
        Proposal storage proposal = proposals[proposalId];
        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < quorumVotes) {
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
    function castVote(uint256 proposalId, uint8 support) external {
        emit VoteCast(msg.sender, proposalId, support, castVoteInternal(msg.sender, proposalId, support), "");
    }

    /**
     * @notice Cast a vote for a proposal by signature
     * @dev External function that accepts EIP-712 signatures for voting on proposals.
     */
    function castVoteBySig(uint256 proposalId, uint8 support, uint8 v, bytes32 r, bytes32 s) external {
        bytes32 domainSeparator =
            keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), getChainIdInternal(), address(this)));
        bytes32 structHash = keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "GovernorBravo::castVoteBySig: invalid signature");
        emit VoteCast(signatory, proposalId, support, castVoteInternal(signatory, proposalId, support), "");
    }

    /**
     * @notice Cast a vote for a proposal with a reason
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     * @param reason The reason given for the vote by the voter
     */
    function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason) external {
        emit VoteCast(msg.sender, proposalId, support, castVoteInternal(msg.sender, proposalId, support), reason);
    }

    /**
     * @notice Cast a vote for a proposal with a reason by `ERC712` signature
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     * @param reason The reason given for the vote by the voter
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function castVoteWithReasonBySig(
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        address signatory;
        {
            bytes32 domainSeparator =
                keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), getChainIdInternal(), address(this)));
            bytes32 structHash =
                keccak256(abi.encode(BALLOT_WITH_REASON_TYPEHASH, proposalId, support, keccak256(bytes(reason))));
            bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
            signatory = ecrecover(digest, v, r, s);
        }
        require(signatory != address(0), "GovernorBravo::castVoteWithReasonBySig: invalid signature");
        emit VoteCast(signatory, proposalId, support, castVoteInternal(signatory, proposalId, support), reason);
    }

    /**
     * @notice Internal function that caries out voting logic
     * @param voter The voter that is casting their vote
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     * @return The number of votes cast
     */
    function castVoteInternal(address voter, uint256 proposalId, uint8 support) internal returns (uint96) {
        require(state(proposalId) == ProposalState.Active, "GovernorBravo::castVoteInternal: voting is closed");
        require(support <= 2, "GovernorBravo::castVoteInternal: invalid vote type");
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        require(receipt.hasVoted == false, "GovernorBravo::castVoteInternal: voter already voted");
        uint96 votes = comp.getPriorVotes(voter, proposal.startBlock);

        if (support == 0) {
            proposal.againstVotes = proposal.againstVotes + votes;
        } else if (support == 1) {
            proposal.forVotes = proposal.forVotes + votes;
        } else if (support == 2) {
            proposal.abstainVotes = proposal.abstainVotes + votes;
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        return votes;
    }

    /**
     * @notice View function which returns if an account is whitelisted
     * @param account Account to check whitelist status of
     * @return If the account is whitelisted
     */
    function isWhitelisted(address account) public view returns (bool) {
        return (whitelistAccountExpirations[account] > block.timestamp);
    }

    /**
     * @notice Admin function for setting the voting delay
     * @param newVotingDelay new voting delay, in blocks
     */
    function _setVotingDelay(uint256 newVotingDelay) external {
        require(msg.sender == admin, "GovernorBravo::_setVotingDelay: admin only");
        require(
            newVotingDelay >= MIN_VOTING_DELAY && newVotingDelay <= MAX_VOTING_DELAY,
            "GovernorBravo::_setVotingDelay: invalid voting delay"
        );
        uint256 oldVotingDelay = votingDelay;
        votingDelay = newVotingDelay;

        emit VotingDelaySet(oldVotingDelay, votingDelay);
    }

    /**
     * @notice Admin function for setting the voting period
     * @param newVotingPeriod new voting period, in blocks
     */
    function _setVotingPeriod(uint256 newVotingPeriod) external {
        require(msg.sender == admin, "GovernorBravo::_setVotingPeriod: admin only");
        require(
            newVotingPeriod >= MIN_VOTING_PERIOD && newVotingPeriod <= MAX_VOTING_PERIOD,
            "GovernorBravo::_setVotingPeriod: invalid voting period"
        );
        uint256 oldVotingPeriod = votingPeriod;
        votingPeriod = newVotingPeriod;

        emit VotingPeriodSet(oldVotingPeriod, votingPeriod);
    }

    /**
     * @notice Admin function for setting the proposal threshold
     * @dev newProposalThreshold must be greater than the hardcoded min
     * @param newProposalThreshold new proposal threshold
     */
    function _setProposalThreshold(uint256 newProposalThreshold) external {
        require(msg.sender == admin, "GovernorBravo::_setProposalThreshold: admin only");
        require(
            newProposalThreshold >= MIN_PROPOSAL_THRESHOLD && newProposalThreshold <= MAX_PROPOSAL_THRESHOLD,
            "GovernorBravo::_setProposalThreshold: invalid proposal threshold"
        );
        uint256 oldProposalThreshold = proposalThreshold;
        proposalThreshold = newProposalThreshold;

        emit ProposalThresholdSet(oldProposalThreshold, proposalThreshold);
    }

    /**
     * @notice Admin function for setting the whitelist expiration as a timestamp for an account. Whitelist status allows accounts to propose without meeting threshold
     * @param account Account address to set whitelist expiration for
     * @param expiration Expiration for account whitelist status as timestamp (if now < expiration, whitelisted)
     */
    function _setWhitelistAccountExpiration(address account, uint256 expiration) external {
        require(
            msg.sender == admin || msg.sender == whitelistGuardian,
            "GovernorBravo::_setWhitelistAccountExpiration: admin only"
        );
        whitelistAccountExpirations[account] = expiration;

        emit WhitelistAccountExpirationSet(account, expiration);
    }

    /**
     * @notice Admin function for setting the whitelistGuardian. WhitelistGuardian can cancel proposals from whitelisted addresses
     * @param account Account to set whitelistGuardian to (0x0 to remove whitelistGuardian)
     */
    function _setWhitelistGuardian(address account) external {
        require(msg.sender == admin, "GovernorBravo::_setWhitelistGuardian: admin only");
        address oldGuardian = whitelistGuardian;
        whitelistGuardian = account;

        emit WhitelistGuardianSet(oldGuardian, whitelistGuardian);
    }

    /**
     * @notice Admin function for setting the proposalGuardian. ProposalGuardian can cancel all proposals.
     * @param newProposalGuardian The account and expiration for the new proposal guardian.
     */
    function _setProposalGuardian(ProposalGuardian memory newProposalGuardian) external {
        require(msg.sender == admin, "GovernorBravo::_setProposalGuardian: admin only");

        emit ProposalGuardianSet(
            proposalGuardian.account,
            proposalGuardian.expiration,
            newProposalGuardian.account,
            newProposalGuardian.expiration
        );

        proposalGuardian = newProposalGuardian;
    }

    /**
     * @notice Initiate the GovernorBravo contract
     * @dev Admin only. Sets initial proposal id which initiates the contract, ensuring a continuous proposal id count
     * @param governorAlpha The address for the Governor to continue the proposal id count from
     */
    function _initiate(address governorAlpha) external {
        require(msg.sender == admin, "GovernorBravo::_initiate: admin only");
        require(initialProposalId == 0, "GovernorBravo::_initiate: can only initiate once");
        proposalCount = GovernorAlphaInterface(governorAlpha).proposalCount();
        initialProposalId = proposalCount;
        timelock.acceptAdmin();
    }

    /**
     * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
     * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
     * @param newPendingAdmin New pending admin.
     */
    function _setPendingAdmin(address newPendingAdmin) external {
        // Check caller = admin
        require(msg.sender == admin, "GovernorBravo:_setPendingAdmin: admin only");

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
            msg.sender == pendingAdmin && msg.sender != address(0), "GovernorBravo:_acceptAdmin: pending admin only"
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

    function getChainIdInternal() internal view returns (uint256) {
        uint256 chainId;
        assembly ("memory-safe") {
            chainId := chainid()
        }
        return chainId;
    }
}
