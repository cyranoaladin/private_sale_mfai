# PrivateSaleMFAI Smart Contract

## Description

`PrivateSaleMFAI` is a smart contract deployed on the Binance Smart Chain (BSC) that implements a private token sale with a tiered system. This contract allows for the collection of funds in BNB according to a three-tier structure with cumulative contribution limits.

## Key Features

- **Three-tier system**:
  - **Tier 1**: Cumulative limit of 30 BNB
  - **Tier 2**: Additional contribution of 60 BNB (cumulative 90 BNB)
  - **Tier 3**: Additional contribution of 60 BNB (cumulative 150 BNB)

- **Automatic tier management**: The contract automatically advances to the next tier when the current tier limit is reached.

- **Flexible contribution**: If a contribution exceeds the current tier limit, the excess is applied to the next tier.

- **Individual contribution limits**: For tiers 1 and 2, a maximum contribution limit per participant is applied (default 10 BNB).

- **Contribution increments**: Contributions must be multiples of a specified increment (default 1 BNB).

- **Timelock mechanism**: Changes to the contribution increment are subject to a security delay (2 hours by default).

- **Data export**: Pagination functionality for exporting participant data.

- **Reentrancy protection**: Use of the `nonReentrant` modifier to prevent reentrancy attacks.

- **Pause control**: Ability to pause and resume the sale.

## Technical Architecture

The contract is developed in Solidity 0.8.28 and inherits from three OpenZeppelin contracts:
- `Ownable`: Management of administrative permissions
- `ReentrancyGuard`: Protection against reentrancy attacks
- `Pausable`: Pause/resume functionality

### Data Structure

```solidity
struct Contribution {
    uint256 total;
    uint256 tier1;
    uint256 tier2;
    uint256 tier3;
}
```

This structure stores the total and per-tier contributions for each participant.

### Main State Variables

- `wallet`: Address of the wallet receiving all funds
- `tierXLimit`: Cumulative limits for each tier (X = 1, 2, 3)
- `totalFunds`: Total amount collected
- `currentTier`: Current tier (1, 2, 3, or 0 if the sale is finished)
- `maxContribution`: Maximum contribution per participant
- `contributionIncrement`: Minimum contribution increment
- `participants`: List of participating addresses
- `contributions`: Mapping of contributions by address

## Administrative Functions

The contract offers several administrative functions reserved for the owner:

- `resetPrivateSale()`: Completely resets the private sale
- `updateTierLimit()`: Modifies a tier limit
- `updateMaxContribution()`: Modifies the maximum contribution per participant
- `updateContributionIncrement()`: Schedules an update to the contribution increment
- `applyContributionIncrement()`: Applies the increment update after the delay
- `pause()` and `unpause()`: Pauses or resumes the sale
- `exportParticipants()`: Exports participant data with pagination

## Contribution Flow

1. A participant sends BNB via the `contribute()` function
2. The contract verifies that:
   - The amount is positive
   - The amount is a multiple of the contribution increment
   - For tiers 1 and 2, the participant's total contribution does not exceed the individual limit
3. The contract processes the contribution:
   - If the amount can be fully accepted in the current tier, it records it
   - If the amount exceeds the current tier limit, it distributes the contribution across tiers
   - If tier 3 is reached and exceeded, the sale ends
4. The funds are transferred to the specified wallet

## Events

The contract emits several events to track its activity:
- `ContributionEvent`: Emitted during a contribution
- `TierAdvanced`: Emitted when advancing to a new tier
- `TierLimitUpdated`: Emitted when modifying a tier limit
- `ContributionIncrementUpdated`: Emitted when scheduling an increment update

## Security Measures

- **Reentrancy protection**: Use of the `nonReentrant` modifier for the `contribute()` function
- **Access control**: Use of the `onlyOwner` modifier for administrative functions
- **Timelock**: Security delay for contribution increment modifications
- **Rejection of direct transfers**: The `receive()` and `fallback()` functions reject direct ETH transfers
- **Input validation**: Strict validation of input parameters for all functions

## Deployment

The contract is configured to be deployed on:
- BSC Mainnet (chainId: 56)
- BSC Testnet (chainId: 97)

### Prerequisites

- Node.js and npm installed
- A BSC account with BNB for deployment

### Configuration

1. Clone the repository
2. Install dependencies:
   ```
   npm install
   ```
3. Configure the `.env` file with:
   ```
   PRIVATE_KEY=your_private_key
   BSC_MAINNET_RPC_URL=https://bsc-dataseed.binance.org/
   BSC_TESTNET_RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545/
   BSCSCAN_API_KEY=your_bscscan_api_key
   WALLET_ADDRESS=address_of_the_wallet_receiving_funds
   ```

### Deployment on BSC Testnet

```bash
npx hardhat run scripts/deploy.js --network bscTestnet
```

### Deployment on BSC Mainnet

```bash
npx hardhat run scripts/deploy.js --network bsc
```

#### Mainnet Deployment Considerations

When deploying to BSC Mainnet, consider the following:

1. **Gas Optimization**: BSC Mainnet has different gas prices than Testnet. Set an appropriate gas price in the Hardhat config (currently set to 5 gwei).

2. **Security Verification**: Before deploying to Mainnet, ensure all security audits are complete and all vulnerabilities are addressed.

3. **Wallet Address**: Double-check the wallet address that will receive the funds. This address should be secure and under your control.

4. **Initial Parameters**: Carefully set the initial parameters (tier limits, max contribution, etc.) as these will be public once deployed.

5. **Contract Verification**: After deployment, verify your contract on BscScan for transparency:

```bash
npx hardhat verify --network bsc CONTRACT_ADDRESS WALLET_ADDRESS
```

6. **Monitoring**: Set up monitoring for your contract to track contributions and tier progression.

7. **Backup**: Keep a secure backup of your deployment information, including the contract address and ABI.

### Contract Verification on BscScan

```bash
npx hardhat verify --network bsc CONTRACT_ADDRESS WALLET_ADDRESS
```

## Tests

The project includes unit tests to verify the proper functioning of the contract.

To run the tests:

```bash
npm test
```

The tests verify:
- Correct initialization of tier limits
- Correct progression through tiers
- Compliance with individual contribution limits
- Rejection of contributions that do not respect the increment

## Security Audit

### Strengths

1. **Reentrancy protection**: Appropriate use of the `nonReentrant` modifier
2. **Access control**: Administrative functions properly protected by `onlyOwner`
3. **Input validation**: Rigorous verification of input parameters
4. **Timelock mechanism**: Security delay for sensitive modifications
5. **Rejection of direct transfers**: Protection against unintentional ETH transfers

### Recommendations

1. **Error handling**: Use more descriptive error messages to facilitate debugging
2. **Additional events**: Add events for all administrative actions
3. **Stress testing**: Perform tests with a large number of participants
4. **Gas optimization**: Further optimize loops and gas-expensive operations

## License

This project is under the MIT License.

## Author

Alaeddine BEN RHOUMA
