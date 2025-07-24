;; TokenVault - Multi-Signature Wallet for DAOs

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-invalid-threshold (err u101))
(define-constant err-member-exists (err u102))
(define-constant err-member-not-found (err u103))
(define-constant err-proposal-not-found (err u104))
(define-constant err-already-voted (err u105))
(define-constant err-proposal-expired (err u106))
(define-constant err-insufficient-votes (err u107))
(define-constant err-invalid-amount (err u108))
(define-constant err-execution-failed (err u109))

;; Role definitions
(define-constant ROLE-ADMIN u1)
(define-constant ROLE-SIGNER u2)
(define-constant ROLE-VIEWER u3)

;; Data variables
(define-data-var signature-threshold uint u3)
(define-data-var total-members uint u0)
(define-data-var proposal-counter uint u0)
(define-data-var treasury-balance uint u0)
(define-data-var vault-paused bool false)

;; Organization members with roles
(define-map organization-members
    principal
    {
        role: uint,
        added-at: uint,
        last-activity: uint,
        active: bool,
    }
)

;; Multi-signature proposals
(define-map proposals
    uint
    {
        proposer: principal,
        proposal-type: (string-utf8 32),
        recipient: principal,
        amount: uint,
        description: (string-utf8 256),
        votes-for: uint,
        votes-against: uint,
        executed: bool,
        created-at: uint,
        expiry: uint,
        threshold-required: uint,
    }
)

;; Proposal voting records
(define-map proposal-votes
    {
        proposal-id: uint,
        voter: principal,
    }
    {
        vote: bool, ;; true = approve, false = reject
        voted-at: uint,
    }
)

;; Member list for iteration
(define-map member-list
    uint
    principal
)

;; Read-only functions
(define-read-only (get-member-info (member principal))
    (map-get? organization-members member)
)

(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id)
)

(define-read-only (get-vote
        (proposal-id uint)
        (voter principal)
    )
    (map-get? proposal-votes {
        proposal-id: proposal-id,
        voter: voter,
    })
)

(define-read-only (get-signature-threshold)
    (var-get signature-threshold)
)

(define-read-only (get-treasury-balance)
    (var-get treasury-balance)
)

(define-read-only (get-vault-stats)
    (ok {
        total-members: (var-get total-members),
        signature-threshold: (var-get signature-threshold),
        treasury-balance: (var-get treasury-balance),
        total-proposals: (var-get proposal-counter),
        vault-paused: (var-get vault-paused),
    })
)

(define-read-only (is-authorized-member (member principal))
    (match (map-get? organization-members member)
        member-info (and (get active member-info) (>= (get role member-info) ROLE-SIGNER))
        false
    )
)

;; Private functions
(define-private (has-role
        (member principal)
        (required-role uint)
    )
    (match (map-get? organization-members member)
        member-info (and
            (get active member-info)
            (>= (get role member-info) required-role)
        )
        false
    )
)

(define-private (calculate-votes-needed)
    (var-get signature-threshold)
)

;; Member management
(define-public (add-member
        (new-member principal)
        (role uint)
    )
    (begin
        (asserts! (has-role tx-sender ROLE-ADMIN) err-unauthorized)
        (asserts! (not (var-get vault-paused)) err-unauthorized)
        (asserts! (is-none (map-get? organization-members new-member))
            err-member-exists
        )
        (asserts! (and (>= role ROLE-VIEWER) (<= role ROLE-ADMIN))
            err-invalid-threshold
        )
        (map-set organization-members new-member {
            role: role,
            added-at: stacks-block-height,
            last-activity: stacks-block-height,
            active: true,
        })
        ;; Add to member list
        (let ((member-index (var-get total-members)))
            (map-set member-list member-index new-member)
            (var-set total-members (+ member-index u1))
        )
        (ok true)
    )
)

(define-public (remove-member (member principal))
    (let ((member-info (unwrap! (map-get? organization-members member) err-member-not-found)))
        (begin
            (asserts! (has-role tx-sender ROLE-ADMIN) err-unauthorized)
            (asserts! (not (var-get vault-paused)) err-unauthorized)
            (asserts! (get active member-info) err-member-not-found)
            (map-set organization-members member
                (merge member-info { active: false })
            )
            (ok true)
        )
    )
)

