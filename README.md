# RentSecure

RentSecure is a smart contract-based escrow system for rental agreements built on the Stacks blockchain. It provides secure deposit holding and facilitates monthly rental payments between landlords and tenants through automated escrow mechanisms.

## Features

- **Automated Deposit Escrow**: Securely holds rental deposits in smart contract escrow until lease termination
- **Monthly Rent Payment System**: Direct payment processing from tenant to landlord with payment tracking
- **Dual-Party Approval**: Requires both landlord and tenant approval for deposit release
- **Lease Management**: Complete lease lifecycle management from creation to termination
- **Payment History**: Comprehensive tracking of all monthly payments and deposit transactions
- **Early Termination**: Landlord-initiated lease termination with proper escrow handling
- **Transparent Operations**: All transactions and lease states are publicly verifiable on the blockchain

## Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity v2
- **Epoch**: 2.5
- **Token**: STX (Stacks native token)
- **Contract Version**: 1.0.0

## Architecture

The RentSecure contract uses three main data structures:

### Lease Data Structure
- Landlord and tenant principals
- Monthly rent amount and deposit amount
- Lease start/end dates (in block heights)
- Payment tracking and lease status
- Creation timestamp

### Monthly Payment Tracking
- Payment amount and timestamp
- Payment status verification
- Month-by-month payment history

### Deposit Escrow System
- Escrowed deposit amount
- Dual approval system (landlord + tenant)
- Release authorization tracking

## Installation

### Prerequisites

