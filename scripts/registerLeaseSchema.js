import { SchemaRegistry } from "@ethereum-attestation-service/eas-sdk";
import { ethers } from "ethers";

// Define the SchemaRegistry contract address and initialize the SchemaRegistry instance
const schemaRegistryContractAddress =
  "0x0a7E2Ff54e76B8E6659aedc9103FB21c038050D0";
const schemaRegistry = new SchemaRegistry(schemaRegistryContractAddress);

// Connect the schema registry to a signer
schemaRegistry.connect(signer);

// Define the schema for Lease (excluding `disputeResolutionProtocol`, `paymentFrequency`, `escrowEnabled`)
const leaseSchema = `
  address tenant,
  address landlord,
  uint256 rentAmount,
  uint256 securityDeposit,
  uint256 leaseStartDate,
  uint256 leaseEndDate,
  string propertyAddress,
  uint256 propertyId,
  string status,
  string terminationConditions,
  address attestor,
  uint256 timestamp
`;

// Define additional parameters for schema registration
const resolverAddress = "0xResolverAddressForLease"; // Replace with the appropriate address
const revocable = true;

// Register the schema
const leaseTransaction = await schemaRegistry.register({
  schema: leaseSchema,
  resolverAddress,
  revocable,
});

// Optional: Wait for transaction to be validated
await leaseTransaction.wait();
console.log("Lease schema registered:", leaseTransaction.hash);