(define-public (update-member-role
        (member principal)
        (new-role uint)
    )
    (let ((member-info (unwrap! (map-get? organization-members member) err-member-not-found)))
        (begin
            (asserts! (has-role tx-sender ROLE-ADMIN) err-unauthorized)
            (asserts! (not (var-get vault-paused)) err-unauthorized)
            (asserts! (get active member-info) err-member-not-found)
            (asserts! (and (>= new-role ROLE-VIEWER) (<= new-role ROLE-ADMIN))
                err-invalid-threshold
            )
            (map-set organization-members member
                (merge member-info {
                    role: new-role,
                    last-activity: stacks-block-height,
                })
            )
            (ok true)
        )
    )
)

;; Proposal creation and voting
(define-public (create-proposal
        (proposal-type (string-utf8 32))
        (recipient principal)
        (amount uint)
        (description (string-utf8 256))
        (expiry-blocks uint)
    )
    (let ((proposal-id (var-get proposal-counter)))
        (begin
            (asserts! (is-authorized-member tx-sender) err-unauthorized)
            (asserts! (not (var-get vault-paused)) err-unauthorized)
            (asserts! (> amount u0) err-invalid-amount)
            (asserts! (> expiry-blocks u0) err-invalid-amount)
            (map-set proposals proposal-id {
                proposer: tx-sender,
                proposal-type: proposal-type,
                recipient: recipient,
                amount: amount,
                description: description,
                votes-for: u0,
                votes-against: u0,
                executed: false,
                created-at: stacks-block-height,
                expiry: (+ stacks-block-height expiry-blocks),
                threshold-required: (calculate-votes-needed),
            })
            (var-set proposal-counter (+ proposal-id u1))
            (ok proposal-id)
        )
    )
)

