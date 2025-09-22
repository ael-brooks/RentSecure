
;; title: RentSecure
;; version: 1.0.0
;; summary: Rental deposit and monthly payment escrow system
;; description: A smart contract that manages rental agreements with deposit and monthly payment escrow functionality

;; Error constants
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_LEASE_NOT_FOUND (err u101))
(define-constant ERR_LEASE_ALREADY_EXISTS (err u102))
(define-constant ERR_INSUFFICIENT_AMOUNT (err u103))
(define-constant ERR_LEASE_NOT_ACTIVE (err u104))
(define-constant ERR_PAYMENT_NOT_DUE (err u105))
(define-constant ERR_DEPOSIT_ALREADY_PAID (err u106))
(define-constant ERR_LEASE_TERMINATED (err u107))
(define-constant ERR_UNAUTHORIZED_RELEASE (err u108))

;; Data structure for lease agreements
(define-map leases
  { lease-id: uint }
  {
    landlord: principal,
    tenant: principal,
    monthly-rent: uint,
    deposit-amount: uint,
    lease-start: uint,
    lease-end: uint,
    deposit-paid: bool,
    deposit-released: bool,
    monthly-payments-made: uint,
    is-active: bool,
    created-at: uint
  }
)

;; Data structure for monthly payments
(define-map monthly-payments
  { lease-id: uint, payment-month: uint }
  {
    amount: uint,
    paid-at: uint,
    is-paid: bool
  }
)

;; Data structure for deposit escrow
(define-map deposit-escrow
  { lease-id: uint }
  {
    amount: uint,
    held-until: uint,
    release-approved-by-landlord: bool,
    release-approved-by-tenant: bool
  }
)

;; Global variables
(define-data-var next-lease-id uint u1)

;; Public function to create a new lease agreement
(define-public (create-lease
  (tenant principal)
  (monthly-rent uint)
  (deposit-amount uint)
  (lease-duration-months uint))
  (let
    (
      (lease-id (var-get next-lease-id))
      (current-block block-height)
      (lease-end (+ current-block (* lease-duration-months u144))) ;; Assuming ~144 blocks per day, 30 days per month
    )
    ;; Check if lease already exists
    (asserts! (is-none (map-get? leases { lease-id: lease-id })) ERR_LEASE_ALREADY_EXISTS)

    ;; Create the lease
    (map-set leases
      { lease-id: lease-id }
      {
        landlord: tx-sender,
        tenant: tenant,
        monthly-rent: monthly-rent,
        deposit-amount: deposit-amount,
        lease-start: current-block,
        lease-end: lease-end,
        deposit-paid: false,
        deposit-released: false,
        monthly-payments-made: u0,
        is-active: true,
        created-at: current-block
      }
    )

    ;; Increment lease ID for next lease
    (var-set next-lease-id (+ lease-id u1))

    (ok lease-id)
  )
)

;; Public function for tenant to pay deposit
(define-public (pay-deposit (lease-id uint))
  (let
    (
      (lease-data (unwrap! (map-get? leases { lease-id: lease-id }) ERR_LEASE_NOT_FOUND))
      (deposit-amount (get deposit-amount lease-data))
    )
    ;; Check if caller is the tenant
    (asserts! (is-eq tx-sender (get tenant lease-data)) ERR_NOT_AUTHORIZED)

    ;; Check if lease is active
    (asserts! (get is-active lease-data) ERR_LEASE_NOT_ACTIVE)

    ;; Check if deposit hasn't been paid yet
    (asserts! (not (get deposit-paid lease-data)) ERR_DEPOSIT_ALREADY_PAID)

    ;; Transfer STX from tenant to contract
    (try! (stx-transfer? deposit-amount tx-sender (as-contract tx-sender)))

    ;; Update lease to mark deposit as paid
    (map-set leases
      { lease-id: lease-id }
      (merge lease-data { deposit-paid: true })
    )

    ;; Create deposit escrow entry
    (map-set deposit-escrow
      { lease-id: lease-id }
      {
        amount: deposit-amount,
        held-until: (get lease-end lease-data),
        release-approved-by-landlord: false,
        release-approved-by-tenant: false
      }
    )

    (ok true)
  )
)

;; Public function for tenant to pay monthly rent
(define-public (pay-monthly-rent (lease-id uint) (payment-month uint))
  (let
    (
      (lease-data (unwrap! (map-get? leases { lease-id: lease-id }) ERR_LEASE_NOT_FOUND))
      (monthly-rent (get monthly-rent lease-data))
    )
    ;; Check if caller is the tenant
    (asserts! (is-eq tx-sender (get tenant lease-data)) ERR_NOT_AUTHORIZED)

    ;; Check if lease is active
    (asserts! (get is-active lease-data) ERR_LEASE_NOT_ACTIVE)

    ;; Check if this month's payment hasn't been made
    (asserts! (is-none (map-get? monthly-payments { lease-id: lease-id, payment-month: payment-month })) ERR_PAYMENT_NOT_DUE)

    ;; Transfer STX from tenant to landlord
    (try! (stx-transfer? monthly-rent tx-sender (get landlord lease-data)))

    ;; Record the payment
    (map-set monthly-payments
      { lease-id: lease-id, payment-month: payment-month }
      {
        amount: monthly-rent,
        paid-at: block-height,
        is-paid: true
      }
    )

    ;; Update lease payment counter
    (map-set leases
      { lease-id: lease-id }
      (merge lease-data { monthly-payments-made: (+ (get monthly-payments-made lease-data) u1) })
    )

    (ok true)
  )
)

