pragma solidity ^0.8.20;

import "@kleros/kleros-v2-contracts/arbitration/interfaces/IArbitratorV2.sol"; // Import the Arbitrator contract
import "@kleros/kleros-v2-contracts/arbitration/interfaces/IArbitrableV2.sol"; // Import the Arbitrable contract
import "@ethereum-attestation-service/eas-sdk/contracts/IEAS.sol"; // Import EAS interface
import "../estates-protocol/EstateRegistry.sol";

contract Invoice is IArbitrableV2 {
    // Reference to the Ethereum Attestation Service (EAS)
    IEAS public eas;

    // Reference to the arbitrator
    IArbitrator public arbitrator;

    // Reference to WETH for dispute fee payments
    IERC20 public immutable weth;

    // Struct to define an invoice
    struct InvoiceData {
        uint256 estateId; // The ID of the estate
        address issuer; // The address issuing the invoice
        address payer; // The address responsible for payment
        uint256 amountDue; // The amount due
        uint256 issueDate; // The date the invoice was issued
        uint256 dueDate; // The date the payment is due
        string description; // Description of the invoice
        string serviceType; // Type of service related to the invoice
        bool isPaid; // Whether the invoice is paid
        bytes32 easUID; // The unique identifier for EAS attestations
    }

    // Mapping from estate ID to invoices
    mapping(uint256 => InvoiceData) public invoices;

    // Mapping from arbitrator dispute IDs to invoice IDs
    mapping(uint256 => uint256) public arbitratorDisputes;

    // Arbitrator extra data for dispute creation
    bytes public arbitratorExtraData;

    // Events
    event InvoiceDisputed(
        uint256 indexed invoiceId,
        uint256 indexed disputeId,
        string metaEvidenceURI
    );
    event InvoiceRuling(uint256 indexed invoiceId, uint256 ruling);

    // Modifier to restrict access to estate owners
    modifier onlyEstateOwner() {
        // Add your logic to validate the caller as an estate owner
        _;
    }

    constructor(
        address _eas,
        address _arbitrator,
        address _weth,
        bytes memory _arbitratorExtraData
    ) {
        eas = IEAS(_eas);
        arbitrator = IArbitrator(_arbitrator);
        weth = IERC20(_weth);
        arbitratorExtraData = _arbitratorExtraData;
    }

    /**
     * @dev Creates a new invoice and stores it in the mapping.
     * @param estateId The ID of the estate this invoice belongs to.
     * @param payer The address responsible for payment.
     * @param amountDue The amount due for this invoice.
     * @param dueDate The date by which the invoice must be paid.
     * @param description A brief description of the invoice.
     * @param serviceType The type of service (e.g., utilities, repairs).
     */
    function createInvoice(
        uint256 estateId,
        address payer,
        uint256 amountDue,
        uint256 dueDate,
        string calldata description,
        string calldata serviceType
    ) external onlyEstateOwner {
        uint256 issueDate = block.timestamp;

        // Store the invoice in the mapping
        invoices[estateId] = InvoiceData({
            estateId: estateId,
            issuer: msg.sender,
            payer: payer,
            amountDue: amountDue,
            issueDate: issueDate,
            dueDate: dueDate,
            description: description,
            serviceType: serviceType,
            isPaid: false,
            easUID: bytes32(0) // Placeholder for EAS UID
        });
    }

    /**
     * @dev Attests an invoice on EAS.
     * @param estateId The ID of the estate associated with the invoice.
     * @param schemaUID The UID of the schema for attestation.
     */
    function attestInvoice(uint256 estateId, bytes32 schemaUID) external {
        InvoiceData storage invoice = invoices[estateId];
        require(invoice.issuer == msg.sender, "Only the issuer can attest");

        // Prepare attestation data
        IEAS.AttestationRequestData memory requestData = IEAS
            .AttestationRequestData({
                recipient: invoice.payer,
                expirationTime: 0, // 0 means no expiration
                revocable: true,
                refUID: bytes32(0), // No referenced attestation
                data: abi.encode(invoice), // Custom attestation data
                value: 0 // No ETH sent to resolver
            });

        // Create an attestation
        IEAS.AttestationRequest memory request = IEAS.AttestationRequest({
            schema: schemaUID,
            data: requestData
        });

        bytes32 uid = eas.attest{value: 0}(request);
        invoice.easUID = uid;
    }

    /**
     * @dev Revokes an attestation on EAS.
     * @param estateId The ID of the estate associated with the invoice.
     */
    function revokeInvoice(uint256 estateId) external {
        InvoiceData storage invoice = invoices[estateId];
        require(invoice.issuer == msg.sender, "Only the issuer can revoke");
        require(invoice.easUID != bytes32(0), "Invoice is not attested");

        IEAS.RevocationRequestData memory revocationData = IEAS
            .RevocationRequestData({
                uid: invoice.easUID,
                value: 0 // No ETH sent to resolver
            });

        IEAS.RevocationRequest memory revocationRequest = IEAS
            .RevocationRequest({
                schema: bytes32(0), // Schema UID not required for revocation
                data: revocationData
            });

        eas.revoke(revocationRequest);
        invoice.easUID = bytes32(0); // Reset UID to indicate revocation
    }

    function settleInvoice() returns () {}

    /**
     * @dev Disputes an invoice.
     * @param invoiceId The ID of the invoice being disputed.
     * @param metaEvidenceURI The URI of the meta-evidence for the dispute.
     * @param arbitrationFee The fee required for arbitration in WETH.
     */
    function disputeInvoice(
        uint256 invoiceId,
        string calldata metaEvidenceURI,
        uint256 arbitrationFee
    ) external {
        InvoiceData storage invoice = invoices[invoiceId];
        require(!invoice.isPaid, "Invoice already paid");
        require(
            msg.sender == invoice.issuer || msg.sender == invoice.payer,
            "Only issuer or payer can dispute"
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
        uint256 numberOfRulingOptions = 2; // Issuer wins (1) or Payer wins (2)
        uint256 disputeId = arbitrator.createDispute(
            numberOfRulingOptions,
            arbitratorExtraData
        );
        invoice.disputeId = disputeId;
        invoice.isRuled = false;
        arbitratorDisputes[disputeId] = invoiceId;

        emit InvoiceDisputed(invoiceId, disputeId, metaEvidenceURI);
    }

    /**
     * @dev Handles the ruling from the arbitrator.
     * @param _disputeID The ID of the dispute in the arbitrator contract.
     * @param _ruling The ruling given by the arbitrator (1 for issuer, 2 for payer).
     */
    function rule(uint256 _disputeID, uint256 _ruling) external override {
        require(msg.sender == address(arbitrator), "Only arbitrator can call");

        uint256 invoiceId = arbitratorDisputes[_disputeID];
        InvoiceData storage invoice = invoices[invoiceId];
        require(!invoice.isRuled, "Ruling already executed");

        // Apply the ruling logic
        if (_ruling == 1) {
            // Issuer wins: payer is obligated to pay the invoice amount
            // Implementation for enforcing payment can be added here
        } else if (_ruling == 2) {
            // Payer wins: invoice is marked as resolved without payment
            invoice.isPaid = true;
        }

        invoice.isRuled = true;

        emit InvoiceRuling(invoiceId, _ruling);
    }

    function withdrawInvoicePayments() onlyEstateOwner returns () {}

    function getInvoice() returns () {}
}