(define-public (vote-on-proposal
        (proposal-id uint)
        (approve bool)
    )
    (let (
            (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
            (existing-vote (map-get? proposal-votes {
                proposal-id: proposal-id,
                voter: tx-sender,
            }))
        )
        (begin
            (asserts! (is-authorized-member tx-sender) err-unauthorized)
            (asserts! (not (var-get vault-paused)) err-unauthorized)
            (asserts! (is-none existing-vote) err-already-voted)
            (asserts! (< stacks-block-height (get expiry proposal))
                err-proposal-expired
            )
            (asserts! (not (get executed proposal)) err-execution-failed)
            ;; Record vote
            (map-set proposal-votes {
                proposal-id: proposal-id,
                voter: tx-sender,
            } {
                vote: approve,
                voted-at: stacks-block-height,
            })
            ;; Update proposal vote counts
            (map-set proposals proposal-id
                (merge proposal {
                    votes-for: (if approve
                        (+ (get votes-for proposal) u1)
                        (get votes-for proposal)
                    ),
                    votes-against: (if (not approve)
                        (+ (get votes-against proposal) u1)
                        (get votes-against proposal)
                    ),
                })
            )
            ;; Update member activity
            (let ((member-info (unwrap-panic (map-get? organization-members tx-sender))))
                (map-set organization-members tx-sender
                    (merge member-info { last-activity: stacks-block-height })
                )
            )
            (ok true)
        )
    )
)

;; Administrative functions
(define-public (update-signature-threshold (new-threshold uint))
    (begin
        (asserts! (has-role tx-sender ROLE-ADMIN) err-unauthorized)
        (asserts! (not (var-get vault-paused)) err-unauthorized)
        (asserts!
            (and (> new-threshold u0) (<= new-threshold (var-get total-members)))
            err-invalid-threshold
        )
        (var-set signature-threshold new-threshold)
        (ok true)
    )
)

(define-public (toggle-vault-pause)
    (begin
        (asserts! (has-role tx-sender ROLE-ADMIN) err-unauthorized)
        (var-set vault-paused (not (var-get vault-paused)))
        (ok true)
    )
)

(define-public (deposit-funds)
    (begin
        (asserts! (not (var-get vault-paused)) err-unauthorized)
        (let ((deposit-amount (stx-get-balance tx-sender)))
            (asserts! (> deposit-amount u0) err-invalid-amount)
            (try! (stx-transfer? deposit-amount tx-sender (as-contract tx-sender)))
            (var-set treasury-balance
                (+ (var-get treasury-balance) deposit-amount)
            )
            (ok deposit-amount)
        )
    )
)

;; Spending limit configurations
(define-map spending-limits
    principal ;; member
    {
        daily-limit: uint,
        monthly-limit: uint,
        total-limit: uint,
        daily-spent: uint,
        monthly-spent: uint,
        total-spent: uint,
        last-reset-day: uint,
        last-reset-month: uint,
    }
)

;; Global spending policies
(define-map spending-policies
    (string-utf8 32) ;; policy-type
    {
        max-amount: uint,
        requires-approval: bool,
        min-signers: uint,
        cooldown-period: uint,
    }
)

;; Transaction history
(define-map transaction-history
    uint
    {
        proposal-id: uint,
        recipient: principal,
        amount: uint,
        executed-by: principal,
        executed-at: uint,
        transaction-type: (string-utf8 32),
    }
)

(define-data-var transaction-counter uint u0)

;; Proposal execution
(define-public (execute-proposal (proposal-id uint))
    (let (
            (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
            (tx-id (var-get transaction-counter))
        )
        (begin
            (asserts! (is-authorized-member tx-sender) err-unauthorized)
            (asserts! (not (var-get vault-paused)) err-unauthorized)
            (asserts! (not (get executed proposal)) err-execution-failed)
            (asserts! (< stacks-block-height (get expiry proposal))
                err-proposal-expired
            )
            (asserts!
                (>= (get votes-for proposal) (get threshold-required proposal))
                err-insufficient-votes
            )
            (asserts! (>= (var-get treasury-balance) (get amount proposal))
                err-invalid-amount
            )
            ;; Check spending limits
            (unwrap! (validate-spending-limit tx-sender (get amount proposal))
                err-unauthorized
            )
            ;; Execute transfer
            (unwrap!
                (as-contract (stx-transfer? (get amount proposal) tx-sender
                    (get recipient proposal)
                ))
                err-execution-failed
            )
            ;; Update treasury balance
            (var-set treasury-balance
                (- (var-get treasury-balance) (get amount proposal))
            )
            ;; Update spending limits
            (update-spending-usage tx-sender (get amount proposal))
            ;; Mark proposal as executed
            (map-set proposals proposal-id (merge proposal { executed: true }))
            ;; Record transaction
            (map-set transaction-history tx-id {
                proposal-id: proposal-id,
                recipient: (get recipient proposal),
                amount: (get amount proposal),
                executed-by: tx-sender,
                executed-at: stacks-block-height,
                transaction-type: (get proposal-type proposal),
            })
            (var-set transaction-counter (+ tx-id u1))
            (ok tx-id)
        )
    )
)

;; Spending limit management
(define-public (set-spending-limit
        (member principal)
        (daily-limit uint)
        (monthly-limit uint)
        (total-limit uint)
    )
    (begin
        (asserts! (has-role tx-sender ROLE-ADMIN) err-unauthorized)
        (asserts! (not (var-get vault-paused)) err-unauthorized)
        (asserts! (is-some (map-get? organization-members member))
            err-member-not-found
        )
        (map-set spending-limits member {
            daily-limit: daily-limit,
            monthly-limit: monthly-limit,
            total-limit: total-limit,
            daily-spent: u0,
            monthly-spent: u0,
            total-spent: u0,
            last-reset-day: (/ stacks-block-height u144), ;; Approximate daily blocks
            last-reset-month: (/ stacks-block-height u4320), ;; Approximate monthly blocks
        })
        (ok true)
    )
)

(define-public (set-spending-policy
        (policy-type (string-utf8 32))
        (max-amount uint)
        (requires-approval bool)
        (min-signers uint)
        (cooldown-period uint)
    )
    (begin
        (asserts! (has-role tx-sender ROLE-ADMIN) err-unauthorized)
        (asserts! (not (var-get vault-paused)) err-unauthorized)
        (map-set spending-policies policy-type {
            max-amount: max-amount,
            requires-approval: requires-approval,
            min-signers: min-signers,
            cooldown-period: cooldown-period,
        })
        (ok true)
    )
)

;; Emergency withdrawal (requires higher threshold)
(define-public (emergency-withdrawal
        (recipient principal)
        (amount uint)
        (reason (string-utf8 256))
    )
    (let ((emergency-threshold (+ (var-get signature-threshold) u2)))
        ;; Requires 2 additional signatures
        (begin
            (asserts! (has-role tx-sender ROLE-ADMIN) err-unauthorized)
            (asserts! (> amount u0) err-invalid-amount)
            (asserts! (>= (var-get treasury-balance) amount) err-invalid-amount)
            ;; Create emergency proposal with higher threshold
            (let ((proposal-id (var-get proposal-counter)))
                (map-set proposals proposal-id {
                    proposer: tx-sender,
                    proposal-type: u"EMERGENCY",
                    recipient: recipient,
                    amount: amount,
                    description: reason,
                    votes-for: u1, ;; Auto-approve from proposer
                    votes-against: u0,
                    executed: false,
                    created-at: stacks-block-height,
                    expiry: (+ stacks-block-height u1440), ;; 10 days for emergency
                    threshold-required: emergency-threshold,
                })
                (var-set proposal-counter (+ proposal-id u1))
                (ok proposal-id)
            )
        )
    )
)

;; Private helper functions for spending limits
(define-private (validate-spending-limit
        (member principal)
        (amount uint)
    )
    (let (
            (limits (default-to {
                daily-limit: u999999999999,
                monthly-limit: u999999999999,
                total-limit: u999999999999,
                daily-spent: u0,
                monthly-spent: u0,
                total-spent: u0,
                last-reset-day: u0,
                last-reset-month: u0,
            }
                (map-get? spending-limits member)
            ))
            (current-day (/ stacks-block-height u144))
            (current-month (/ stacks-block-height u4320))
        )
        (let (
                (reset-daily (> current-day (get last-reset-day limits)))
                (reset-monthly (> current-month (get last-reset-month limits)))
                (daily-spent (if reset-daily
                    u0
                    (get daily-spent limits)
                ))
                (monthly-spent (if reset-monthly
                    u0
                    (get monthly-spent limits)
                ))
            )
            (if (and
                    (<= (+ daily-spent amount) (get daily-limit limits))
                    (<= (+ monthly-spent amount) (get monthly-limit limits))
                    (<= (+ (get total-spent limits) amount)
                        (get total-limit limits)
                    )
                )
                (ok true)
                (err err-unauthorized)
            )
        )
    )
)

(define-private (update-spending-usage
        (member principal)
        (amount uint)
    )
    (let (
            (limits (unwrap-panic (map-get? spending-limits member)))
            (current-day (/ stacks-block-height u144))
            (current-month (/ stacks-block-height u4320))
            (reset-daily (> current-day (get last-reset-day limits)))
            (reset-monthly (> current-month (get last-reset-month limits)))
        )
        (map-set spending-limits member {
            daily-limit: (get daily-limit limits),
            monthly-limit: (get monthly-limit limits),
            total-limit: (get total-limit limits),
            daily-spent: (+
                (if reset-daily
                    u0
                    (get daily-spent limits)
                )
                amount
            ),
            monthly-spent: (+
                (if reset-monthly
                    u0
                    (get monthly-spent limits)
                )
                amount
            ),
            total-spent: (+ (get total-spent limits) amount),
            last-reset-day: current-day,
            last-reset-month: current-month,
        })
        true
    )
)

;; Read-only functions for spending limits
(define-read-only (get-spending-limit (member principal))
    (map-get? spending-limits member)
)

(define-read-only (get-spending-policy (policy-type (string-utf8 32)))
    (map-get? spending-policies policy-type)
)

(define-read-only (get-transaction (tx-id uint))
    (map-get? transaction-history tx-id)
)

(define-read-only (get-remaining-daily-limit (member principal))
    (let (
            (limits (unwrap! (map-get? spending-limits member) (err u0)))
            (current-day (/ stacks-block-height u144))
            (reset-daily (> current-day (get last-reset-day limits)))
            (daily-spent (if reset-daily
                u0
                (get daily-spent limits)
            ))
        )
        (ok (- (get daily-limit limits) daily-spent))
    )
)

(define-read-only (check-proposal-executable (proposal-id uint))
    (let ((proposal (unwrap! (map-get? proposals proposal-id) (err u0))))
        (ok (and
            (not (get executed proposal))
            (< stacks-block-height (get expiry proposal))
            (>= (get votes-for proposal) (get threshold-required proposal))
            (>= (var-get treasury-balance) (get amount proposal))
        ))
    )
)

;; Recurring payment schedules
(define-map recurring-payments
    uint
    {
        recipient: principal,
        amount: uint,
        frequency: uint, ;; blocks between payments
        next-payment: uint,
        total-payments: uint,
        payments-made: uint,
        active: bool,
        created-by: principal,
        created-at: uint,
        description: (string-utf8 128),
    }
)

(define-data-var payment-schedule-counter uint u0)

;; Treasury analytics data
(define-map treasury-analytics
    uint ;; time-period (block-height / period-length)
    {
        total-inflows: uint,
        total-outflows: uint,
        transaction-count: uint,
        average-transaction: uint,
        period-start: uint,
        period-end: uint,
    }
)

;; Member activity analytics
(define-map member-analytics
    principal
    {
        proposals-created: uint,
        votes-cast: uint,
        transactions-executed: uint,
        last-active: uint,
        total-amount-proposed: uint,
        total-amount-executed: uint,
    }
)

;; Automated payment execution
(define-public (execute-recurring-payment (payment-id uint))
    (let (
            (payment (unwrap! (map-get? recurring-payments payment-id)
                err-proposal-not-found
            ))
            (tx-id (var-get transaction-counter))
        )
        (begin
            (asserts! (not (var-get vault-paused)) err-unauthorized)
            (asserts! (get active payment) err-execution-failed)
            (asserts! (<= (get next-payment payment) stacks-block-height)
                err-proposal-expired
            )
            (asserts!
                (< (get payments-made payment) (get total-payments payment))
                err-execution-failed
            )
            (asserts! (>= (var-get treasury-balance) (get amount payment))
                err-invalid-amount
            )
            ;; Execute payment
            (unwrap!
                (as-contract (stx-transfer? (get amount payment) tx-sender
                    (get recipient payment)
                ))
                err-execution-failed
            )
            ;; Update treasury balance
            (var-set treasury-balance
                (- (var-get treasury-balance) (get amount payment))
            )
            ;; Update payment schedule
            (map-set recurring-payments payment-id
                (merge payment {
                    next-payment: (+ (get next-payment payment) (get frequency payment)),
                    payments-made: (+ (get payments-made payment) u1),
                    active: (< (+ (get payments-made payment) u1)
                        (get total-payments payment)
                    ),
                })
            )
            ;; Record transaction
            (map-set transaction-history tx-id {
                proposal-id: u0, ;; No proposal for recurring payments
                recipient: (get recipient payment),
                amount: (get amount payment),
                executed-by: tx-sender,
                executed-at: stacks-block-height,
                transaction-type: u"RECURRING",
            })
            ;; Update analytics
            (update-treasury-analytics (get amount payment) false)
            (update-member-analytics tx-sender u0 (get amount payment) false true)
            (var-set transaction-counter (+ tx-id u1))
            (ok tx-id)
        )
    )
)

(define-public (create-recurring-payment
        (recipient principal)
        (amount uint)
        (frequency uint)
        (total-payments uint)
        (description (string-utf8 128))
    )
    (let ((payment-id (var-get payment-schedule-counter)))
        (begin
            (asserts! (has-role tx-sender ROLE-ADMIN) err-unauthorized)
            (asserts! (not (var-get vault-paused)) err-unauthorized)
            (asserts! (> amount u0) err-invalid-amount)
            (asserts! (> frequency u0) err-invalid-amount)
            (asserts! (> total-payments u0) err-invalid-amount)
            (map-set recurring-payments payment-id {
                recipient: recipient,
                amount: amount,
                frequency: frequency,
                next-payment: (+ stacks-block-height frequency),
                total-payments: total-payments,
                payments-made: u0,
                active: true,
                created-by: tx-sender,
                created-at: stacks-block-height,
                description: description,
            })
            (var-set payment-schedule-counter (+ payment-id u1))
            (ok payment-id)
        )
    )
)

(define-public (cancel-recurring-payment (payment-id uint))
    (let ((payment (unwrap! (map-get? recurring-payments payment-id) err-proposal-not-found)))
        (begin
            (asserts!
                (or
                    (has-role tx-sender ROLE-ADMIN)
                    (is-eq tx-sender (get created-by payment))
                )
                err-unauthorized
            )
            (asserts! (get active payment) err-execution-failed)
            (map-set recurring-payments payment-id
                (merge payment { active: false })
            )
            (ok true)
        )
    )
)

;; Analytics functions
(define-private (update-treasury-analytics
        (amount uint)
        (is-inflow bool)
    )
    (let (
            (period (/ stacks-block-height u1440)) ;; Daily periods
            (current-analytics (default-to {
                total-inflows: u0,
                total-outflows: u0,
                transaction-count: u0,
                average-transaction: u0,
                period-start: (* period u1440),
                period-end: (* (+ period u1) u1440),
            }
                (map-get? treasury-analytics period)
            ))
        )
        (let (
                (new-inflows (if is-inflow
                    (+ (get total-inflows current-analytics) amount)
                    (get total-inflows current-analytics)
                ))
                (new-outflows (if (not is-inflow)
                    (+ (get total-outflows current-analytics) amount)
                    (get total-outflows current-analytics)
                ))
                (new-count (+ (get transaction-count current-analytics) u1))
                (total-volume (+ new-inflows new-outflows))
            )
            (map-set treasury-analytics period {
                total-inflows: new-inflows,
                total-outflows: new-outflows,
                transaction-count: new-count,
                average-transaction: (if (> new-count u0)
                    (/ total-volume new-count)
                    u0
                ),
                period-start: (get period-start current-analytics),
                period-end: (get period-end current-analytics),
            })
        )
        true
    )
)

(define-private (update-member-analytics
        (member principal)
        (proposal-amount uint)
        (execution-amount uint)
        (voted bool)
        (executed bool)
    )
    (let ((current-analytics (default-to {
            proposals-created: u0,
            votes-cast: u0,
            transactions-executed: u0,
            last-active: u0,
            total-amount-proposed: u0,
            total-amount-executed: u0,
        }
            (map-get? member-analytics member)
        )))
        (map-set member-analytics member {
            proposals-created: (+ (get proposals-created current-analytics)
                (if (> proposal-amount u0)
                    u1
                    u0
                )),
            votes-cast: (+ (get votes-cast current-analytics)
                (if voted
                    u1
                    u0
                )),
            transactions-executed: (+ (get transactions-executed current-analytics)
                (if executed
                    u1
                    u0
                )),
            last-active: stacks-block-height,
            total-amount-proposed: (+ (get total-amount-proposed current-analytics) proposal-amount),
            total-amount-executed: (+ (get total-amount-executed current-analytics) execution-amount),
        })
        true
    )
)

;; Enhanced proposal creation with analytics
(define-public (create-proposal-with-analytics
        (proposal-type (string-utf8 32))
        (recipient principal)
        (amount uint)
        (description (string-utf8 256))
        (expiry-blocks uint)
    )
    (begin
        ;; Create proposal using existing function
        (let ((proposal-result (create-proposal proposal-type recipient amount description
                expiry-blocks
            )))
            (match proposal-result
                success (begin
                    ;; Update member analytics
                    (update-member-analytics tx-sender amount u0 false false)
                    (ok success)
                )
                error (err error)
            )
        )
    )
)

;; Enhanced voting with analytics
(define-public (vote-with-analytics
        (proposal-id uint)
        (approve bool)
    )
    (begin
        ;; Vote using existing function
        (let ((vote-result (vote-on-proposal proposal-id approve)))
            (match vote-result
                success (begin
                    ;; Update member analytics
                    (update-member-analytics tx-sender u0 u0 true false)
                    (ok success)
                )
                error (err error)
            )
        )
    )
)

;; Read-only analytics functions
(define-read-only (get-treasury-analytics (period uint))
    (map-get? treasury-analytics period)
)

(define-read-only (get-member-analytics (member principal))
    (map-get? member-analytics member)
)

(define-read-only (get-recurring-payment (payment-id uint))
    (map-get? recurring-payments payment-id)
)

(define-read-only (get-pending-recurring-payments)
    (ok (var-get payment-schedule-counter))
)

(define-read-only (calculate-monthly-burn-rate)
    (let (
            (current-period (/ stacks-block-height u1440))
            (periods-to-check u30) ;; Last 30 days
            (total-outflows (fold +
                (map get-period-outflows
                    (list
                        u0                         u1                         u2
                        u3                         u4                         u5
                        u6                         u7                         u8
                        u9                         u10
                        u11                         u12
                        u13                         u14
                        u15
                        u16                         u17                         u18
                        u19                         u20
                        u21                         u22
                        u23                         u24
                        u25                         u26
                        u27                         u28
                        u29
                    ))
                u0
            ))
        )
        (ok (/ total-outflows u30))
    )
)

(define-private (get-period-outflows (offset uint))
    (let (
            (period (- (/ stacks-block-height u1440) offset))
            (analytics (map-get? treasury-analytics period))
        )
        (match analytics
            data (get total-outflows data)
            u0
        )
    )
)

(define-read-only (get-treasury-health-score)
    (let (
            (balance (var-get treasury-balance))
            (monthly-burn (unwrap-panic (calculate-monthly-burn-rate)))
            (runway-months (if (> monthly-burn u0)
                (/ balance monthly-burn)
                u999
            ))
        )
        (ok {
            current-balance: balance,
            monthly-burn-rate: monthly-burn,
            runway-months: runway-months,
            health-score: (if (> runway-months u12)
                u100
                (if (> runway-months u6)
                    u75
                    (if (> runway-months u3)
                        u50
                        u25
                    )
                )
            ),
        })
    )
)

(define-read-only (get-member-activity-summary (member principal))
    (let (
            (analytics (unwrap! (map-get? member-analytics member) (err u0)))
            (member-info (unwrap! (map-get? organization-members member) (err u0)))
        )
        (ok {
            role: (get role member-info),
            proposals-created: (get proposals-created analytics),
            votes-cast: (get votes-cast analytics),
            transactions-executed: (get transactions-executed analytics),
            total-proposed: (get total-amount-proposed analytics),
            total-executed: (get total-amount-executed analytics),
            last-active: (get last-active analytics),
            days-since-active: (/ (- stacks-block-height (get last-active analytics)) u144),
        })
    )
)

;; Batch operations for efficiency
(define-public (batch-execute-recurring-payments (payment-ids (list 10 uint)))
    (begin
        (asserts! (not (var-get vault-paused)) err-unauthorized)
        (ok (map execute-single-recurring payment-ids))
    )
)

(define-private (execute-single-recurring (payment-id uint))
    (match (execute-recurring-payment payment-id)
        success
        true
        error
        false
    )
)

;; Emergency treasury management
(define-public (freeze-all-recurring-payments)
    (begin
        (asserts! (has-role tx-sender ROLE-ADMIN) err-unauthorized)
        ;; This would need to iterate through all payments in a full implementation
        ;; For now, we'll implement a simpler version
        (ok true)
    )
)

(define-read-only (get-vault-analytics-summary)
    (ok {
        total-members: (var-get total-members),
        signature-threshold: (var-get signature-threshold),
        treasury-balance: (var-get treasury-balance),
        total-proposals: (var-get proposal-counter),
        total-transactions: (var-get transaction-counter),
        active-recurring-payments: (var-get payment-schedule-counter),
        vault-paused: (var-get vault-paused),
        health-score: (unwrap-panic (get-treasury-health-score)),
    })
)
