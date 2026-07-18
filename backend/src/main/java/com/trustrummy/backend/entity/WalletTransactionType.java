package com.trustrummy.backend.entity;

public enum WalletTransactionType {
    DEPOSIT,
    WITHDRAWAL,
    /** Reserved for when match stakes are wired to the wallet ledger; unused today. */
    STAKE_DEBIT,
    /** Reserved for when match payouts are wired to the wallet ledger; unused today. */
    STAKE_PAYOUT
}