- [Node.js](https://nodejs.org/) (v16 or higher)
- [Clarinet](https://github.com/hirosystems/clarinet) CLI tool
- [Stacks CLI](https://docs.stacks.co/docs/write-smart-contracts/cli-wallet-quickstart)

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd RentSecure
```

2. Navigate to the contract directory:
```bash
cd RentSecure_contract
```

3. Install dependencies:
```bash
npm install
```

4. Check contract syntax:
```bash
clarinet check
```

## Usage Examples

### Creating a New Lease

```clarity
;; Landlord creates a lease for tenant
(contract-call? .RentSecure create-lease
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7  ;; tenant principal
  u500000000                                      ;; monthly rent (5 STX in microSTX)
  u1000000000                                     ;; deposit amount (10 STX in microSTX)
  u12)                                           ;; lease duration (12 months)
```

### Tenant Pays Deposit

```clarity
;; Tenant pays the required deposit
(contract-call? .RentSecure pay-deposit u1)  ;; lease-id: 1
```

### Monthly Rent Payment

```clarity
;; Tenant pays monthly rent for specific month
(contract-call? .RentSecure pay-monthly-rent u1 u1)  ;; lease-id: 1, month: 1
```

### Deposit Release Process

```clarity
;; 1. Landlord approves deposit release
(contract-call? .RentSecure landlord-approve-deposit-release u1)

;; 2. Tenant approves deposit release
(contract-call? .RentSecure tenant-approve-deposit-release u1)

;; 3. Anyone can execute the release (both approvals required)
(contract-call? .RentSecure release-deposit u1)
```

## Contract Functions

### Public Functions

#### `create-lease`
Creates a new rental lease agreement.
- **Parameters**: `tenant` (principal), `monthly-rent` (uint), `deposit-amount` (uint), `lease-duration-months` (uint)
- **Returns**: `(ok lease-id)` on success
- **Caller**: Landlord

#### `pay-deposit`
Allows tenant to pay the required security deposit.
- **Parameters**: `lease-id` (uint)
- **Returns**: `(ok true)` on success
- **Caller**: Tenant only

#### `pay-monthly-rent`
Processes monthly rent payment from tenant to landlord.
- **Parameters**: `lease-id` (uint), `payment-month` (uint)
- **Returns**: `(ok true)` on success
- **Caller**: Tenant only

#### `landlord-approve-deposit-release`
Landlord approves the release of escrowed deposit.
- **Parameters**: `lease-id` (uint)
- **Returns**: `(ok true)` on success
- **Caller**: Landlord only

#### `tenant-approve-deposit-release`
Tenant approves the release of escrowed deposit.
- **Parameters**: `lease-id` (uint)
- **Returns**: `(ok true)` on success
- **Caller**: Tenant only

#### `release-deposit`
Executes deposit release to tenant (requires both parties' approval).
- **Parameters**: `lease-id` (uint)
- **Returns**: `(ok true)` on success
- **Caller**: Anyone (after dual approval)

#### `terminate-lease`
Allows landlord to terminate lease early.
- **Parameters**: `lease-id` (uint)
- **Returns**: `(ok true)` on success
- **Caller**: Landlord only

### Read-Only Functions

#### `get-lease`
Retrieves complete lease information.
- **Parameters**: `lease-id` (uint)
- **Returns**: `(optional lease-data)`

#### `get-deposit-escrow`
Retrieves deposit escrow details.
- **Parameters**: `lease-id` (uint)
- **Returns**: `(optional escrow-data)`

#### `get-monthly-payment`
Retrieves specific monthly payment information.
- **Parameters**: `lease-id` (uint), `payment-month` (uint)
- **Returns**: `(optional payment-data)`

#### `is-payment-due`
Checks if monthly payment is due for specific month.
- **Parameters**: `lease-id` (uint), `payment-month` (uint)
- **Returns**: `boolean`

#### `get-next-lease-id`
Returns the next available lease ID.
- **Returns**: `uint`

## Error Codes

- `u100` - ERR_NOT_AUTHORIZED: Caller not authorized for this action
- `u101` - ERR_LEASE_NOT_FOUND: Lease ID does not exist
- `u102` - ERR_LEASE_ALREADY_EXISTS: Lease ID already in use
- `u103` - ERR_INSUFFICIENT_AMOUNT: Insufficient payment amount
- `u104` - ERR_LEASE_NOT_ACTIVE: Lease is not active
- `u105` - ERR_PAYMENT_NOT_DUE: Payment already made for this month
- `u106` - ERR_DEPOSIT_ALREADY_PAID: Deposit already paid
- `u107` - ERR_LEASE_TERMINATED: Lease has been terminated
- `u108` - ERR_UNAUTHORIZED_RELEASE: Deposit release not authorized

## Testing

Run the test suite:

```bash
npm test
```

Run tests with coverage and cost analysis:

```bash
npm run test:report
```

Watch mode for development:

```bash
npm run test:watch
```

## Deployment Guide

### Testnet Deployment

1. Configure your Stacks wallet and ensure testnet STX balance
2. Update deployment settings in `settings/Testnet.toml`
3. Deploy using Clarinet:

```bash
clarinet deployments generate --name testnet
clarinet deployments apply --name testnet
```

### Mainnet Deployment

1. Configure mainnet settings in `settings/Mainnet.toml`
2. Ensure sufficient STX for deployment fees
3. Deploy to mainnet:

```bash
clarinet deployments generate --name mainnet
clarinet deployments apply --name mainnet
```

## Security Considerations

### Audit Status
This contract has not undergone a formal security audit. Use at your own risk in production environments.

### Security Features

- **Access Control**: Function-level authorization ensures only appropriate parties can call specific functions
- **State Validation**: Comprehensive input validation and state checking prevents invalid operations
- **Dual Approval**: Deposit release requires explicit approval from both landlord and tenant
- **Atomic Operations**: All state changes occur atomically within single transactions
- **Immutable Records**: All payment and lease data is permanently recorded on-chain

### Potential Risks

- **Block Height Timing**: Lease duration calculated in blocks (~144 blocks/day) may vary with network conditions
- **No Dispute Resolution**: Contract does not include arbitration mechanisms for disputes
- **Permanent Lock Risk**: If either party becomes unavailable, deposits may remain locked indefinitely
- **No Interest Calculation**: Deposits do not accrue interest while held in escrow

### Best Practices

1. **Test Thoroughly**: Always test contract interactions on testnet before mainnet deployment
2. **Verify Addresses**: Double-check all principal addresses before lease creation
3. **Monitor Block Heights**: Be aware of block height progression for lease timing
4. **Backup Access**: Ensure both parties maintain secure access to their wallets
5. **Documentation**: Keep detailed records of all lease agreements and transactions

## License

This project is licensed under the ISC License.

## Contributing

Contributions are welcome! Please ensure all tests pass and follow the existing code style when submitting pull requests.

## Support

For questions or issues, please create an issue in the project repository.