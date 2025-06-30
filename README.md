# TokenVault 🔐

**Secure Multi-Signature Wallet for DAOs and Organizations on Stacks**

TokenVault provides comprehensive treasury management for DAOs and organizations with role-based access control, spending limits, proposal-based fund management, built-in analytics, and automated recurring payments.

## 🌟 Key Features

### For Organizations & DAOs

- **Multi-Signature Security**: Configurable signature thresholds for proposal execution
- **Role-Based Access**: Hierarchical permissions (Admin, Signer, Viewer) with granular controls
- **Proposal Governance**: Democratic fund management with voting and approval workflows
- **Spending Controls**: Individual spending limits with daily, monthly, and total caps

### For Treasury Management

- **Automated Payments**: Recurring payment schedules for salaries, subscriptions, and expenses
- **Spending Analytics**: Real-time treasury health monitoring and burn rate analysis
- **Transaction History**: Complete audit trail of all fund movements and approvals
- **Emergency Controls**: Multi-level security with emergency withdrawal procedures

### For Members & Contributors

- **Activity Tracking**: Comprehensive analytics on member participation and contributions
- **Transparent Governance**: Public voting records and proposal tracking
- **Flexible Execution**: Batch operations for efficient recurring payment management
- **Security Guarantees**: Multi-signature protection and role-based authorization

## 📊 Smart Contract Architecture

### Core Components

1. **Multi-Signature Infrastructure**

   - Configurable signature thresholds with member management
   - Role-based access control with hierarchical permission system
   - Proposal creation, voting, and execution workflow
   - Member activity tracking and last activity monitoring

2. **Spending Management**

   - Individual spending limits with automatic time-based resets
   - Spending policy framework with approval requirements
   - Real-time limit validation and usage tracking
   - Emergency withdrawal with elevated signature requirements

3. **Treasury Analytics**

   - Daily period-based analytics with inflow/outflow tracking
   - Member activity analytics including proposals and execution history
   - Treasury health scoring with runway analysis and burn rate calculation
   - Comprehensive dashboard with vault statistics and health metrics

4. **Automated Payments**
   - Recurring payment schedules with configurable frequency
   - Automated execution with batch processing capabilities
   - Payment lifecycle management with creation, execution, and cancellation
   - Integration with analytics for comprehensive financial tracking

## 🚀 Getting Started

### Prerequisites

- Stacks wallet (Hiro Wallet recommended)
- STX tokens for treasury management
- Clarinet for local development

### Deployment

```bash
# Install Clarinet
npm install -g @hirosystems/clarinet-cli

# Clone repository
git clone <repository-url>
cd tokenvault

# Deploy to testnet
clarinet deploy --testnet

# Deploy to mainnet
clarinet deploy --mainnet
```

### Usage Examples

#### Adding Organization Members

```clarity
(contract-call? .tokenvault add-member
    'SP1MEMBER123...  ;; New member address
    u2)              ;; Role: SIGNER (2)
```

#### Creating Spending Proposal

```clarity
(contract-call? .tokenvault create-proposal
    u"PAYMENT"                               ;; Proposal type
    'SP1RECIPIENT123...                      ;; Recipient address
    u10000000                                ;; 10 STX amount
    u"Monthly contractor payment for Q1"     ;; Description
    u1440)                                   ;; 10 days expiry
```

#### Voting on Proposals

```clarity
(contract-call? .tokenvault vote-on-proposal
    u1     ;; Proposal ID
    true)  ;; Approve vote
```

#### Setting Up Recurring Payments

```clarity
(contract-call? .tokenvault create-recurring-payment
    'SP1CONTRACTOR123...     ;; Recipient
    u5000000                 ;; 5 STX amount
    u4320                    ;; Monthly frequency (30 days)
    u12                      ;; 12 payments (1 year)
    u"Monthly contractor payment") ;; Description
```

#### Configuring Spending Limits

```clarity
(contract-call? .tokenvault set-spending-limit
    'SP1MEMBER123...  ;; Member address
    u1000000          ;; 1 STX daily limit
    u10000000         ;; 10 STX monthly limit
    u50000000)        ;; 50 STX total limit
```

## 📈 Contract Functions

### Member Management

- `add-member()` - Add new organization member with role assignment
- `remove-member()` - Deactivate member access and permissions
- `update-member-role()` - Change member role and permissions
- `get-member-info()` - Retrieve member details and activity

### Proposal System

- `create-proposal()` - Create new spending proposal with expiry
- `vote-on-proposal()` - Cast vote on active proposals
- `execute-proposal()` - Execute approved proposals with threshold validation
- `emergency-withdrawal()` - Create emergency proposal with elevated requirements

### Spending Controls