;; Public function for landlord to approve deposit release
(define-public (landlord-approve-deposit-release (lease-id uint))
  (let
    (
      (lease-data (unwrap! (map-get? leases { lease-id: lease-id }) ERR_LEASE_NOT_FOUND))
      (escrow-data (unwrap! (map-get? deposit-escrow { lease-id: lease-id }) ERR_LEASE_NOT_FOUND))
    )
    ;; Check if caller is the landlord
    (asserts! (is-eq tx-sender (get landlord lease-data)) ERR_NOT_AUTHORIZED)

    ;; Check if lease has ended or been terminated
    (asserts! (or
      (>= block-height (get lease-end lease-data))
      (not (get is-active lease-data))
    ) ERR_LEASE_NOT_ACTIVE)

    ;; Update escrow to mark landlord approval
    (map-set deposit-escrow
      { lease-id: lease-id }
      (merge escrow-data { release-approved-by-landlord: true })
    )

    (ok true)
  )
)

;; Public function for tenant to approve deposit release
(define-public (tenant-approve-deposit-release (lease-id uint))
  (let
    (
      (lease-data (unwrap! (map-get? leases { lease-id: lease-id }) ERR_LEASE_NOT_FOUND))
      (escrow-data (unwrap! (map-get? deposit-escrow { lease-id: lease-id }) ERR_LEASE_NOT_FOUND))
    )
    ;; Check if caller is the tenant
    (asserts! (is-eq tx-sender (get tenant lease-data)) ERR_NOT_AUTHORIZED)

    ;; Update escrow to mark tenant approval
    (map-set deposit-escrow
      { lease-id: lease-id }
      (merge escrow-data { release-approved-by-tenant: true })
    )

    (ok true)
  )
)

;; Public function to release deposit (requires both parties' approval)
(define-public (release-deposit (lease-id uint))
  (let
    (
      (lease-data (unwrap! (map-get? leases { lease-id: lease-id }) ERR_LEASE_NOT_FOUND))
      (escrow-data (unwrap! (map-get? deposit-escrow { lease-id: lease-id }) ERR_LEASE_NOT_FOUND))
      (deposit-amount (get amount escrow-data))
    )
    ;; Check if both parties have approved
    (asserts! (and
      (get release-approved-by-landlord escrow-data)
      (get release-approved-by-tenant escrow-data)
    ) ERR_UNAUTHORIZED_RELEASE)

    ;; Check if deposit hasn't been released yet
    (asserts! (not (get deposit-released lease-data)) ERR_UNAUTHORIZED_RELEASE)

    ;; Transfer deposit back to tenant
    (try! (as-contract (stx-transfer? deposit-amount tx-sender (get tenant lease-data))))

    ;; Mark deposit as released
    (map-set leases
      { lease-id: lease-id }
      (merge lease-data { deposit-released: true })
    )

    (ok true)
  )
)

;; Public function to terminate lease early (landlord only)
(define-public (terminate-lease (lease-id uint))
  (let
    (
      (lease-data (unwrap! (map-get? leases { lease-id: lease-id }) ERR_LEASE_NOT_FOUND))
    )
    ;; Check if caller is the landlord
    (asserts! (is-eq tx-sender (get landlord lease-data)) ERR_NOT_AUTHORIZED)

    ;; Check if lease is active
    (asserts! (get is-active lease-data) ERR_LEASE_NOT_ACTIVE)

    ;; Mark lease as inactive
    (map-set leases
      { lease-id: lease-id }
      (merge lease-data { is-active: false })
    )

    (ok true)
  )
)

;; Read-only function to get lease details
(define-read-only (get-lease (lease-id uint))
  (map-get? leases { lease-id: lease-id })
)

;; Read-only function to get deposit escrow details
(define-read-only (get-deposit-escrow (lease-id uint))
  (map-get? deposit-escrow { lease-id: lease-id })
)

;; Read-only function to get monthly payment details
(define-read-only (get-monthly-payment (lease-id uint) (payment-month uint))
  (map-get? monthly-payments { lease-id: lease-id, payment-month: payment-month })
)

;; Read-only function to check if monthly payment is due
(define-read-only (is-payment-due (lease-id uint) (payment-month uint))
  (is-none (map-get? monthly-payments { lease-id: lease-id, payment-month: payment-month }))
)

;; Read-only function to get next lease ID
(define-read-only (get-next-lease-id)
  (var-get next-lease-id)
)
