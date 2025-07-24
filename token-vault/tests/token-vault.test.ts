import { describe, expect, it, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

const simnet = (globalThis as any).simnet;

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;
const address2 = accounts.get("wallet_2")!;
const address3 = accounts.get("wallet_3")!;
const deployer = accounts.get("deployer")!;

const contractName = "token-vault";

// Role constants
const ROLE_ADMIN = 1;
const ROLE_SIGNER = 2;
const ROLE_VIEWER = 3;

describe("TokenVault Contract Tests", () => {
  beforeEach(() => {
    simnet.mineEmptyBlocks(1);
  });

  describe("Contract Initialization and Read-Only Functions", () => {
    it("initializes with correct default values", () => {
      const { result } = simnet.callReadOnlyFn(contractName, "get-vault-stats", [], deployer);
      expect(result).toBeOk(
        Cl.tuple({
          "total-members": Cl.uint(0),
          "signature-threshold": Cl.uint(3),
          "treasury-balance": Cl.uint(0),
          "total-proposals": Cl.uint(0),
          "vault-paused": Cl.bool(false),
        })
      );
    });

    it("returns none for non-existent member", () => {
      const { result } = simnet.callReadOnlyFn(contractName, "get-member-info", [Cl.principal(address1)], deployer);
      expect(result).toBeNone();
    });

    it("returns none for non-existent proposal", () => {
      const { result } = simnet.callReadOnlyFn(contractName, "get-proposal", [Cl.uint(0)], deployer);
      expect(result).toBeNone();
    });

    it("returns none for non-existent vote", () => {
      const { result } = simnet.callReadOnlyFn(contractName, "get-vote", [
        Cl.uint(0),
        Cl.principal(address1)
      ], deployer);
      expect(result).toBeNone();
    });

    it("returns correct signature threshold", () => {
      const { result } = simnet.callReadOnlyFn(contractName, "get-signature-threshold", [], deployer);
      expect(result).toBeUint(3);
    });

    it("returns correct treasury balance", () => {
      const { result } = simnet.callReadOnlyFn(contractName, "get-treasury-balance", [], deployer);
      expect(result).toBeUint(0);
    });

    it("returns false for unauthorized member check", () => {
      const { result } = simnet.callReadOnlyFn(contractName, "is-authorized-member", [Cl.principal(address1)], deployer);
      expect(result).toBeBool(false);
    });
  });

  describe("Member Management Functions", () => {
    it("allows deployer to add first admin member", () => {
      const { result } = simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address1),
        Cl.uint(ROLE_ADMIN)
      ], deployer);
      expect(result).toBeOk(Cl.bool(true));

      // Verify member was added
      const { result: memberInfo } = simnet.callReadOnlyFn(contractName, "get-member-info", [Cl.principal(address1)], deployer);
      expect(memberInfo).toBeSome(
        Cl.tuple({
          role: Cl.uint(ROLE_ADMIN),
          "added-at": Cl.uint(expect.any(Number)),
          "last-activity": Cl.uint(expect.any(Number)),
          active: Cl.bool(true),
        })
      );
    });

    it("updates total members count after adding member", () => {
      simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address1),
        Cl.uint(ROLE_ADMIN)
      ], deployer);

      const { result } = simnet.callReadOnlyFn(contractName, "get-vault-stats", [], deployer);
      expect(result).toBeOk(
        Cl.tuple({
          "total-members": Cl.uint(1),
          "signature-threshold": Cl.uint(3),
          "treasury-balance": Cl.uint(0),
          "total-proposals": Cl.uint(0),
          "vault-paused": Cl.bool(false),
        })
      );
    });

    it("prevents duplicate member addition", () => {
      // Add member first
      simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address1),
        Cl.uint(ROLE_ADMIN)
      ], deployer);

      // Try to add same member again
      const { result } = simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address1),
        Cl.uint(ROLE_SIGNER)
      ], deployer);
      expect(result).toBeErr(Cl.uint(102)); // err-member-exists
    });

    it("validates role bounds when adding member", () => {
      // Invalid role too high
      let { result } = simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address1),
        Cl.uint(4) // Invalid role > 3
      ], deployer);
      expect(result).toBeErr(Cl.uint(101)); // err-invalid-threshold

      // Invalid role too low
      ({ result } = simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address1),
        Cl.uint(0) // Invalid role < 1
      ], deployer));
      expect(result).toBeErr(Cl.uint(101)); // err-invalid-threshold
    });

    it("allows admin to remove member", () => {
      // Add admin first
      simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address1),
        Cl.uint(ROLE_ADMIN)
      ], deployer);

      // Add another member to remove
      simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address2),
        Cl.uint(ROLE_SIGNER)
      ], address1);

      // Remove the member
      const { result } = simnet.callPublicFn(contractName, "remove-member", [
        Cl.principal(address2)
      ], address1);
      expect(result).toBeOk(Cl.bool(true));

      // Verify member was deactivated
      const { result: memberInfo } = simnet.callReadOnlyFn(contractName, "get-member-info", [Cl.principal(address2)], deployer);
      expect(memberInfo).toBeSome(
        Cl.tuple({
          role: Cl.uint(ROLE_SIGNER),
          "added-at": Cl.uint(expect.any(Number)),
          "last-activity": Cl.uint(expect.any(Number)),
          active: Cl.bool(false),
        })
      );
    });

    it("prevents non-admin from adding members", () => {
      // Add non-admin member
      simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address1),
        Cl.uint(ROLE_SIGNER)
      ], deployer);

      // Try to add member as non-admin
      const { result } = simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address2),
        Cl.uint(ROLE_VIEWER)
      ], address1);
      expect(result).toBeErr(Cl.uint(100)); // err-unauthorized
    });

    it("allows admin to update member role", () => {
      // Add admin
      simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address1),
        Cl.uint(ROLE_ADMIN)
      ], deployer);

      // Add member with signer role
      simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address2),
        Cl.uint(ROLE_SIGNER)
      ], address1);

      // Update role to viewer
      const { result } = simnet.callPublicFn(contractName, "update-member-role", [
        Cl.principal(address2),
        Cl.uint(ROLE_VIEWER)
      ], address1);
      expect(result).toBeOk(Cl.bool(true));

      // Verify role was updated
      const { result: memberInfo } = simnet.callReadOnlyFn(contractName, "get-member-info", [Cl.principal(address2)], deployer);
      expect(memberInfo).toBeSome(
        Cl.tuple({
          role: Cl.uint(ROLE_VIEWER),
          "added-at": Cl.uint(expect.any(Number)),
          "last-activity": Cl.uint(simnet.blockHeight),
          active: Cl.bool(true),
        })
      );
    });

    it("validates role bounds when updating member role", () => {
      // Add admin and member
      simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address1),
        Cl.uint(ROLE_ADMIN)
      ], deployer);
      simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address2),
        Cl.uint(ROLE_SIGNER)
      ], address1);

      // Try invalid role
      const { result } = simnet.callPublicFn(contractName, "update-member-role", [
        Cl.principal(address2),
        Cl.uint(5) // Invalid role
      ], address1);
      expect(result).toBeErr(Cl.uint(101)); // err-invalid-threshold
    });

    it("prevents updating role of non-existent member", () => {
      // Add admin
      simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address1),
        Cl.uint(ROLE_ADMIN)
      ], deployer);

      // Try to update non-existent member
      const { result } = simnet.callPublicFn(contractName, "update-member-role", [
        Cl.principal(address2),
        Cl.uint(ROLE_VIEWER)
      ], address1);
      expect(result).toBeErr(Cl.uint(103)); // err-member-not-found
    });

    it("correctly identifies authorized members", () => {
      // Add admin member
      simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address1),
        Cl.uint(ROLE_ADMIN)
      ], deployer);

      // Add signer member
      simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address2),
        Cl.uint(ROLE_SIGNER)
      ], address1);

      // Add viewer member
      simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address3),
        Cl.uint(ROLE_VIEWER)
      ], address1);

      // Check authorization
      let { result } = simnet.callReadOnlyFn(contractName, "is-authorized-member", [Cl.principal(address1)], deployer);
      expect(result).toBeBool(true); // Admin is authorized

      ({ result } = simnet.callReadOnlyFn(contractName, "is-authorized-member", [Cl.principal(address2)], deployer));
      expect(result).toBeBool(true); // Signer is authorized

      ({ result } = simnet.callReadOnlyFn(contractName, "is-authorized-member", [Cl.principal(address3)], deployer));
      expect(result).toBeBool(false); // Viewer is not authorized (< ROLE_SIGNER)
    });
  });

  describe("Proposal Creation and Management", () => {
    beforeEach(() => {
      // Setup: Add admin and signer members
      simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address1),
        Cl.uint(ROLE_ADMIN)
      ], deployer);
      simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address2),
        Cl.uint(ROLE_SIGNER)
      ], address1);
    });

    it("allows authorized member to create proposal", () => {
      const { result } = simnet.callPublicFn(contractName, "create-proposal", [
        Cl.stringUtf8("PAYMENT"),
        Cl.principal(address3),
        Cl.uint(1000),
        Cl.stringUtf8("Payment for services"),
        Cl.uint(100) // expires in 100 blocks
      ], address1);
      
      expect(result).toBeOk(Cl.uint(0)); // First proposal ID should be 0
    });

    it("stores proposal information correctly", () => {
      simnet.callPublicFn(contractName, "create-proposal", [
        Cl.stringUtf8("PAYMENT"),
        Cl.principal(address3),
        Cl.uint(1000),
        Cl.stringUtf8("Payment for services"),
        Cl.uint(100)
      ], address1);

      const { result } = simnet.callReadOnlyFn(contractName, "get-proposal", [Cl.uint(0)], deployer);
      expect(result).toBeSome(
        Cl.tuple({
          proposer: Cl.principal(address1),
          "proposal-type": Cl.stringUtf8("PAYMENT"),
          recipient: Cl.principal(address3),
          amount: Cl.uint(1000),
          description: Cl.stringUtf8("Payment for services"),
          "votes-for": Cl.uint(0),
          "votes-against": Cl.uint(0),
          executed: Cl.bool(false),
          "created-at": Cl.uint(simnet.blockHeight),
          expiry: Cl.uint(simnet.blockHeight + 100),
          "threshold-required": Cl.uint(3),
        })
      );
    });

    it("prevents unauthorized member from creating proposal", () => {
      // Add viewer member (not authorized)
      simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address3),
        Cl.uint(ROLE_VIEWER)
      ], address1);

      const { result } = simnet.callPublicFn(contractName, "create-proposal", [
        Cl.stringUtf8("PAYMENT"),
        Cl.principal(address1),
        Cl.uint(500),
        Cl.stringUtf8("Unauthorized proposal"),
        Cl.uint(50)
      ], address3);
      
      expect(result).toBeErr(Cl.uint(100)); // err-unauthorized
    });

    it("validates proposal parameters", () => {
      // Zero amount
      let { result } = simnet.callPublicFn(contractName, "create-proposal", [
        Cl.stringUtf8("PAYMENT"),
        Cl.principal(address3),
        Cl.uint(0), // Invalid zero amount
        Cl.stringUtf8("Invalid proposal"),
        Cl.uint(100)
      ], address1);
      expect(result).toBeErr(Cl.uint(108)); // err-invalid-amount

      // Zero expiry blocks
      ({ result } = simnet.callPublicFn(contractName, "create-proposal", [
        Cl.stringUtf8("PAYMENT"),
        Cl.principal(address3),
        Cl.uint(1000),
        Cl.stringUtf8("Invalid proposal"),
        Cl.uint(0) // Invalid zero expiry
      ], address1));
      expect(result).toBeErr(Cl.uint(108)); // err-invalid-amount
    });
  });

  describe("Voting System", () => {
    beforeEach(() => {
      // Setup: Add members and create proposal
      simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address1),
        Cl.uint(ROLE_ADMIN)
      ], deployer);
      simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address2),
        Cl.uint(ROLE_SIGNER)
      ], address1);
      simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address3),
        Cl.uint(ROLE_SIGNER)
      ], address1);
      
      // Create a proposal
      simnet.callPublicFn(contractName, "create-proposal", [
        Cl.stringUtf8("PAYMENT"),
        Cl.principal(deployer),
        Cl.uint(500),
        Cl.stringUtf8("Test payment"),
        Cl.uint(200)
      ], address1);
    });

    it("allows authorized member to vote on proposal", () => {
      const { result } = simnet.callPublicFn(contractName, "vote-on-proposal", [
        Cl.uint(0),
        Cl.bool(true) // approve
      ], address1);
      
      expect(result).toBeOk(Cl.bool(true));
    });

    it("records vote information correctly", () => {
      simnet.callPublicFn(contractName, "vote-on-proposal", [
        Cl.uint(0),
        Cl.bool(true)
      ], address1);

      const { result } = simnet.callReadOnlyFn(contractName, "get-vote", [
        Cl.uint(0),
        Cl.principal(address1)
      ], deployer);
      
      expect(result).toBeSome(
        Cl.tuple({
          vote: Cl.bool(true),
          "voted-at": Cl.uint(simnet.blockHeight),
        })
      );
    });

    it("updates proposal vote counts correctly", () => {
      // Vote approve
      simnet.callPublicFn(contractName, "vote-on-proposal", [
        Cl.uint(0),
        Cl.bool(true)
      ], address1);

      // Vote reject
      simnet.callPublicFn(contractName, "vote-on-proposal", [
        Cl.uint(0),
        Cl.bool(false)
      ], address2);

      const { result } = simnet.callReadOnlyFn(contractName, "get-proposal", [Cl.uint(0)], deployer);
      expect(result).toBeSome(
        Cl.tuple({
          proposer: Cl.principal(address1),
          "proposal-type": Cl.stringUtf8("PAYMENT"),
          recipient: Cl.principal(deployer),
          amount: Cl.uint(500),
          description: Cl.stringUtf8("Test payment"),
          "votes-for": Cl.uint(1),
          "votes-against": Cl.uint(1),
          executed: Cl.bool(false),
          "created-at": Cl.uint(expect.any(Number)),
          expiry: Cl.uint(expect.any(Number)),
          "threshold-required": Cl.uint(3),
        })
      );
    });

    it("prevents double voting", () => {
      // First vote
      simnet.callPublicFn(contractName, "vote-on-proposal", [
        Cl.uint(0),
        Cl.bool(true)
      ], address1);

      // Try to vote again
      const { result } = simnet.callPublicFn(contractName, "vote-on-proposal", [
        Cl.uint(0),
        Cl.bool(false)
      ], address1);
      
      expect(result).toBeErr(Cl.uint(105)); // err-already-voted
    });

    it("prevents voting on non-existent proposal", () => {
      const { result } = simnet.callPublicFn(contractName, "vote-on-proposal", [
        Cl.uint(999), // non-existent proposal
        Cl.bool(true)
      ], address1);
      
      expect(result).toBeErr(Cl.uint(104)); // err-proposal-not-found
    });

    it("updates member last activity after voting", () => {
      const initialBlockHeight = simnet.blockHeight;
      
      simnet.callPublicFn(contractName, "vote-on-proposal", [
        Cl.uint(0),
        Cl.bool(true)
      ], address1);

      const { result } = simnet.callReadOnlyFn(contractName, "get-member-info", [Cl.principal(address1)], deployer);
      expect(result).toBeSome(
        Cl.tuple({
          role: Cl.uint(ROLE_ADMIN),
          "added-at": Cl.uint(expect.any(Number)),
          "last-activity": Cl.uint(simnet.blockHeight),
          active: Cl.bool(true),
        })
      );
    });
  });

  describe("Administrative Functions", () => {
    beforeEach(() => {
      // Add admin member
      simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address1),
        Cl.uint(ROLE_ADMIN)
      ], deployer);
    });

    it("allows admin to update signature threshold", () => {
      const { result } = simnet.callPublicFn(contractName, "update-signature-threshold", [
        Cl.uint(2)
      ], address1);
      
      expect(result).toBeOk(Cl.bool(true));

      // Verify threshold was updated
      const { result: threshold } = simnet.callReadOnlyFn(contractName, "get-signature-threshold", [], deployer);
      expect(threshold).toBeUint(2);
    });

    it("validates signature threshold bounds", () => {
      // Zero threshold
      let { result } = simnet.callPublicFn(contractName, "update-signature-threshold", [
        Cl.uint(0)
      ], address1);
      expect(result).toBeErr(Cl.uint(101)); // err-invalid-threshold

      // Add more members first
      simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address2),
        Cl.uint(ROLE_SIGNER)
      ], address1);

      // Threshold higher than total members
      ({ result } = simnet.callPublicFn(contractName, "update-signature-threshold", [
        Cl.uint(5) // Only 2 members exist
      ], address1));
      expect(result).toBeErr(Cl.uint(101)); // err-invalid-threshold
    });

    it("allows admin to toggle vault pause", () => {
      const { result } = simnet.callPublicFn(contractName, "toggle-vault-pause", [], address1);
      expect(result).toBeOk(Cl.bool(true));

      // Verify vault is paused
      const { result: stats } = simnet.callReadOnlyFn(contractName, "get-vault-stats", [], deployer);
      expect(stats).toBeOk(
        Cl.tuple({
          "total-members": Cl.uint(1),
          "signature-threshold": Cl.uint(3),
          "treasury-balance": Cl.uint(0),
          "total-proposals": Cl.uint(0),
          "vault-paused": Cl.bool(true),
        })
      );
    });

    it("prevents non-admin from updating threshold", () => {
      // Add non-admin member
      simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address2),
        Cl.uint(ROLE_SIGNER)
      ], address1);

      const { result } = simnet.callPublicFn(contractName, "update-signature-threshold", [
        Cl.uint(2)
      ], address2);
      
      expect(result).toBeErr(Cl.uint(100)); // err-unauthorized
    });

    it("prevents operations when vault is paused", () => {
      // Pause vault
      simnet.callPublicFn(contractName, "toggle-vault-pause", [], address1);

      // Try to add member when paused
      const { result } = simnet.callPublicFn(contractName, "add-member", [
        Cl.principal(address2),
        Cl.uint(ROLE_SIGNER)
      ], address1);
      
      expect(result).toBeErr(Cl.uint(100)); // err-unauthorized
    });
  });
});