- `set-spending-limit()` - Configure individual member spending limits
- `set-spending-policy()` - Define global spending policies and requirements
- `validate-spending-limit()` - Check spending limit compliance
- `get-remaining-daily-limit()` - Check remaining daily spending capacity

### Treasury Management

- `deposit-funds()` - Add funds to treasury with balance tracking
- `execute-recurring-payment()` - Process scheduled recurring payments
- `create-recurring-payment()` - Set up automated payment schedules
- `cancel-recurring-payment()` - Stop active recurring payment schedules

### Analytics & Reporting

- `get-treasury-analytics()` - Retrieve period-based financial analytics
- `get-member-analytics()` - View member activity and contribution history
- `calculate-monthly-burn-rate()` - Calculate average monthly spending
- `get-treasury-health-score()` - Assess treasury financial health

## 🔒 Security Features

- **Multi-Signature Protection**: Configurable signature thresholds preventing unauthorized access
- **Role-Based Authorization**: Hierarchical permissions ensuring appropriate access levels
- **Spending Limit Enforcement**: Automatic limit validation with time-based resets
- **Proposal Expiry**: Time-limited proposals preventing stale or outdated executions
- **Emergency Procedures**: Elevated signature requirements for emergency withdrawals
- **Activity Monitoring**: Comprehensive tracking of all member actions and fund movements

## 💼 Treasury Analytics

### Health Monitoring

- **Burn Rate Analysis**: Calculate monthly spending trends and sustainability
- **Runway Calculation**: Estimate treasury lifespan at current spending rates
- **Health Scoring**: 0-100 score based on balance, burn rate, and runway
- **Inflow/Outflow Tracking**: Monitor treasury growth and spending patterns

### Member Analytics

- **Participation Metrics**: Track proposal creation, voting, and execution activity
- **Contribution Analysis**: Measure member engagement and value contribution
- **Activity Monitoring**: Monitor last activity and participation frequency
- **Performance Insights**: Analyze member effectiveness and treasury impact

## 🛠️ Development

### Contract Structure (295 lines)

- **Core Infrastructure**: Multi-signature system and member management (87 lines)
- **Spending & Execution**: Limits, policies, and proposal execution (98 lines)
- **Analytics & Automation**: Treasury analytics and recurring payments (110 lines)

### Role Hierarchy

- **Admin (Level 1)**: Full access including member management and policy configuration
- **Signer (Level 2)**: Proposal creation, voting, and execution capabilities
- **Viewer (Level 3)**: Read-only access to proposals and treasury information

### Spending Limit System

- **Daily Limits**: Reset every 144 blocks (~24 hours)
- **Monthly Limits**: Reset every 4,320 blocks (~30 days)
- **Total Limits**: Cumulative lifetime spending caps
- **Automatic Tracking**: Real-time usage monitoring and limit enforcement

## 📊 Use Cases

### DAOs & Decentralized Organizations

- **Treasury Management**: Secure multi-signature control over community funds
- **Democratic Governance**: Proposal-based spending with member voting
- **Contributor Payments**: Automated recurring payments for regular contributors
- **Financial Transparency**: Public analytics and spending tracking

### Traditional Organizations

- **Corporate Treasury**: Multi-signature security for business funds
- **Expense Management**: Role-based spending limits and approval workflows
- **Vendor Payments**: Automated recurring payments for suppliers and services
- **Financial Reporting**: Built-in analytics for accounting and compliance

### Investment Groups

- **Fund Management**: Multi-signature control over investment capital
- **Distribution Management**: Automated profit distribution to members
- **Spending Oversight**: Transparent tracking of fund usage and performance
- **Risk Management**: Spending limits and emergency withdrawal procedures

### Service Organizations

- **Operational Funding**: Secure treasury management for ongoing operations
- **Salary Automation**: Recurring payments for employees and contractors
- **Budget Management**: Spending limits and approval workflows
- **Financial Planning**: Analytics for budget forecasting and planning

## 📄 Governance & Compliance

- Multi-signature requirements ensure no single point of failure
- Transparent voting records enable accountability and audit trails
- Spending limits and policies ensure responsible fund management
- Emergency procedures provide security while maintaining accessibility

## 🏆 Competitive Advantages

- **Stacks-Native**: Built specifically for Stacks ecosystem with Bitcoin security
- **Comprehensive Analytics**: Built-in treasury health monitoring and reporting
- **Automated Payments**: Recurring payment system reducing operational overhead
- **Role-Based Security**: Granular permissions ensuring appropriate access control
- **Emergency Procedures**: Multi-level security with elevated signature requirements

## 📋 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Built on Stacks | Secured by Bitcoin | Treasury Management for the Future**
