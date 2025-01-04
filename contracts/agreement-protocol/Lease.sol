pragma solidity ^0.8.20;

import "@kleros/kleros-v2-contracts/arbitration/interfaces/IArbitratorV2.sol"; // Import the Arbitrator contract
import "@kleros/kleros-v2-contracts/arbitration/interfaces/IArbitrableV2.sol"; // Import the Arbitrable contract
import "@ethereum-attestation-service/eas-sdk/contracts/IEAS.sol"; // Import EAS interface
import "../estates-protocol/EstateRegistry.sol";

contract Lease is IArbitrableV2, EAS {
    address owner;
    // Reference to the Ethereum Attestation Service (EAS)
    IEAS public eas;

    // Reference to the arbitrator
    IArbitrator public arbitrator;

    // Reference to WETH for dispute fee payments
    IERC20 public immutable weth;

    // Struct to define a lease agreement
    struct LeaseData {
        uint256 estateId; // The ID of the estate associated with the lease
        address tenant; // The tenant's address
        address landlord; // The landlord's address
        uint256 rentAmount; // Rent payment amount
        uint256 securityDeposit; // Security deposit amount
        uint256 leaseStartDate; // Lease start date
        uint256 leaseEndDate; // Lease end date
        string propertyAddress; // Address of the property
        bytes32 easUID; // UID for EAS attestation
        bool active; // Status of the lease
    }

    // Mapping from estate ID to lease details
    mapping(uint256 => LeaseData) public leases;

    // Mapping from arbitrator dispute IDs to estate IDs
    mapping(uint256 => uint256) public arbitratorDisputes;

    // Event emitted when a dispute is created
    event LeaseDisputed(uint256 indexed estateId, uint256 indexed disputeId);

    // Event emitted when a ruling is given
    event LeaseRuling(uint256 indexed estateId, uint256 ruling);

    // Modifier to restrict access to estate owners
    modifier onlyEstateOwner() {
        // Implement validation logic for estate owners
        // require(msg.sender == owner, "Only Contract Owner Can Call This Contract")
        _;
    }

    constructor(address _eas, address _arbitrator, address _weth) {
        eas = IEAS(_eas);
        arbitrator = IArbitrator(_arbitrator);
        weth = IERC20(_weth);
        owner = msg.sender;
    }

    /**
     * @dev Creates a new lease and stores it in the mapping.
     * @param estateId The ID of the estate this lease is associated with.
     * @param tenant The address of the tenant.
     * @param landlord The address of the landlord.
     * @param rentAmount The rent payment amount.
     * @param securityDeposit The security deposit amount.
     * @param leaseStartDate The start date of the lease (timestamp).
     * @param leaseEndDate The end date of the lease (timestamp).
     * @param propertyAddress The address of the property.
     */
    function createLease(
        uint256 estateId,
        address tenant,
        address landlord,
        uint256 rentAmount,
        uint256 securityDeposit,
        uint256 leaseStartDate,
        uint256 leaseEndDate,
        string calldata propertyAddress
    ) external onlyEstateOwner {
        require(
            leases[estateId].active == false,
            "Lease already exists for estate"
        );

        leases[estateId] = LeaseData({
            estateId: estateId,
            tenant: tenant,
            landlord: landlord,
            rentAmount: rentAmount,
            securityDeposit: securityDeposit,
            leaseStartDate: leaseStartDate,
            leaseEndDate: leaseEndDate,
            propertyAddress: propertyAddress,
            easUID: bytes32(0), // Placeholder for EAS UID
            active: true
        });
    }

    /**
     * @dev Attests a lease on EAS.
     * @param estateId The ID of the estate associated with the lease.
     * @param schemaUID The UID of the schema for attestation.
     */
    function attestLease(uint256 estateId, bytes32 schemaUID) external {
        LeaseData storage lease = leases[estateId];
        require(lease.landlord == msg.sender, "Only the landlord can attest");
        require(lease.active, "Lease is not active");

        // Prepare attestation data
        IEAS.AttestationRequestData memory requestData = IEAS
            .AttestationRequestData({
                recipient: lease.tenant,
                expirationTime: lease.leaseEndDate, // Expiration equals lease end date
                revocable: true,
                refUID: bytes32(0), // No referenced attestation
                data: abi.encode(lease), // Custom attestation data
                value: 0 // No ETH sent to resolver
            });

        // Create an attestation
        IEAS.AttestationRequest memory request = IEAS.AttestationRequest({
            schema: schemaUID,
            data: requestData
        });

        bytes32 uid = eas.attest{value: 0}(request);
        lease.easUID = uid;
    }

    /**
     * @dev Revokes a lease attestation on EAS.
     * @param estateId The ID of the estate associated with the lease.
     */
    function revokeLease(uint256 estateId) external {
        LeaseData storage lease = leases[estateId];
        require(lease.landlord == msg.sender, "Only the landlord can revoke");
        require(lease.easUID != bytes32(0), "Lease is not attested");

        IEAS.RevocationRequestData memory revocationData = IEAS
            .RevocationRequestData({
                uid: lease.easUID,
                value: 0 // No ETH sent to resolver
            });

        IEAS.RevocationRequest memory revocationRequest = IEAS
            .RevocationRequest({
                schema: bytes32(0), // Schema UID not required for revocation
                data: revocationData
            });

        eas.revoke(revocationRequest);
        lease.easUID = bytes32(0); // Reset UID to indicate revocation
        lease.active = false; // Mark the lease as inactive
    }

    function fundLease() returns () {}

    function concludeLease() returns () {}

    /**
     * @dev Creates a dispute for a lease.
     * @param estateId The ID of the estate associated with the lease.
     * @param metaEvidence The metadata associated with the dispute (e.g., IPFS hash or template URI).
     * @param arbitrationFee The fee required for arbitration in WETH.
     */
    function disputeLease(
        uint256 estateId,
        string calldata metaEvidence,
        uint256 arbitrationFee
    ) external {
        LeaseData storage lease = leases[estateId];
        require(lease.active, "Lease is not active");
        require(
            msg.sender == lease.tenant || msg.sender == lease.landlord,
            "Only tenant or landlord can dispute"
        );

        // Transfer arbitration fee in WETH
        require(
            weth.transferFrom(msg.sender, address(this), arbitrationFee),
            "WETH transfer failed"
        );
        require(
            weth.approve(address(arbitrator), arbitrationFee),
            "WETH approve failed"
        );

        // Create dispute
        uint256 disputeId = arbitrator.createDispute(
            2,
            abi.encode(metaEvidence)
        );
        lease.disputeId = disputeId;
        arbitratorDisputes[disputeId] = estateId;

        emit LeaseDisputed(estateId, disputeId);
    }

    /**
     * @dev Handles the ruling from the arbitrator.
     * @param _disputeID The ID of the dispute in the arbitrator contract.
     * @param _ruling The ruling given by the arbitrator (1 for tenant, 2 for landlord).
     */
    function rule(uint256 _disputeID, uint256 _ruling) external override {
        require(msg.sender == address(arbitrator), "Only arbitrator can call");
        require(_ruling == 1 || _ruling == 2, "Invalid ruling");

        uint256 estateId = arbitratorDisputes[_disputeID];
        LeaseData storage lease = leases[estateId];
        require(lease.active, "Lease is not active");

        // Apply the ruling logic
        if (_ruling == 1) {
            // Tenant wins: refund security deposit
            payable(lease.tenant).transfer(lease.securityDeposit);
        } else if (_ruling == 2) {
            // Landlord wins: security deposit goes to landlord
            payable(lease.landlord).transfer(lease.securityDeposit);
        }

        lease.active = false; // Conclude the lease

        emit LeaseRuling(estateId, _ruling);
    }

    function withdrawLeasePayments(
        string estateId
    ) onlyEstateOwner returns () {}

    /**
     * @dev Retrieves lease details.
     * @param estateId The ID of the estate.
     * @return LeaseData The lease details.
     */
    function getLease(
        uint256 estateId
    ) external view returns (LeaseData memory) {
        return leases[estateId];
    }
}
