import { SchemaRegistry } from "@ethereum-attestation-service/eas-sdk";
import { ethers } from "ethers";

// Define the SchemaRegistry contract address and initialize the SchemaRegistry instance
const schemaRegistryContractAddress = "0xYourSchemaRegistryContractAddress";
const schemaRegistry = new SchemaRegistry(schemaRegistryContractAddress);

// Connect the schema registry to a signer
schemaRegistry.connect(signer);

// Define the schema for Invoice (excluding `penaltyApplied`)
const invoiceSchema = `
  uint256 invoiceId,
  address issuer,
  address payer,
  uint256 amountDue,
  uint256 issueDate,
  uint256 dueDate,
  string description,
  string serviceType,
  string status,
  uint256 paymentDate,
  uint256 lateFee,
  address attestor,
  uint256 timestamp
`;

// Define additional parameters for schema registration
const resolverAddress = "0xResolverAddressForInvoice"; // Replace with the appropriate address
const revocable = true;

// Register the schema
const invoiceTransaction = await schemaRegistry.register({
  schema: invoiceSchema,
  resolverAddress,
  revocable,
});

// Optional: Wait for transaction to be validated
await invoiceTransaction.wait();
console.log("Invoice schema registered:", invoiceTransaction.hash);
